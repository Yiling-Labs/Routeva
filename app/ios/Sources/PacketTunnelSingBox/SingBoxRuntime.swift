import Foundation
import DataKit
import SharedKit

enum SingBoxCoreProbeError: Error, Sendable {
    case unavailable
    case failed
    case dataPlaneUnavailable

    var stableCode: String {
        switch self {
        case .unavailable: "probe.core_url_test_unavailable"
        case .failed: "probe.core_url_test_failed"
        case .dataPlaneUnavailable: "probe.packet_bridge_unavailable"
        }
    }
}

enum SingBoxNodeSelectionError: Error, Equatable, Sendable {
    case unavailable
    case nodeNotInRuntimeCatalog
    case rejected
    case selectorStateUnconfirmed
    case connectionInterruptionFailed
    case configurationReloadRejected
    case configurationReloadRollbackFailed

    var stableCode: String {
        switch self {
        case .unavailable: "provider.node_selection_unavailable"
        case .nodeNotInRuntimeCatalog: "provider.node_not_in_runtime_catalog"
        case .rejected: "provider.node_selection_rejected"
        case .selectorStateUnconfirmed: "provider.node_selection_unconfirmed"
        case .connectionInterruptionFailed:
            "provider.node_connection_interruption_failed"
        case .configurationReloadRejected: "provider.configuration_reload_rejected"
        case .configurationReloadRollbackFailed:
            "provider.configuration_reload_rollback_failed"
        }
    }

    var requiresTunnelCancellation: Bool {
        self == .configurationReloadRollbackFailed
    }
}

#if canImport(Libbox)
import Libbox

final class SingBoxRuntime: @unchecked Sendable {
    private struct ConfigurationSnapshot {
        let json: String
        let directRouteAddresses: [String]
        let allowedNodeIDs: Set<UUID>
        let selectedNodeID: UUID
    }

    private var commandServer: LibboxCommandServer?
    private var statusClient: LibboxCommandClient?
    private weak var probePlatform: SingBoxPlatformInterface?
    private let clientLock = NSLock()
    private var allowedNodeIDs: Set<UUID> = []
    private var selectedNodeID: UUID?
    private var activeJSON: String?
    private var pendingReloadRollback: ConfigurationSnapshot?
    private var didSetup = false

    func start(
        json: String,
        platform: SingBoxPlatformInterface,
        initialNodeID: UUID,
        availableNodeIDs: Set<UUID>,
        onFailure: @escaping @Sendable (ProviderStartupStage, String) -> Void = { _, _ in },
        onStage: @escaping @Sendable (ProviderStartupStage) -> Void
    ) throws {
        if !didSetup {
            try setupRuntime()
        }

        var createError: NSError?
        guard let server = LibboxNewCommandServer(platform, platform, &createError) else {
            throw PacketTunnelRuntimeError.coreFailure("sing-box-command-server-failed")
        }
        var currentStage = ProviderStartupStage.validatingConfiguration
        do {
            onStage(currentStage)
            try server.checkConfig(json)
            currentStage = .startingCommandServer
            onStage(currentStage)
            try server.start()
            // Libbox exposes this parameter as nullable to Objective-C, but the
            // pinned Go implementation dereferences it unconditionally.
            currentStage = .startingCoreService
            onStage(currentStage)
            platform.resetCoreURLTestResult()
            platform.resetSelectorSelection()
            try server.startOrReloadService(json, options: LibboxOverrideOptions())
            // Start consuming NEPacketTunnelFlow only after gVisor has
            // attached its socket reader. This removes the route-installed /
            // core-reader-not-ready window that used to fill the datagram
            // queue during startup.
            try platform.startPacketBridge()
            commandServer = server

            let options = LibboxCommandClientOptions()
            options.addCommand(LibboxCommandStatus)
            options.addCommand(LibboxCommandLog)
            options.addCommand(LibboxCommandGroup)
            options.statusInterval = 1_000_000_000
            if let client = LibboxNewCommandClient(platform, options),
               (try? client.connect()) != nil {
                guard availableNodeIDs.contains(initialNodeID) else {
                    throw SingBoxNodeSelectionError.nodeNotInRuntimeCatalog
                }
                try applyNodeSelection(
                    initialNodeID,
                    using: client,
                    platform: platform,
                    availableNodeIDs: availableNodeIDs
                )
                clientLock.withLock {
                    statusClient = client
                    probePlatform = platform
                    allowedNodeIDs = availableNodeIDs
                    selectedNodeID = initialNodeID
                    activeJSON = json
                }
            } else {
                throw SingBoxNodeSelectionError.unavailable
            }
        } catch {
            let runtimeError = classifiedStartupFailure(error, at: currentStage)
            // Persist the redacted classification before closing Libbox. Its
            // teardown can make NEVPNStatus become disconnected before the
            // provider's outer catch gets a chance to update the handoff.
            onFailure(currentStage, runtimeError.stableDiagnosticCode)
            server.close()
            throw runtimeError
        }
    }

    private func classifiedStartupFailure(
        _ error: Error,
        at stage: ProviderStartupStage
    ) -> PacketTunnelRuntimeError {
        switch stage {
        case .validatingConfiguration:
            return .coreConfigurationValidationFailed
        case .startingCommandServer:
            return .commandServerStartFailed
        case .startingCoreService:
            let value = (error as NSError).localizedDescription.lowercased()
            if value.contains("plugin") || value.contains("obfs") {
                return .coreServicePluginFailed
            }
            if value.contains("route") || value.contains("rule")
                || value.contains("domain matcher") {
                return .coreServiceRouteFailed
            }
            if value.contains("dns") || value.contains("resolver") {
                return .coreServiceDNSFailed
            }
            if value.contains("tun") || value.contains("packet flow")
                || value.contains("gvisor") {
                return .coreServiceTunnelFailed
            }
            if value.contains("outbound") || value.contains("proxy") {
                return .coreServiceOutboundFailed
            }
            return .coreServiceStartFailed
        default:
            return .coreServiceStartFailed
        }
    }

    func stop() {
        let client: LibboxCommandClient? = clientLock.withLock {
            let current = statusClient
            let currentPlatform = probePlatform
            statusClient = nil
            probePlatform = nil
            allowedNodeIDs.removeAll(keepingCapacity: false)
            selectedNodeID = nil
            activeJSON = nil
            pendingReloadRollback = nil
            currentPlatform?.resetSelectorSelection()
            return current
        }
        try? client?.disconnect()
        if let server = commandServer {
            try? server.closeService()
            server.close()
        }
        commandServer = nil
    }

    /// Runs sing-box's own URL-test through the configured `proxy` outbound.
    /// This does not depend on the container App being routed into its own
    /// Packet Tunnel and does not consult CFNetwork's system proxy settings.
    func probe() throws -> ProviderCoreProbeSnapshot {
        let pair: (LibboxCommandClient, SingBoxPlatformInterface)? = clientLock.withLock {
            guard let statusClient, let probePlatform else { return nil }
            return (statusClient, probePlatform)
        }
        guard let (client, platform) = pair else {
            throw SingBoxCoreProbeError.unavailable
        }
        guard platform.isPacketBridgeRunning() else {
            throw SingBoxCoreProbeError.dataPlaneUnavailable
        }

        if let latency = platform.currentCoreURLTestLatency() {
            guard platform.isPacketBridgeRunning() else {
                throw SingBoxCoreProbeError.dataPlaneUnavailable
            }
            return ProviderCoreProbeSnapshot(latencyMilliseconds: latency)
        }
        do {
            try client.urlTest("routeva-probe")
        } catch {
            throw SingBoxCoreProbeError.failed
        }
        guard let latency = platform.waitForCoreURLTestSuccess(timeout: 10) else {
            throw SingBoxCoreProbeError.failed
        }
        guard platform.isPacketBridgeRunning() else {
            throw SingBoxCoreProbeError.dataPlaneUnavailable
        }
        return ProviderCoreProbeSnapshot(latencyMilliseconds: latency)
    }

    /// Atomically updates Libbox first, then publishes the confirmed runtime
    /// selection. A rejected command leaves the previously selected UUID
    /// untouched so the App can safely query or roll back.
    func selectNode(_ nodeID: UUID) throws -> UUID {
        try clientLock.withLock {
            guard let statusClient, let platform = probePlatform else {
                throw SingBoxNodeSelectionError.unavailable
            }
            guard allowedNodeIDs.contains(nodeID) else {
                throw SingBoxNodeSelectionError.nodeNotInRuntimeCatalog
            }
            try applyNodeSelection(
                nodeID,
                using: statusClient,
                platform: platform,
                availableNodeIDs: allowedNodeIDs
            )
            selectedNodeID = nodeID
            return nodeID
        }
    }

    func currentSelectedNode() throws -> UUID {
        try clientLock.withLock {
            guard statusClient != nil, let platform = probePlatform else {
                throw SingBoxNodeSelectionError.unavailable
            }
            if let actualNodeID = platform.currentSelectedNodeID(),
               allowedNodeIDs.contains(actualNodeID) {
                selectedNodeID = actualNodeID
                return actualNodeID
            }
            // sing-box intentionally omits groups with fewer than two items
            // from SubscribeGroups. In a one-node catalog, a successful
            // SelectOutbound command uniquely determines the actual result.
            if allowedNodeIDs.count == 1, let selectedNodeID,
               allowedNodeIDs.contains(selectedNodeID) {
                return selectedNodeID
            }
            throw SingBoxNodeSelectionError.unavailable
        }
    }

    /// Replaces the bounded outbound catalog without closing the surrounding
    /// Network Extension session. Libbox stops and recreates only its service;
    /// the command server and NE provider remain alive. A failure after the old
    /// service was closed is repaired immediately from the previous JSON and
    /// route snapshot before the error is returned to the App.
    func reloadConfiguration(
        json: String,
        initialNodeID: UUID,
        availableNodeIDs: Set<UUID>,
        directRouteAddresses: [String]
    ) throws -> UUID {
        try clientLock.withLock {
            guard let commandServer, let statusClient, let platform = probePlatform,
                  let previousJSON = activeJSON, let previousNodeID = selectedNodeID
            else { throw SingBoxNodeSelectionError.unavailable }
            guard availableNodeIDs.contains(initialNodeID) else {
                throw SingBoxNodeSelectionError.nodeNotInRuntimeCatalog
            }

            do {
                try commandServer.checkConfig(json)
            } catch {
                throw SingBoxNodeSelectionError.configurationReloadRejected
            }

            let previousDirectRouteAddresses = platform.updateDirectRouteAddresses(
                directRouteAddresses
            )
            let previousAllowedNodeIDs = allowedNodeIDs
            let existingRollbackSnapshot = pendingReloadRollback
            do {
                platform.resetCoreURLTestResult()
                platform.resetSelectorSelection()
                try commandServer.startOrReloadService(
                    json,
                    options: LibboxOverrideOptions()
                )
                try platform.startPacketBridge()
                try applyNodeSelection(
                    initialNodeID,
                    using: statusClient,
                    platform: platform,
                    availableNodeIDs: availableNodeIDs
                )
                allowedNodeIDs = availableNodeIDs
                selectedNodeID = initialNodeID
                activeJSON = json
                pendingReloadRollback = existingRollbackSnapshot
                    ?? ConfigurationSnapshot(
                        json: previousJSON,
                        directRouteAddresses: previousDirectRouteAddresses,
                        allowedNodeIDs: previousAllowedNodeIDs,
                        selectedNodeID: previousNodeID
                    )
                return initialNodeID
            } catch {
                platform.updateDirectRouteAddresses(previousDirectRouteAddresses)
                do {
                    platform.resetCoreURLTestResult()
                    platform.resetSelectorSelection()
                    try commandServer.startOrReloadService(
                        previousJSON,
                        options: LibboxOverrideOptions()
                    )
                    try platform.startPacketBridge()
                    try applyNodeSelection(
                        previousNodeID,
                        using: statusClient,
                        platform: platform,
                        availableNodeIDs: previousAllowedNodeIDs
                    )
                    pendingReloadRollback = existingRollbackSnapshot
                } catch {
                    allowedNodeIDs.removeAll(keepingCapacity: false)
                    selectedNodeID = nil
                    activeJSON = nil
                    pendingReloadRollback = nil
                    throw SingBoxNodeSelectionError.configurationReloadRollbackFailed
                }
                throw SingBoxNodeSelectionError.configurationReloadRejected
            }
        }
    }

    /// Completes the two-phase reload transaction. Rejecting restores the
    /// oldest still-unverified snapshot so canceled A→B→C reloads roll back to
    /// the last verified A configuration rather than an unverified B service.
    func finalizeConfigurationReload(
        expectedNodeID: UUID,
        accept: Bool
    ) throws -> UUID {
        try clientLock.withLock {
            guard let commandServer, let statusClient, let platform = probePlatform,
                  let selectedNodeID, selectedNodeID == expectedNodeID
            else { throw SingBoxNodeSelectionError.unavailable }
            guard !accept else {
                pendingReloadRollback = nil
                return selectedNodeID
            }
            guard let snapshot = pendingReloadRollback else {
                throw SingBoxNodeSelectionError.configurationReloadRejected
            }

            platform.updateDirectRouteAddresses(snapshot.directRouteAddresses)
            do {
                platform.resetCoreURLTestResult()
                platform.resetSelectorSelection()
                try commandServer.startOrReloadService(
                    snapshot.json,
                    options: LibboxOverrideOptions()
                )
                try platform.startPacketBridge()
                try applyNodeSelection(
                    snapshot.selectedNodeID,
                    using: statusClient,
                    platform: platform,
                    availableNodeIDs: snapshot.allowedNodeIDs
                )
                activeJSON = snapshot.json
                allowedNodeIDs = snapshot.allowedNodeIDs
                self.selectedNodeID = snapshot.selectedNodeID
                pendingReloadRollback = nil
                return snapshot.selectedNodeID
            } catch {
                allowedNodeIDs.removeAll(keepingCapacity: false)
                self.selectedNodeID = nil
                activeJSON = nil
                pendingReloadRollback = nil
                throw SingBoxNodeSelectionError.configurationReloadRollbackFailed
            }
        }
    }

    /// Applies the selector mutation, immediately tears down every tracked
    /// remote TCP/UDP session, then waits for sing-box's Group stream to report
    /// the requested UUID. The global close is required for iOS TUN traffic:
    /// selector NewConnectionEx delegates directly to the raw outbound, so the
    /// selector's own interrupt group does not necessarily own those sessions.
    private func applyNodeSelection(
        _ nodeID: UUID,
        using client: LibboxCommandClient,
        platform: SingBoxPlatformInterface,
        availableNodeIDs: Set<UUID>
    ) throws {
        platform.resetCoreURLTestResult()
        do {
            try client.selectOutbound(
                SingBoxNodeSelector.groupTag,
                outboundTag: SingBoxNodeSelector.outboundTag(for: nodeID)
            )
        } catch {
            throw SingBoxNodeSelectionError.rejected
        }
        do {
            try client.closeConnections()
        } catch {
            throw SingBoxNodeSelectionError.connectionInterruptionFailed
        }
        guard availableNodeIDs.count == 1
                || platform.waitForSelectedNode(nodeID, timeout: 2)
        else {
            throw SingBoxNodeSelectionError.selectorStateUnconfirmed
        }
    }

    private func setupRuntime() throws {
        let setup = LibboxSetupOptions()
        let baseURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.yilinglabs.routeva"
        ) ?? FileManager.default.temporaryDirectory
        setup.basePath = baseURL.path
        setup.workingPath = baseURL.appendingPathComponent("CoreRuntime", isDirectory: true).path
        setup.tempPath = FileManager.default.temporaryDirectory.path
        setup.logMaxLines = 0
        setup.debug = false

        do {
            try FileManager.default.createDirectory(
                atPath: setup.workingPath,
                withIntermediateDirectories: true
            )
        } catch {
            throw PacketTunnelRuntimeError.coreFailure("sing-box-runtime-directory-failed")
        }

        var setupError: NSError?
        guard LibboxSetup(setup, &setupError) else {
            throw PacketTunnelRuntimeError.coreFailure("sing-box-setup-failed")
        }
        didSetup = true
    }
}
#else
final class SingBoxPlatformInterface: @unchecked Sendable {
    init(
        tunnel: AnyObject,
        runtimeState: ProviderRuntimeStateStore,
        directRouteAddresses: [String],
        onBridgeStarting: @escaping @Sendable () -> Void,
        onBridgeFailure: @escaping @Sendable (PacketTunnelRuntimeError) -> Void
    ) {}

    func stopPacketBridge() {}
}

final class SingBoxRuntime: @unchecked Sendable {
    func start(
        json: String,
        platform: SingBoxPlatformInterface,
        initialNodeID: UUID,
        availableNodeIDs: Set<UUID>,
        onFailure: @escaping @Sendable (ProviderStartupStage, String) -> Void = { _, _ in },
        onStage: @escaping @Sendable (ProviderStartupStage) -> Void
    ) throws {
        throw PacketTunnelRuntimeError.coreNotLinked(.singBox)
    }

    func stop() {}

    func probe() throws -> ProviderCoreProbeSnapshot {
        throw SingBoxCoreProbeError.unavailable
    }

    func selectNode(_ nodeID: UUID) throws -> UUID {
        throw SingBoxNodeSelectionError.unavailable
    }

    func currentSelectedNode() throws -> UUID {
        throw SingBoxNodeSelectionError.unavailable
    }

    func reloadConfiguration(
        json: String,
        initialNodeID: UUID,
        availableNodeIDs: Set<UUID>,
        directRouteAddresses: [String]
    ) throws -> UUID {
        throw SingBoxNodeSelectionError.unavailable
    }

    func finalizeConfigurationReload(
        expectedNodeID: UUID,
        accept: Bool
    ) throws -> UUID {
        throw SingBoxNodeSelectionError.unavailable
    }
}
#endif
