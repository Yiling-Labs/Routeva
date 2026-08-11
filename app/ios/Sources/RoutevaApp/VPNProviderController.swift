import DataKit
import Foundation
@preconcurrency import NetworkExtension
import SharedKit

enum ProviderBundleIdentifier {
    static func value(for core: CoreIdentifier) -> String {
        "com.yilinglabs.routeva.PacketTunnel.SingBox"
    }
}

enum VPNProviderControllerError: LocalizedError {
    case switchTimedOut
    case providerConfigurationMissing(CoreIdentifier)
    case providerStartFailed(CoreIdentifier, diagnosticCode: String?)
    case providerResponseMissing

    var errorDescription: String? {
        switch self {
        case .switchTimedOut:
            "The active VPN provider did not stop before the core switch timed out."
        case let .providerConfigurationMissing(core):
            "The VPN configuration for \(core.rawValue) is unavailable."
        case let .providerStartFailed(core, _):
            "The \(core.rawValue) VPN provider stopped before it finished starting."
        case .providerResponseMissing:
            "The VPN provider did not return a response."
        }
    }
}

/// Owns the process boundary between the two Go runtimes. Automatic selection
/// happens before a provider starts. Fallback always stops one extension and
/// starts the other; an already connected session is never hot-swapped.
actor VPNProviderController {
    private let selector = CoreSelector()
    private let startupDiagnostics = ProviderStartupDiagnosticStore()
    /// The manager that completed the latest start in this App process.
    /// Keeping it avoids a preferences round-trip before an explicit user
    /// stop can even be submitted to NetworkExtension.
    private var activeManager: (core: CoreIdentifier, manager: NETunnelProviderManager)?

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
        try await start(core: decision.selected, manifestID: manifest.manifestID)
        return decision
    }

    func disconnectAll() async throws {
        activeManager?.manager.connection.stopVPNTunnel()
        activeManager = nil
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()
        managers.forEach { $0.connection.stopVPNTunnel() }
    }

    func start(core: CoreIdentifier, manifestID: UUID) async throws {
        try await removeLegacyRoutevaManagers()
        let existingManagers = try await loadManagersFromPreferences()
        if let existingManager = existingManagers[core] {
            // Every attempt has a new manifest ID. Never reuse a same-core
            // session that merely still reports Connected: it may be an old
            // bridge in the asynchronous cancel/teardown window. Serialize
            // provider lifetimes before sending the new manifest.
            try await stopForFreshSession(existingManager)
        }

        // Stop any stale Routeva session before starting a fresh manifest.
        try await stopOtherManagers(existingManagers, except: core)
        var managers = managersMatchDesiredConfiguration(
            existingManagers,
            activating: core
        ) ? existingManagers : try await configureManagers(activating: core)
        guard var manager = managers[core] else {
            throw VPNProviderControllerError.providerConfigurationMissing(core)
        }
        guard manager.isEnabled else {
            throw VPNProviderControllerError.providerStartFailed(
                core,
                diagnosticCode: "provider.configuration_activation_not_persisted"
            )
        }

        startupDiagnostics.clear()
        do {
            try manager.connection.startVPNTunnel(options: [
                ProviderStartOptionKey.manifestID: manifestID.uuidString as NSString,
            ])
        } catch {
            if Self.shouldReactivateConfiguration(after: error) {
                // Settings or another VPN may have changed the single enabled
                // enterprise configuration between our load and start request.
                managers = try await configureManagers(activating: core)
                guard let refreshed = managers[core], refreshed.isEnabled else {
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
        try await waitForStatus(manager, desired: .connected, timeout: .seconds(20))
        activeManager = (core, manager)
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
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()
        guard let manager = managers.first(where: {
            ($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier
                == ProviderBundleIdentifier.value(for: core)
        }), let session = manager.connection as? NETunnelProviderSession else {
            throw VPNProviderControllerError.providerConfigurationMissing(core)
        }
        let request = ProviderMessageRequest(kind: .traffic)
        let requestData = try ProviderMessageCodec.encode(request)
        let responseData: Data = try await withCheckedThrowingContinuation { continuation in
            do {
                try session.sendProviderMessage(requestData) { response in
                    guard let response else {
                        continuation.resume(throwing: VPNProviderControllerError.providerResponseMissing)
                        return
                    }
                    continuation.resume(returning: response)
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
        let response = try ProviderMessageCodec.decodeResponse(responseData, matching: request)
        guard let traffic = response.traffic else {
            throw VPNProviderControllerError.providerResponseMissing
        }
        return traffic
    }

    func queryDataPlane(core: CoreIdentifier) async throws -> ProviderDataPlaneSnapshot {
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()
        guard let manager = managers.first(where: {
            ($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier
                == ProviderBundleIdentifier.value(for: core)
        }), let session = manager.connection as? NETunnelProviderSession else {
            throw VPNProviderControllerError.providerConfigurationMissing(core)
        }
        let request = ProviderMessageRequest(kind: .dataPlane)
        let requestData = try ProviderMessageCodec.encode(request)
        let responseData: Data = try await withCheckedThrowingContinuation { continuation in
            do {
                try session.sendProviderMessage(requestData) { response in
                    guard let response else {
                        continuation.resume(throwing: VPNProviderControllerError.providerResponseMissing)
                        return
                    }
                    continuation.resume(returning: response)
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
        let response = try ProviderMessageCodec.decodeResponse(responseData, matching: request)
        guard let dataPlane = response.dataPlane else {
            throw VPNProviderControllerError.providerResponseMissing
        }
        return dataPlane
    }

    func probeCore(
        core: CoreIdentifier,
        tunnelProbeAddressSets: [ProviderTunnelProbeAddressSet] = []
    ) async throws -> ProviderCoreProbeSnapshot? {
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()
        guard let manager = managers.first(where: {
            ($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier
                == ProviderBundleIdentifier.value(for: core)
        }), let session = manager.connection as? NETunnelProviderSession else {
            throw VPNProviderControllerError.providerConfigurationMissing(core)
        }
        let request = ProviderMessageRequest(
            kind: .coreProbe,
            tunnelProbeAddressSets: tunnelProbeAddressSets
        )
        let requestData = try ProviderMessageCodec.encode(request)
        let responseData: Data = try await withCheckedThrowingContinuation { continuation in
            do {
                try session.sendProviderMessage(requestData) { response in
                    guard let response else {
                        continuation.resume(
                            throwing: VPNProviderControllerError.providerResponseMissing
                        )
                        return
                    }
                    continuation.resume(returning: response)
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
        let response = try ProviderMessageCodec.decodeResponse(responseData, matching: request)
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
        core: CoreIdentifier
    ) async throws -> ProviderMessageResponse {
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()
        guard let manager = managers.first(where: {
            ($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier
                == ProviderBundleIdentifier.value(for: core)
        }), let session = manager.connection as? NETunnelProviderSession else {
            throw VPNProviderControllerError.providerConfigurationMissing(core)
        }
        let requestData = try ProviderMessageCodec.encode(request)
        let responseData: Data = try await withCheckedThrowingContinuation { continuation in
            do {
                try session.sendProviderMessage(requestData) { response in
                    guard let response else {
                        continuation.resume(
                            throwing: VPNProviderControllerError.providerResponseMissing
                        )
                        return
                    }
                    continuation.resume(returning: response)
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
        return try ProviderMessageCodec.decodeResponse(responseData, matching: request)
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
            // Smart, Global, and Direct all require provider classification of
            // the device's routable traffic. Apple's strong capture contract is
            // includeAllNetworks; the core's physical-interface binding keeps
            // the proxy transport outside the TUN. Keep route enforcement off:
            // forcing it made WebKit flows fail NECP path evaluation on iOS 26
            // before they reached PacketFlow.
            tunnelProtocol.includeAllNetworks = true
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
            manager.localizedDescription = "Routeva (\(core.rawValue))"
            manager.isEnabled = shouldEnable
            try await manager.saveToPreferences()
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
              tunnelProtocol.includeAllNetworks == true,
              tunnelProtocol.excludeLocalNetworks == false,
              tunnelProtocol.enforceRoutes == false,
              manager.localizedDescription == "Routeva (\(core.rawValue))",
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

    private func waitForStatus(
        _ manager: NETunnelProviderManager,
        desired: NEVPNStatus,
        timeout: Duration
    ) async throws {
        let deadline = ContinuousClock.now + timeout
        let disconnectedGraceDeadline = ContinuousClock.now + .seconds(2)
        var observedStartupTransition = false
        while manager.connection.status != desired {
            try Task.checkCancellation()
            let core = CoreIdentifier.allCases.first(where: {
                ProviderBundleIdentifier.value(for: $0)
                    == (manager.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier
            }) ?? .singBox
            switch manager.connection.status {
            case .connecting, .reasserting, .disconnecting:
                observedStartupTransition = true
            case .invalid where desired == .connected:
                throw VPNProviderControllerError.providerConfigurationMissing(core)
            case .disconnected where desired == .connected
                && (observedStartupTransition || ContinuousClock.now >= disconnectedGraceDeadline):
                throw providerStartFailure(for: core)
            default:
                break
            }
            guard ContinuousClock.now < deadline else { throw VPNProviderControllerError.switchTimedOut }
            try await Task.sleep(for: .milliseconds(100))
        }
    }

    private func providerStartFailure(for core: CoreIdentifier) -> VPNProviderControllerError {
        guard let snapshot = startupDiagnostics.snapshot(), snapshot.core == core else {
            return .providerStartFailed(core, diagnosticCode: nil)
        }
        let code = snapshot.stableErrorCode
            ?? "provider.stage.\(snapshot.stage.rawValue)"
        return .providerStartFailed(core, diagnosticCode: code)
    }
}

private enum ProviderStartOptionKey {
    static let manifestID = "routeva.manifest-id"
}
