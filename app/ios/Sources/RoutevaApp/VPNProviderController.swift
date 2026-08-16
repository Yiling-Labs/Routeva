import DataKit
import Foundation
@preconcurrency import NetworkExtension
import SharedKit

enum ProviderBundleIdentifier {
    static func value(for core: CoreIdentifier) -> String {
        "com.yilinglabs.routeva.SingBoxTunnel"
    }
}

enum VPNProviderControllerError: LocalizedError {
    case switchTimedOut
    case providerConfigurationMissing(CoreIdentifier)
    case providerSessionUnavailable(CoreIdentifier, status: Int)
    case providerStartFailed(CoreIdentifier, diagnosticCode: String?)
    case providerResponseMissing
    case providerResponseTimedOut

    var errorDescription: String? {
        switch self {
        case .switchTimedOut:
            "The active VPN provider did not stop before the core switch timed out."
        case let .providerConfigurationMissing(core):
            "The VPN configuration for \(core.rawValue) is unavailable."
        case let .providerSessionUnavailable(core, status):
            "The \(core.rawValue) VPN provider session is unavailable (status \(status))."
        case let .providerStartFailed(core, _):
            "The \(core.rawValue) VPN provider stopped before it finished starting."
        case .providerResponseMissing:
            "The VPN provider did not return a response."
        case .providerResponseTimedOut:
            "The VPN provider did not respond in time."
        }
    }
}

/// Owns the process boundary between the two Go runtimes. Automatic selection
/// happens before a provider starts. Fallback always stops one extension and
/// starts the other; an already connected session is never hot-swapped.
actor VPNProviderController {
    private let selector = CoreSelector()
    private let startupDiagnostics = ProviderStartupDiagnosticStore()
    private let ipcRecoveryPolicy = ProviderIPCRecoveryPolicy()
    /// The manager that completed the latest start in this App process.
    /// Keeping it avoids a preferences round-trip before an explicit user
    /// stop can even be submitted to NetworkExtension.
    private var activeManager: (core: CoreIdentifier, manager: NETunnelProviderManager)?
    /// Reserve Provider messages far enough apart to stay outside the
    /// extension's 200 ms request limiter, including concurrent polling tasks.
    private var nextProviderMessageAt = ContinuousClock.now
    /// 取消/超时后作废仍在跑的 saveToPreferences / startVPNTunnel。
    private var startGeneration: UInt64 = 0

    static func stableDiagnosticCode(for error: Error) -> String {
        guard case let VPNProviderControllerError.providerStartFailed(_, code) = error else {
            return "tunnel.provider_start_failed"
        }
        return code ?? "tunnel.provider_start_failed"
    }

    static func stableCoreProbeDiagnosticCode(for error: Error) -> String {
        if case let ProviderMessageCodecError.providerRejected(code) = error {
            return code
        }
        if case VPNProviderControllerError.providerConfigurationMissing = error {
            return "probe.tunnel_probe_session_missing"
        }
        if case VPNProviderControllerError.providerSessionUnavailable = error {
            return "probe.tunnel_probe_session_unavailable"
        }
        if case VPNProviderControllerError.providerResponseMissing = error {
            return "probe.tunnel_probe_response_missing"
        }
        if case VPNProviderControllerError.providerResponseTimedOut = error {
            return "probe.tunnel_probe_ipc_timeout"
        }
        if let codecError = error as? ProviderMessageCodecError {
            switch codecError {
            case .messageTooLarge:
                return "probe.tunnel_probe_message_too_large"
            case .unsupportedSchema:
                return "probe.tunnel_probe_schema_unsupported"
            case .malformedMessage:
                return "probe.tunnel_probe_response_malformed"
            case .mismatchedResponse:
                return "probe.tunnel_probe_response_mismatched"
            case .providerRejected:
                break
            }
        }
        return "probe.tunnel_probe_ipc_failed"
    }

    private static func startRequestDiagnosticCode(for error: Error) -> String {
        let systemError = error as NSError
        guard systemError.domain == NEVPNErrorDomain else {
            return "provider.start_request_failed.system"
        }
        switch systemError.code {
        case 1:
            return "provider.start_request_failed.configuration_invalid"
        case 2:
            return "provider.start_request_failed.configuration_disabled"
        case 3:
            return "provider.start_request_failed.connection_failed"
        case 4:
            return "provider.start_request_failed.configuration_stale"
        case 5:
            return "provider.start_request_failed.configuration_read_write_failed"
        case 6:
            return "provider.start_request_failed.configuration_unknown"
        default:
            return "provider.start_request_failed.nevpn_unknown"
        }
    }

    static func isConfigurationPermissionFailure(_ error: Error) -> Bool {
        guard case let VPNProviderControllerError.providerStartFailed(_, code) = error else {
            return false
        }
        switch code {
        case "provider.configuration_activation_not_persisted",
             "provider.configuration_save_timed_out",
             "provider.start_request_failed.configuration_invalid",
             "provider.start_request_failed.configuration_disabled",
             "provider.start_request_failed.configuration_stale",
             "provider.start_request_failed.configuration_read_write_failed",
             "provider.start_request_failed.configuration_unknown":
            return true
        default:
            return false
        }
    }

    private static func shouldReactivateConfiguration(after error: Error) -> Bool {
        let systemError = error as NSError
        guard systemError.domain == NEVPNErrorDomain else { return false }
        return systemError.code == 2 || systemError.code == 4
    }

    @discardableResult
    func connect(
        manifest: RuntimeManifest,
        health: [CoreIdentifier: CoreHealth],
        excluding: Set<CoreIdentifier> = []
    ) async throws -> CoreSelectionDecision {
        let decision = try selector.select(
            manifest: manifest,
            health: health,
            excluding: excluding
        )
        try await start(
            core: decision.selected,
            manifestID: manifest.manifestID,
            isSceneActive: { true }
        )
        return decision
    }

    func invalidateInFlightStart() {
        startGeneration &+= 1
    }

    func hasEnabledConfiguration(core: CoreIdentifier = .singBox) async -> Bool {
        guard let managers = try? await loadManagersFromPreferences() else { return false }
        return managers[core]?.isEnabled == true
    }

    func disconnectAll() async throws {
        activeManager?.manager.connection.stopVPNTunnel()
        activeManager = nil
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()
        managers.forEach { $0.connection.stopVPNTunnel() }
    }

    /// Reloads system preferences because the Packet Tunnel may have survived
    /// the containing App process. An in-memory manager from a previous App
    /// lifetime is never required for status recovery.
    func connectionSnapshot() async throws -> ProviderConnectionSnapshot {
        let managers = try await loadManagersFromPreferences()
        let candidates = CoreIdentifier.allCases.compactMap { core -> (
            core: CoreIdentifier,
            manager: NETunnelProviderManager,
            status: NEVPNStatus
        )? in
            guard let manager = managers[core] else { return nil }
            // Read each connection status exactly once. Repeated status reads
            // perform synchronous NetworkExtension IPC on a real device.
            return (core, manager, manager.connection.status)
        }

        for desiredStatus in [
            NEVPNStatus.connected,
            .reasserting,
            .connecting,
            .disconnecting,
        ] {
            guard let candidate = candidates.first(where: {
                $0.status == desiredStatus
            }) else { continue }
            activeManager = (candidate.core, candidate.manager)
            switch desiredStatus {
            case .connected:
                return .connected(
                    core: candidate.core,
                    since: candidate.manager.connection.connectedDate
                )
            case .reasserting:
                return .reasserting(
                    core: candidate.core,
                    since: candidate.manager.connection.connectedDate
                )
            case .connecting:
                return .connecting(core: candidate.core)
            case .disconnecting:
                return .disconnecting(core: candidate.core)
            default:
                break
            }
        }

        activeManager = nil
        return .disconnected
    }

    func start(
        core: CoreIdentifier,
        manifestID: UUID,
        isSceneActive: @escaping @Sendable () async -> Bool = { true }
    ) async throws {
        startGeneration &+= 1
        let generation = startGeneration
        try await removeLegacyRoutevaManagers()
        try ensureStartCurrent(generation)
        if let activeManager {
            try await stopForFreshSession(activeManager.manager)
        }
        activeManager = nil

        var existingManagers = try await loadManagersFromPreferences()
        try ensureStartCurrent(generation)
        if let existingManager = existingManagers[core] {
            // Every attempt has a new manifest ID. Never reuse a same-core
            // session that merely still reports Connected: it may be an old
            // bridge in the asynchronous cancel/teardown window. Serialize
            // provider lifetimes before sending the new manifest.
            try await stopForFreshSession(existingManager)
        }

        // Stop any stale Routeva session before starting a fresh manifest.
        try await stopOtherManagers(existingManagers, except: core)
        try ensureStartCurrent(generation)
        // A manager loaded before stop can remain bound to the old Provider
        // bridge even after its local connection object says Disconnected.
        // Require two refreshed inactive observations, then start only from a
        // manager loaded after that teardown barrier.
        try await waitForStableDisconnection(core: core)
        try ensureStartCurrent(generation)
        existingManagers = try await loadManagersFromPreferences()
        if !managersMatchDesiredConfiguration(existingManagers, activating: core) {
            try await configureManagers(activating: core)
            try ensureStartCurrent(generation)
        }
        var manager = try await waitUntilReadyToStart(
            core: core,
            generation: generation,
            isSceneActive: isSceneActive
        )

        startupDiagnostics.clear()
        let startupRequestedAt = Date()
        try ensureStartCurrent(generation)
        do {
            try manager.connection.startVPNTunnel(options: [
                ProviderStartOptionKey.manifestID: manifestID.uuidString as NSString,
            ])
        } catch {
            if Self.shouldReactivateConfiguration(after: error) {
                // Settings or another VPN may have changed the single enabled
                // enterprise configuration between our load and start request.
                try ensureStartCurrent(generation)
                let refreshedManagers = try await configureManagers(activating: core)
                guard let refreshed = refreshedManagers[core], refreshed.isEnabled else {
                    throw VPNProviderControllerError.providerStartFailed(
                        core,
                        diagnosticCode: "provider.configuration_activation_not_persisted"
                    )
                }
                manager = refreshed
                do {
                    try manager.connection.startVPNTunnel(options: [
                        ProviderStartOptionKey.manifestID: manifestID.uuidString as NSString,
                    ])
                } catch {
                    throw VPNProviderControllerError.providerStartFailed(
                        core,
                        diagnosticCode: Self.startRequestDiagnosticCode(for: error)
                    )
                }
            } else {
                throw VPNProviderControllerError.providerStartFailed(
                    core,
                    diagnosticCode: Self.startRequestDiagnosticCode(for: error)
                )
            }
        }
        try await waitForStatus(
            manager,
            desired: .connected,
            timeout: .seconds(20),
            startupRequestedAt: startupRequestedAt
        )
        activeManager = (core, manager)
        try await waitForProviderReadiness(core: core)
    }

    func stop(core: CoreIdentifier) async {
        guard let manager = await managerForStop(core: core) else { return }
        manager.connection.stopVPNTunnel()
        if activeManager?.core == core { activeManager = nil }
        try? await waitForStatus(manager, desired: .disconnected, timeout: .seconds(10))
    }

    /// Submits a user-requested stop without serializing the host UI behind
    /// NetworkExtension's asynchronous `.disconnecting` -> `.disconnected`
    /// transition. A subsequent start still calls `stopForFreshSession`, so a
    /// rapid reconnect cannot overlap the old provider lifetime.
    func requestStop(core: CoreIdentifier) async {
        guard let manager = await managerForStop(core: core) else { return }
        manager.connection.stopVPNTunnel()
        if activeManager?.core == core { activeManager = nil }
    }

    func isConnectionActive(core: CoreIdentifier) async -> Bool {
        guard let managers = try? await loadManagersFromPreferences(),
              let manager = managers[core]
        else { return false }
        switch manager.connection.status {
        case .connected, .connecting, .reasserting:
            return true
        default:
            return false
        }
    }

    func queryTraffic(core: CoreIdentifier) async throws -> ProviderTrafficSnapshot {
        let request = ProviderMessageRequest(kind: .traffic)
        let response = try await sendProviderRequest(request, core: core)
        guard let traffic = response.traffic else {
            throw VPNProviderControllerError.providerResponseMissing
        }
        return traffic
    }

    func queryDataPlane(core: CoreIdentifier) async throws -> ProviderDataPlaneSnapshot {
        let request = ProviderMessageRequest(kind: .dataPlane)
        let response = try await sendProviderRequest(request, core: core)
        guard let dataPlane = response.dataPlane else {
            throw VPNProviderControllerError.providerResponseMissing
        }
        return dataPlane
    }

    func probeCore(
        core: CoreIdentifier,
        tunnelProbeAddressSets: [ProviderTunnelProbeAddressSet] = []
    ) async throws -> ProviderCoreProbeSnapshot? {
        var completedAttempts = 0
        while true {
            completedAttempts += 1
            do {
                return try await performCoreProbe(
                    core: core,
                    tunnelProbeAddressSets: tunnelProbeAddressSets
                )
            } catch {
                let failure = Self.ipcFailureKind(for: error)
                guard ipcRecoveryPolicy.shouldRetryCoreProbe(
                    after: failure,
                    completedAttempts: completedAttempts
                ) else {
                    throw error
                }

                // The first callback may have been lost while NetworkExtension
                // replaced its App Message bridge. Drop the cached manager,
                // prove the currently published session is running, then issue
                // one fresh idempotent probe request.
                let originalError = error
                do {
                    try await recoverProviderIPC(core: core)
                } catch {
                    throw originalError
                }
            }
        }
    }

    private func performCoreProbe(
        core: CoreIdentifier,
        tunnelProbeAddressSets: [ProviderTunnelProbeAddressSet]
    ) async throws -> ProviderCoreProbeSnapshot? {
        let request = ProviderMessageRequest(
            kind: .coreProbe,
            tunnelProbeAddressSets: tunnelProbeAddressSets
        )
        let response = try await sendProviderRequest(request, core: core)
        if response.tunnelProbeSucceeded == true {
            return response.coreProbe
        }
        guard let coreProbe = response.coreProbe else {
            throw VPNProviderControllerError.providerResponseMissing
        }
        return coreProbe
    }

    /// Changes only sing-box's selector outbound. This never stops or starts
    /// the Network Extension session and returns the provider's actual state.
    func selectNode(core: CoreIdentifier, nodeID: UUID) async throws -> UUID {
        let request = ProviderMessageRequest(kind: .selectNode, nodeID: nodeID)
        let response = try await sendProviderRequest(request, core: core)
        guard let selectedNodeID = response.selectedNodeID else {
            throw VPNProviderControllerError.providerResponseMissing
        }
        return selectedNodeID
    }

    func selectedNode(core: CoreIdentifier) async throws -> UUID {
        let request = ProviderMessageRequest(kind: .selectedNode)
        let response = try await sendProviderRequest(request, core: core)
        guard let selectedNodeID = response.selectedNodeID else {
            throw VPNProviderControllerError.providerResponseMissing
        }
        return selectedNodeID
    }

    /// Rebuilds sing-box from a manifest stored in the shared database while
    /// retaining the existing Network Extension session. The provider returns
    /// the selector state actually installed by the reloaded service.
    func reloadConfiguration(
        core: CoreIdentifier,
        manifestID: UUID
    ) async throws -> UUID {
        let request = ProviderMessageRequest(
            kind: .reloadConfiguration,
            manifestID: manifestID
        )
        let response = try await sendProviderRequest(request, core: core)
        guard let selectedNodeID = response.selectedNodeID else {
            throw VPNProviderControllerError.providerResponseMissing
        }
        return selectedNodeID
    }

    /// Connected 入口路径 RTT。探测在扩展里绑物理网卡，不改隧道排除表。
    func measureEntryLatencies(
        core: CoreIdentifier,
        nodeIDs: [UUID]
    ) async throws -> [ProviderEntryLatencySample] {
        let request = ProviderMessageRequest(
            kind: .entryLatency,
            entryLatencyNodeIDs: Array(nodeIDs.prefix(ProviderEntryLatencyCode.maximumBatchCount))
        )
        let response = try await sendProviderRequest(request, core: core)
        guard let samples = response.entryLatencies else {
            throw VPNProviderControllerError.providerResponseMissing
        }
        return samples
    }

    /// Commits a verified hot reload or restores the Provider's exact previous
    /// sing-box JSON/catalog/network-route snapshot after verification fails.
    func finalizeConfigurationReload(
        core: CoreIdentifier,
        expectedNodeID: UUID,
        accept: Bool
    ) async throws -> UUID {
        let request = ProviderMessageRequest(
            kind: .finalizeConfigurationReload,
            nodeID: expectedNodeID,
            acceptConfigurationReload: accept
        )
        let response = try await sendProviderRequest(request, core: core)
        guard let selectedNodeID = response.selectedNodeID else {
            throw VPNProviderControllerError.providerResponseMissing
        }
        return selectedNodeID
    }

    private func sendProviderRequest(
        _ request: ProviderMessageRequest,
        core: CoreIdentifier,
        timeout: Duration = .seconds(15)
    ) async throws -> ProviderMessageResponse {
        var session: NETunnelProviderSession?
        do {
            try await waitForProviderMessageSlot()
            let resolvedSession = try await providerSession(for: core)
            session = resolvedSession
            let requestData = try ProviderMessageCodec.encode(request)
            let responseData = try await sendProviderMessage(
                requestData,
                session: resolvedSession,
                timeout: timeout
            )
            return try ProviderMessageCodec.decodeResponse(responseData, matching: request)
        } catch {
            Self.logProviderIPCFailure(
                error,
                operation: request.kind.rawValue,
                sessionStatus: session?.status
            )
            throw error
        }
    }

    private func waitForProviderReadiness(core: CoreIdentifier) async throws {
        var completedAttempts = 0
        var lastError: (any Error)?
        while completedAttempts < ipcRecoveryPolicy.maximumReadinessAttempts {
            completedAttempts += 1
            do {
                let response = try await sendProviderRequest(
                    ProviderMessageRequest(kind: .status),
                    core: core,
                    timeout: Self.providerReadinessMessageTimeout
                )
                switch response.status {
                case .running:
                    return
                case .preparing, .starting:
                    lastError = VPNProviderControllerError.providerStartFailed(
                        core,
                        diagnosticCode: "provider.runtime_not_ready"
                    )
                case let status?:
                    throw VPNProviderControllerError.providerStartFailed(
                        core,
                        diagnosticCode: "provider.runtime_\(status.rawValue)"
                    )
                case nil:
                    throw VPNProviderControllerError.providerResponseMissing
                }
            } catch {
                lastError = error
                guard ipcRecoveryPolicy.shouldRetryReadiness(
                    after: Self.ipcFailureKind(for: error),
                    completedAttempts: completedAttempts
                ) else {
                    throw error
                }
            }

            guard completedAttempts < ipcRecoveryPolicy.maximumReadinessAttempts else {
                break
            }
            try await Task.sleep(for: Self.providerReadinessRetryDelay)
        }
        throw lastError ?? VPNProviderControllerError.providerStartFailed(
            core,
            diagnosticCode: "provider.runtime_not_ready"
        )
    }

    private func recoverProviderIPC(core: CoreIdentifier) async throws {
        activeManager = nil
        try await Task.sleep(for: Self.providerReadinessRetryDelay)
        try await waitForProviderReadiness(core: core)
    }

    private static func ipcFailureKind(for error: Error) -> ProviderIPCFailureKind {
        switch error {
        case VPNProviderControllerError.providerResponseTimedOut:
            .responseTimedOut
        case VPNProviderControllerError.providerResponseMissing:
            .responseMissing
        case VPNProviderControllerError.providerSessionUnavailable,
             VPNProviderControllerError.providerConfigurationMissing:
            .sessionUnavailable
        case let ProviderMessageCodecError.providerRejected(code)
            where code == "provider.rate_limited":
            .rateLimited
        default:
            .other
        }
    }

    private func waitForProviderMessageSlot() async throws {
        let now = ContinuousClock.now
        let scheduledAt = max(now, nextProviderMessageAt)
        nextProviderMessageAt = scheduledAt + Self.providerMessageSpacing
        let delay = now.duration(to: scheduledAt)
        if delay > .zero {
            try await Task.sleep(for: delay)
        }
    }

    /// Uses the exact manager that completed the latest start whenever it is
    /// still active. Reloaded preference objects can briefly point at the old
    /// provider bridge while NetworkExtension tears one session down and binds
    /// the next, which makes an otherwise healthy post-start probe lose IPC.
    private func providerSession(for core: CoreIdentifier) async throws -> NETunnelProviderSession {
        if let activeManager, activeManager.core == core,
           Self.canSendProviderMessage(status: activeManager.manager.connection.status),
           let session = activeManager.manager.connection as? NETunnelProviderSession {
            return session
        }

        let managers = try await NETunnelProviderManager.loadAllFromPreferences()
        let matchingManagers = managers.filter {
            ($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier
                == ProviderBundleIdentifier.value(for: core)
        }
        guard !matchingManagers.isEmpty else {
            throw VPNProviderControllerError.providerConfigurationMissing(core)
        }

        let manager = matchingManagers.first(where: {
            Self.canSendProviderMessage(status: $0.connection.status)
        }) ?? matchingManagers[0]
        guard Self.canSendProviderMessage(status: manager.connection.status),
              let session = manager.connection as? NETunnelProviderSession else {
            throw VPNProviderControllerError.providerSessionUnavailable(
                core,
                status: manager.connection.status.rawValue
            )
        }
        activeManager = (core, manager)
        return session
    }

    private static func canSendProviderMessage(status: NEVPNStatus) -> Bool {
        switch status {
        case .connected, .reasserting:
            true
        default:
            false
        }
    }

    private static func logProviderIPCFailure(
        _ error: Error,
        operation: String,
        sessionStatus: NEVPNStatus?
    ) {
        #if DEBUG
        let systemError = error as NSError
        // Do not print descriptions, userInfo, request bytes, node IDs, or
        // endpoints. Error type/domain/code and NE status are sufficient to
        // distinguish stale sessions, missing replies, codec errors, and timeouts.
        print(
            "Routeva provider IPC diagnostic: operation=\(operation) "
                + "status=\(sessionStatus?.rawValue ?? -1) "
                + "type=\(String(reflecting: type(of: error))) "
                + "domain=\(systemError.domain) code=\(systemError.code)"
        )
        #endif
    }

    private static let providerMessageTimeout: Duration = .seconds(15)
    private static let providerReadinessMessageTimeout: Duration = .seconds(2)
    private static let providerReadinessRetryDelay: Duration = .milliseconds(300)
    private static let providerMessageSpacing: Duration = .milliseconds(225)

    private func sendProviderMessage(
        _ requestData: Data,
        session: NETunnelProviderSession,
        timeout: Duration
    ) async throws -> Data {
        try await withThrowingTaskGroup(of: Data.self) { group in
            group.addTask {
                let once = OnceThrowingContinuation<Data>()
                return try await withTaskCancellationHandler {
                    try await withCheckedThrowingContinuation { continuation in
                        once.arm(continuation)
                        do {
                            try session.sendProviderMessage(requestData) { response in
                                guard let response else {
                                    once.resume(
                                        throwing: VPNProviderControllerError.providerResponseMissing
                                    )
                                    return
                                }
                                once.resume(returning: response)
                            }
                        } catch {
                            once.resume(throwing: error)
                        }
                    }
                } onCancel: {
                    once.resume(throwing: CancellationError())
                }
            }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw VPNProviderControllerError.providerResponseTimedOut
            }
            do {
                guard let result = try await group.next() else {
                    throw VPNProviderControllerError.providerResponseMissing
                }
                group.cancelAll()
                return result
            } catch {
                group.cancelAll()
                throw error
            }
        }
    }

    private func ensureStartCurrent(_ generation: UInt64) throws {
        try Task.checkCancellation()
        guard generation == startGeneration else { throw CancellationError() }
    }

    private func savePreferencesAllowingPermissionPrompt(
        _ manager: NETunnelProviderManager
    ) async throws {
        do {
            try await AbandonableAsync.firstFinished(
                timeout: .seconds(15),
                operation: { try await manager.saveToPreferences() },
                timeoutError: {
                    VPNProviderControllerError.providerStartFailed(
                        .singBox,
                        diagnosticCode: "provider.configuration_save_timed_out"
                    )
                }
            )
        } catch let error as VPNProviderControllerError {
            throw error
        } catch {
            throw VPNProviderControllerError.providerStartFailed(
                .singBox,
                diagnosticCode: Self.startRequestDiagnosticCode(for: error)
            )
        }
    }

    /// 首次授权可能把 App 切到系统 VPN 页。此时不要 start；等回前台再读一次 isEnabled。
    private func waitUntilReadyToStart(
        core: CoreIdentifier,
        generation: UInt64,
        isSceneActive: @escaping @Sendable () async -> Bool
    ) async throws -> NETunnelProviderManager {
        let deadline = ContinuousClock.now + .seconds(20)
        while true {
            try ensureStartCurrent(generation)
            let managers = try await loadManagersFromPreferences()
            let manager = managers[core]
            let enabled = manager?.isEnabled == true
            let active = await isSceneActive()
            switch VPNPermissionGate.decision(isEnabled: enabled, sceneIsActive: active) {
            case .startTunnel:
                guard let manager else {
                    throw VPNProviderControllerError.providerConfigurationMissing(core)
                }
                return manager
            case .failNotPersisted:
                throw VPNProviderControllerError.providerStartFailed(
                    core,
                    diagnosticCode: "provider.configuration_activation_not_persisted"
                )
            case .waitForForeground:
                guard ContinuousClock.now < deadline else {
                    throw VPNProviderControllerError.providerStartFailed(
                        core,
                        diagnosticCode: "provider.configuration_save_timed_out"
                    )
                }
                try await Task.sleep(for: .milliseconds(200))
            }
        }
    }

    private func configureManagers(
        activating selected: CoreIdentifier
    ) async throws -> [CoreIdentifier: NETunnelProviderManager] {
        // Keep the release build's single provider configuration enabled.
        let saveOrder = CoreIdentifier.allCases.filter { $0 != selected } + [selected]
        for core in saveOrder {
            // A successful save can make previously loaded managers stale, so
            // reload before mutating the release provider configuration.
            let existing = try await NETunnelProviderManager.loadAllFromPreferences()
            let bundleIdentifier = ProviderBundleIdentifier.value(for: core)
            let manager = existing.first { manager in
                (manager.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == bundleIdentifier
            } ?? NETunnelProviderManager()

            let shouldEnable = core == selected
            if managerMatchesDesiredConfiguration(
                manager,
                core: core,
                bundleIdentifier: bundleIdentifier,
                shouldEnable: shouldEnable
            ) {
                continue
            }

            let tunnelProtocol = (manager.protocolConfiguration as? NETunnelProviderProtocol)
                ?? NETunnelProviderProtocol()
            tunnelProtocol.providerBundleIdentifier = bundleIdentifier
            tunnelProtocol.serverAddress = "Routeva"
            tunnelProtocol.providerConfiguration = [
                "schema-version": RuntimeManifest.currentSchemaVersion,
                "core": core.rawValue,
            ]
            // The Packet Tunnel's explicit default route captures user traffic.
            // Keep Apple's stronger include-all mode disabled so the host-sized
            // excluded routes for proxy endpoints and ECH bootstrap resolvers
            // remain on the physical interface. This matches sing-box for
            // Apple's default and avoids routing the proxy's own prerequisites
            // back into Routeva's TUN.
            tunnelProtocol.includeAllNetworks = false
            tunnelProtocol.excludeLocalNetworks = false
            tunnelProtocol.enforceRoutes = false
            if #available(iOS 16.4, *) {
                tunnelProtocol.excludeAPNs = false
                tunnelProtocol.excludeCellularServices = false
            }
            if #available(iOS 17.4, *) {
                tunnelProtocol.excludeDeviceCommunication = false
            }
            manager.protocolConfiguration = tunnelProtocol
            manager.localizedDescription = "Routeva"
            manager.isEnabled = shouldEnable
            try await savePreferencesAllowingPermissionPrompt(manager)
            // Apple：save 之后必须再 load，否则 startVPNTunnel 可能打在过期配置上。
            try await manager.loadFromPreferences()
        }

        // Only return objects loaded after the final preference write. These
        // are the instances that may safely issue startVPNTunnel requests.
        return try await loadManagersFromPreferences()
    }

    private func managersMatchDesiredConfiguration(
        _ managers: [CoreIdentifier: NETunnelProviderManager],
        activating selected: CoreIdentifier
    ) -> Bool {
        CoreIdentifier.allCases.allSatisfy { core in
            guard let manager = managers[core] else { return false }
            return managerMatchesDesiredConfiguration(
                manager,
                core: core,
                bundleIdentifier: ProviderBundleIdentifier.value(for: core),
                shouldEnable: core == selected
            )
        }
    }

    private func managerMatchesDesiredConfiguration(
        _ manager: NETunnelProviderManager,
        core: CoreIdentifier,
        bundleIdentifier: String,
        shouldEnable: Bool
    ) -> Bool {
        guard let tunnelProtocol = manager.protocolConfiguration as? NETunnelProviderProtocol,
              tunnelProtocol.providerBundleIdentifier == bundleIdentifier,
              tunnelProtocol.serverAddress == "Routeva",
              tunnelProtocol.providerConfiguration?["schema-version"] as? Int
                  == RuntimeManifest.currentSchemaVersion,
              tunnelProtocol.providerConfiguration?["core"] as? String == core.rawValue,
              tunnelProtocol.includeAllNetworks == false,
              tunnelProtocol.excludeLocalNetworks == false,
              tunnelProtocol.enforceRoutes == false,
              manager.localizedDescription == "Routeva",
              manager.isEnabled == shouldEnable
        else { return false }
        if #available(iOS 16.4, *),
           tunnelProtocol.excludeAPNs || tunnelProtocol.excludeCellularServices {
            return false
        }
        if #available(iOS 17.4, *), tunnelProtocol.excludeDeviceCommunication {
            return false
        }
        return true
    }

    private func loadManagersFromPreferences() async throws -> [CoreIdentifier: NETunnelProviderManager] {
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()
        var result: [CoreIdentifier: NETunnelProviderManager] = [:]
        for manager in managers {
            guard let bundleIdentifier = (manager.protocolConfiguration as? NETunnelProviderProtocol)?
                .providerBundleIdentifier,
                  let core = CoreIdentifier.allCases.first(where: {
                      ProviderBundleIdentifier.value(for: $0) == bundleIdentifier
                  })
            else { continue }
            result[core] = manager
        }
        return result
    }

    private func removeLegacyRoutevaManagers() async throws {
        let currentBundleIdentifier = ProviderBundleIdentifier.value(for: .singBox)
        let legacyPrefix = "com.yilinglabs.routeva.PacketTunnel."
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()
        for manager in managers {
            guard let bundleIdentifier = (manager.protocolConfiguration as? NETunnelProviderProtocol)?
                    .providerBundleIdentifier,
                  bundleIdentifier.hasPrefix(legacyPrefix),
                  bundleIdentifier != currentBundleIdentifier
            else { continue }
            switch manager.connection.status {
            case .connected, .connecting, .reasserting:
                manager.connection.stopVPNTunnel()
                try? await waitForStatus(
                    manager,
                    desired: .disconnected,
                    timeout: .seconds(10)
                )
            case .disconnecting:
                try? await waitForStatus(
                    manager,
                    desired: .disconnected,
                    timeout: .seconds(10)
                )
            default:
                break
            }
            try await manager.removeFromPreferences()
        }
    }

    private func managerForStop(core: CoreIdentifier) async -> NETunnelProviderManager? {
        if let activeManager, activeManager.core == core {
            return activeManager.manager
        }
        guard let managers = try? await loadManagersFromPreferences() else { return nil }
        return managers[core]
    }

    private func stopOtherManagers(
        _ managers: [CoreIdentifier: NETunnelProviderManager],
        except selected: CoreIdentifier
    ) async throws {
        let others = managers.filter { $0.key != selected }.map(\.value)
        others.forEach { manager in
            switch manager.connection.status {
            case .connected, .connecting, .reasserting:
                manager.connection.stopVPNTunnel()
            default:
                break
            }
        }

        let deadline = ContinuousClock.now + .seconds(10)
        while others.contains(where: { manager in
            switch manager.connection.status {
            case .connected, .connecting, .disconnecting, .reasserting:
                true
            default:
                false
            }
        }) {
            guard ContinuousClock.now < deadline else {
                throw VPNProviderControllerError.switchTimedOut
            }
            try await Task.sleep(for: .milliseconds(100))
        }
    }

    private func stopForFreshSession(_ manager: NETunnelProviderManager) async throws {
        switch manager.connection.status {
        case .connected, .connecting, .reasserting:
            manager.connection.stopVPNTunnel()
            try await waitForStatus(
                manager,
                desired: .disconnected,
                timeout: .seconds(10)
            )
        case .disconnecting:
            try await waitForStatus(
                manager,
                desired: .disconnected,
                timeout: .seconds(10)
            )
        default:
            break
        }
    }

    private func waitForStableDisconnection(core: CoreIdentifier) async throws {
        let deadline = ContinuousClock.now + Self.providerTeardownTimeout
        var firstInactiveObservation: ContinuousClock.Instant?
        while true {
            try Task.checkCancellation()
            let managers = try await loadManagersFromPreferences()
            let status = managers[core]?.connection.status ?? .invalid
            let now = ContinuousClock.now
            switch status {
            case .invalid, .disconnected:
                if let firstInactiveObservation,
                   now - firstInactiveObservation >= Self.providerTeardownQuietInterval {
                    return
                }
                if firstInactiveObservation == nil {
                    firstInactiveObservation = now
                }
            default:
                firstInactiveObservation = nil
            }
            guard now < deadline else {
                throw VPNProviderControllerError.switchTimedOut
            }
            try await Task.sleep(for: .milliseconds(100))
        }
    }

    private func waitForStatus(
        _ manager: NETunnelProviderManager,
        desired: NEVPNStatus,
        timeout: Duration,
        startupRequestedAt: Date? = nil
    ) async throws {
        let deadline = ContinuousClock.now + timeout
        while true {
            try Task.checkCancellation()
            let status = manager.connection.status
            if status == desired { return }
            let core = CoreIdentifier.allCases.first(where: {
                ProviderBundleIdentifier.value(for: $0)
                    == (manager.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier
            }) ?? .singBox
            switch status {
            case .invalid where desired == .connected:
                throw VPNProviderControllerError.providerConfigurationMissing(core)
            case .disconnected where desired == .connected:
                if let diagnostic = freshStartupDiagnostic(
                    for: core,
                    requestedAt: startupRequestedAt
                ) {
                    // The provider writes this immediately before completing
                    // `startTunnel`. NEVPNConnection can still briefly expose
                    // a stale `.disconnected` value at that boundary.
                    if diagnostic.stableErrorCode != nil {
                        throw providerStartFailure(
                            for: core,
                            requestedAt: startupRequestedAt
                        )
                    }
                }
            default:
                break
            }
            guard ContinuousClock.now < deadline else {
                if desired == .connected, status == .disconnected {
                    throw providerStartFailure(
                        for: core,
                        requestedAt: startupRequestedAt
                    )
                }
                throw VPNProviderControllerError.switchTimedOut
            }
            try await Task.sleep(for: .milliseconds(100))
        }
    }

    private static let providerTeardownQuietInterval: Duration = .milliseconds(300)
    private static let providerTeardownTimeout: Duration = .seconds(3)

    private func freshStartupDiagnostic(
        for core: CoreIdentifier,
        requestedAt: Date?
    ) -> ProviderStartupDiagnosticSnapshot? {
        guard let snapshot = startupDiagnostics.snapshot(),
              snapshot.core == core,
              requestedAt.map({ snapshot.updatedAt >= $0 }) ?? true
        else { return nil }
        return snapshot
    }

    private func providerStartFailure(
        for core: CoreIdentifier,
        requestedAt: Date? = nil
    ) -> VPNProviderControllerError {
        guard let snapshot = freshStartupDiagnostic(
            for: core,
            requestedAt: requestedAt
        ) else {
            return .providerStartFailed(core, diagnosticCode: nil)
        }
        // Defensive fallback: `running` is success evidence, never a failure
        // code, even if a caller reaches this path after a later session race.
        let code = snapshot.stableErrorCode ?? (snapshot.confirmsRunning
            ? nil
            : "provider.stage.\(snapshot.stage.rawValue)")
        return .providerStartFailed(core, diagnosticCode: code)
    }
}

private enum ProviderStartOptionKey {
    static let manifestID = "routeva.manifest-id"
}

/// sendProviderMessage 回调、超时与 Task 取消可能同时到达；只 resume 一次。
private final class OnceThrowingContinuation<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T, Error>?
    private var pendingError: Error?
    private var didResume = false

    func arm(_ continuation: CheckedContinuation<T, Error>) {
        lock.lock()
        if didResume {
            lock.unlock()
            return
        }
        if let pendingError {
            didResume = true
            lock.unlock()
            continuation.resume(throwing: pendingError)
            return
        }
        self.continuation = continuation
        lock.unlock()
    }

    func resume(returning value: sending T) {
        lock.lock()
        guard !didResume else {
            lock.unlock()
            return
        }
        didResume = true
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume(returning: value)
    }

    func resume(throwing error: Error) {
        lock.lock()
        guard !didResume else {
            lock.unlock()
            return
        }
        if let continuation {
            didResume = true
            self.continuation = nil
            lock.unlock()
            continuation.resume(throwing: error)
            return
        }
        pendingError = error
        lock.unlock()
    }
}
