import CoreBridge
import DataKit
import Foundation
import Network
import SharedKit
import SwiftUI

@MainActor
final class RoutevaAppModel: ObservableObject {
    enum OnboardingStep: Equatable {
        case welcome
        case dataAndPrivacy
        case complete
    }

    enum ConnectionState: Equatable {
        case idle
        case connecting
        case connected(sessionStartedAt: Date)
        case failed(DiagnosticCase)
    }

    enum RepairPresentationState: Equatable {
        case idle
        case running
    }

    enum PresentedSurface: Identifiable, Equatable {
        case addSubscription
        case subscriptions
        case locations
        case settings

        var id: String {
            switch self {
            case .addSubscription: "add-subscription"
            case .subscriptions: "subscriptions"
            case .locations: "locations"
            case .settings: "settings"
            }
        }
    }

    @Published var onboardingStep: OnboardingStep
    @Published var connectionState: ConnectionState = .idle
    @Published var presentedSurface: PresentedSurface?
    @Published var subscriptions: [SubscriptionSummary] = []
    @Published var selectedNodeIndex = 0
    @Published var routingMode: RoutingMode = .automatic
    @Published var dnsPreset: DNSPreset = .automatic
    @Published var overrides: [DomainOverrideSummary] = []
    @Published var liveDownloadMbps = 0.0
    @Published var liveUploadMbps = 0.0
    @Published var importConfirmation: ImportConfirmation?
    @Published var currentDiagnosticResult: DiagnosticResult?
    @Published private(set) var latestActivityRecord: ActivityRecord?
    @Published var repairState: RepairPresentationState = .idle
    @Published var overrideReconnectPrompt = false
    @Published var connectionFailureMessage: String?
    @Published var nodeFailoverToast: String?
    @Published var nodeLatencies: [UUID: NodeLatencyStatus] = [:]
    @Published var isTestingNodes = false
    @Published var updatingSubscriptionIDs: Set<UUID> = []
    @Published var deletingSubscriptionIDs: Set<UUID> = []
    @Published var subscriptionUpdateFailureToast = false
    @Published var autoUpdateEnabled = true

    private static let onboardingKey = "routeva.onboarding.data-privacy.completed"
    private static let autoUpdateKey = "routeva.subscription.auto-update.enabled"
    #if DEBUG
    private static let debugStartupDurationKey = "routeva.debug.last-startup-duration"
    private static let debugProviderStartupDurationKey =
        "routeva.debug.last-provider-startup-duration"
    #endif
    private let defaults: UserDefaults
    private let database: RoutevaDatabase?
    private let importService: SubscriptionImportService?
    private let secrets: (any SecretStoring)?
    private let payloadLoader = SubscriptionPayloadLoader()
    private let providerController = VPNProviderController()
    private let connectionCoordinator = ProviderConnectionCoordinator()
    private let connectivityProbe = ConnectivityProbe()
    private let diagnosticEngine = DiagnosticEngine()
    private let repairCoordinator = RepairCoordinator()
    private let nodeSelectionMutationGate = NodeSelectionMutationGate()
    private var connectionTask: Task<Void, Never>?
    private var disconnectionTask: Task<Void, Never>?
    private var nodeSelectionTask: Task<Void, Never>?
    private var nodeSelectionRequestID: UUID?
    private var nodeSelectionIntentID: UUID?
    private var repairTask: Task<Void, Never>?
    private var trafficTask: Task<Void, Never>?
    private var trafficTaskID: UUID?
    private var postConnectProbeTask: Task<Void, Never>?
    private var postConnectProbeTaskID: UUID?
    private var trafficRateSampler = ProviderTrafficRateSampler()
    private var connectedCore: CoreIdentifier?
    private var verifiedNodeID: UUID?
    private var runtimeCatalogNodeIDs: Set<UUID> = []
    private var connectedTunnelProbeAddressSets: [ProviderTunnelProbeAddressSet] = []
    private var connectedDirectRouteAddresses: [String] = []
    /// Privacy-safe probe counter vector (counts only) from the latest failed
    /// connection attempt. Surfaced only in the DEBUG failure notice.
    private var probeCounterSummary: String?
    private var isHomeVisible = false
    private var isSceneActive = true
    private let deviceID: String
    private var overrideSyncService: CloudOverrideSyncService?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        autoUpdateEnabled = defaults.object(forKey: Self.autoUpdateKey) as? Bool ?? true
        deviceID = Self.loadOrCreateDeviceID(defaults: defaults)
        #if DEBUG
        let uiTestIdentifier = ProcessInfo.processInfo.environment["ROUTEVA_UI_TEST_DATABASE"]
        #else
        let uiTestIdentifier: String? = nil
        #endif
        onboardingStep = uiTestIdentifier == nil
            ? (defaults.bool(forKey: Self.onboardingKey) ? .complete : .welcome)
            : .complete

        let opened: RoutevaDatabase?
        if let uiTestIdentifier {
            let filename = "RoutevaUITest-\(uiTestIdentifier).sqlite"
            opened = try? RoutevaDatabase(
                databaseURL: FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            )
        } else {
            #if DEBUG && targetEnvironment(simulator)
            let directory = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            )[0].appendingPathComponent("RoutevaSimulator", isDirectory: true)
            try? FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            opened = try? RoutevaDatabase(
                databaseURL: directory.appendingPathComponent(RoutevaDatabase.databaseFilename)
            )
            #else
            opened = try? RoutevaDatabase.openAppGroupDatabase()
            #endif
        }
        if let opened {
            database = opened
            #if DEBUG
            let secretStore: any SecretStoring
            if uiTestIdentifier != nil {
                secretStore = UITestMemorySecretStore()
            } else {
                #if targetEnvironment(simulator)
                // Unsigned local Simulator apps cannot use Routeva's production
                // shared Keychain access group. Keep this isolated from both the
                // signed device App and its Packet Tunnel extensions.
                secretStore = SharedKeychainStore(
                    serviceName: "\(SharedKeychainStore.service).simulator",
                    accessGroup: nil
                )
                #else
                secretStore = SharedKeychainStore()
                #endif
            }
            #else
            let secretStore: any SecretStoring = SharedKeychainStore()
            #endif
            importService = SubscriptionImportService(database: opened, secrets: secretStore)
            secrets = secretStore
            if uiTestIdentifier == nil {
                #if DEBUG && targetEnvironment(simulator)
                // An unsigned Simulator build has no CloudKit container
                // entitlement. Device builds keep private-database syncing.
                overrideSyncService = nil
                #else
                overrideSyncService = CloudOverrideSyncService(localDatabase: opened)
                #endif
            }
        } else {
            database = nil
            importService = nil
            secrets = nil
        }
        Task { [weak self] in
            await self?.reloadSubscriptions()
            await self?.refreshActiveSubscriptionOnColdLaunchIfNeeded()
            await self?.reloadOverrides()
            await self?.reloadLatestActivity()
            await self?.syncOverrides()
        }
    }

    var activeSubscription: SubscriptionSummary? {
        subscriptions.first(where: \.isActive)
    }

    var availableNodes: [NodeSummary] {
        activeSubscription?.nodes ?? []
    }

    var redactedDiagnosticReport: String {
        var lines = [
            "Routeva redacted diagnostic report",
            "schema: 1",
            "generatedAt: \(ISO8601DateFormatter().string(from: .now))",
            "routingMode: \(routingMode.runtimeValue.rawValue)",
            "dnsPreset: \(dnsPreset.runtimeValue.rawValue)",
        ]
        if let result = currentDiagnosticResult {
            lines.append("bucket: \(result.bucket.rawValue)")
            lines.append("errorCode: \(result.stableErrorCode)")
            lines.append("confidence: \(result.confidence.rawValue)")
            lines.append(contentsOf: result.evidence.map {
                "check: \($0.layer.rawValue),\($0.checkStatus.rawValue),\($0.errorCode ?? "none")"
            })
        } else if let latestActivityRecord {
            lines.append("lastActivityAt: \(ISO8601DateFormatter().string(from: latestActivityRecord.createdAt))")
            lines.append("errorCode: \(latestActivityRecord.eventCode)")
            lines.append("bucket: \(latestActivityRecord.failureBucket ?? "none")")
            lines.append("evidence: \(latestActivityRecord.redactedSummary)")
        } else {
            lines.append("diagnostic: none")
        }
        #if DEBUG
        if let duration = defaults.object(forKey: Self.debugStartupDurationKey) as? Double {
            lines.append(String(format: "lastStartupSeconds: %.3f", duration))
        }
        if let duration = defaults.object(
            forKey: Self.debugProviderStartupDurationKey
        ) as? Double {
            lines.append(String(format: "lastProviderStartupSeconds: %.3f", duration))
        }
        #endif
        lines.append("Contains no subscription URL, credentials, endpoint, Core config, or browsing history.")
        return lines.joined(separator: "\n")
    }

    func completeOnboarding(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: Self.onboardingKey)
        onboardingStep = .complete
    }

    func requestConnection() {
        guard activeSubscription != nil, !availableNodes.isEmpty else {
            presentedSurface = .addSubscription
            return
        }
        guard connectionTask == nil, disconnectionTask == nil else { return }
        connectionFailureMessage = nil
        nodeFailoverToast = nil
        cancelNodeSelection()
        probeCounterSummary = nil
        cancelPostConnectProbe()
        #if DEBUG && targetEnvironment(simulator)
        connectionState = .idle
        connectionFailureMessage = "VPN connection testing requires a signed build on a physical iPhone."
        return
        #endif
        connectionState = .connecting
        let startupStartedAt = Date()
        connectionTask = Task { [weak self] in
            guard let self else { return }
            defer { connectionTask = nil }
            let trace = ConnectionDiagnosticTrace()
            do {
                try await establishConnection(trace: trace)
                #if DEBUG
                let duration = Date().timeIntervalSince(startupStartedAt)
                defaults.set(duration, forKey: Self.debugStartupDurationKey)
                print(String(format: "Routeva VPN startup timing: total=%.3fs", duration))
                #endif
            } catch is CancellationError {
                connectionState = .idle
            } catch {
                await presentDiagnostic(from: trace)
            }
        }
    }

    func disconnect() {
        guard case .connected = connectionState, disconnectionTask == nil else { return }
        connectionTask?.cancel()
        connectionTask = nil
        cancelNodeSelection()
        cancelPostConnectProbe()
        stopTrafficPolling()
        trafficRateSampler.reset()
        connectedCore = nil
        clearConnectedNodeState()
        // Do not keep Home visually connected while iOS asynchronously reaps
        // a provider whose stop command is being submitted immediately below.
        connectionState = .idle
        liveDownloadMbps = 0
        liveUploadMbps = 0
        let controller = providerController
        let stopStartedAt = Date()
        disconnectionTask = Task { [weak self] in
            guard let self else { return }
            defer { disconnectionTask = nil }
            await connectionCoordinator.stop(
                stopProvider: { core in await controller.requestStop(core: core) }
            )
            #if DEBUG
            print(String(
                format: "Routeva VPN stop command submitted in %.3fs",
                Date().timeIntervalSince(stopStartedAt)
            ))
            #endif
        }
    }

    func setHomeVisible(_ visible: Bool) {
        isHomeVisible = visible
        refreshTrafficPolling()
    }

    func setSceneActive(_ active: Bool) {
        isSceneActive = active
        refreshTrafficPolling()
        if active {
            Task {
                await syncOverrides()
                await reconcileSelectedNodeIfNeeded()
            }
        }
    }

    func setRoutingMode(_ mode: RoutingMode) {
        guard routingMode != mode else { return }
        let shouldReconnect: Bool
        if case .connected = connectionState { shouldReconnect = true } else { shouldReconnect = false }
        routingMode = mode
        if shouldReconnect { applyOverrideChangesAndReconnect() }
    }

    func saveOverride(domain: String, action: DomainOverrideSummary.Action) async {
        guard let database, let normalized = Self.normalizedDomain(domain) else { return }
        try? await database.upsertOverride(DomainOverrideRecord(
            domain: normalized,
            action: action.storageValue,
            isEnabled: true,
            isDeleted: false,
            deviceID: deviceID
        ))
        await reloadOverrides()
        markOverrideChangePendingIfConnected()
        await syncOverrides()
    }

    func setOverrideEnabled(domain: String, enabled: Bool) async {
        guard let database,
              let current = try? await database.overridesIncludingTombstones()
                .first(where: { $0.domain == domain }) else { return }
        try? await database.upsertOverride(DomainOverrideRecord(
            domain: current.domain,
            action: current.action,
            isEnabled: enabled,
            isDeleted: false,
            deviceID: deviceID
        ))
        await reloadOverrides()
        markOverrideChangePendingIfConnected()
        await syncOverrides()
    }

    func deleteOverride(domain: String) async {
        guard let database,
              let current = try? await database.overridesIncludingTombstones()
                .first(where: { $0.domain == domain }) else { return }
        try? await database.upsertOverride(DomainOverrideRecord(
            domain: current.domain,
            action: current.action,
            isEnabled: false,
            isDeleted: true,
            deviceID: deviceID
        ))
        await reloadOverrides()
        markOverrideChangePendingIfConnected()
        await syncOverrides()
    }

    func syncOverrides() async {
        try? await overrideSyncService?.merge()
        await reloadOverrides()
    }

    func applyOverrideChangesAndReconnect() {
        overrideReconnectPrompt = false
        guard connectionTask == nil, disconnectionTask == nil else { return }
        cancelNodeSelection()
        cancelPostConnectProbe()
        stopTrafficPolling()
        connectionState = .connecting
        let controller = providerController
        let startupStartedAt = Date()
        connectionTask = Task { [weak self] in
            guard let self else { return }
            defer { connectionTask = nil }
            await connectionCoordinator.stop(
                stopProvider: { core in await controller.stop(core: core) }
            )
            try? await controller.disconnectAll()
            connectedCore = nil
            clearConnectedNodeState()
            let trace = ConnectionDiagnosticTrace()
            do {
                try await establishConnection(trace: trace)
                #if DEBUG
                let duration = Date().timeIntervalSince(startupStartedAt)
                defaults.set(duration, forKey: Self.debugStartupDurationKey)
                print(String(format: "Routeva VPN startup timing: total=%.3fs", duration))
                #endif
            } catch is CancellationError {
                connectionState = .idle
            } catch {
                await presentDiagnostic(from: trace)
            }
        }
    }

    func approveAndRepair() {
        guard repairTask == nil, let diagnostic = currentDiagnosticResult,
              diagnostic.bucket == .clientFixable else { return }
        let supported = diagnostic.allowedActions.filter {
            [.switchHealthyNode, .switchDNSPreset, .rebuildTunnel].contains($0)
        }
        let plan = RepairPlan(candidates: supported.map {
            RepairCandidate(action: $0, verificationCode: "probe.routeva.fixed_content")
        })
        repairState = .running
        repairTask = Task { [weak self] in
            guard let self else { return }
            defer {
                repairTask = nil
                repairState = .idle
            }
            do {
                _ = try await repairCoordinator.execute(
                    diagnostic: diagnostic,
                    plan: plan,
                    userApproved: true,
                    makeSnapshot: { [weak self] in
                        guard let self else { throw CancellationError() }
                        return try await self.makeRepairSnapshot()
                    },
                    apply: { [weak self] action in
                        guard let self else { throw CancellationError() }
                        try await self.applyRepairAction(action)
                    },
                    verify: { [weak self] _ in
                        guard let self else { throw CancellationError() }
                        let trace = ConnectionDiagnosticTrace()
                        do {
                            try await self.establishConnection(trace: trace)
                            return true
                        } catch {
                            await self.recordDiagnostic(from: trace)
                            return false
                        }
                    },
                    rollback: { [weak self] snapshotID in
                        await self?.rollbackRepair(snapshotID: snapshotID)
                    }
                )
                presentedSurface = nil
            } catch is CancellationError {
                // RepairCoordinator performs rollback before cancellation exits.
            } catch {
                connectionState = .failed(.clientFixable)
            }
        }
    }

    func cancelRepair() {
        repairTask?.cancel()
    }

    func importClipboardText(_ text: String) async throws -> SubscriptionImportResult {
        let resolved = try await payloadLoader.resolveClipboardText(text)
        return try await importResolvedPayload(resolved)
    }

    func importQRCodeText(_ text: String) async throws -> SubscriptionImportResult {
        let resolved = try await payloadLoader.resolveClipboardText(text)
        let source: SubscriptionImportSource = resolved.source == .clipboard ? .qrCode : resolved.source
        return try await importResolvedPayload(
            ResolvedSubscriptionPayload(data: resolved.data, source: source)
        )
    }

    func importFile(_ url: URL) async throws -> SubscriptionImportResult {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard values.isRegularFile != false,
              (values.fileSize ?? 0) <= SubscriptionParser.maximumPayloadBytes
        else { throw RoutevaAppDataError.invalidImportFile }
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        return try await importResolvedPayload(ResolvedSubscriptionPayload(
            data: data,
            source: .file(displayName: url.deletingPathExtension().lastPathComponent)
        ))
    }

    func setActiveSubscription(_ id: UUID) async {
        guard let database else { return }
        let rollbackNodeID = verifiedNodeID
        do {
            try await database.setActiveSubscription(id)
            await reloadSubscriptions()
            guard case .connected = connectionState else { return }
            if connectedCore == .singBox, let targetNodeID = desiredVisibleNodeID() {
                scheduleNodeSelection(
                    targetNodeID: targetNodeID,
                    rollbackNodeID: rollbackNodeID,
                    forceCatalogReload: true
                )
            } else {
                applyOverrideChangesAndReconnect()
            }
        } catch {
            await reloadSubscriptions()
        }
    }

    func setAutoUpdateEnabled(_ enabled: Bool) {
        autoUpdateEnabled = enabled
        defaults.set(enabled, forKey: Self.autoUpdateKey)
    }

    @discardableResult
    func updateSubscription(_ id: UUID, showFailure: Bool = true) async -> Bool {
        guard let importService, !updatingSubscriptionIDs.contains(id) else { return false }
        updatingSubscriptionIDs.insert(id)
        defer { updatingSubscriptionIDs.remove(id) }
        do {
            _ = try await importService.refreshSubscription(id: id)
            await reloadSubscriptions()
            if activeSubscription?.id == id, case .connected = connectionState {
                if connectedCore == .singBox, let targetNodeID = desiredVisibleNodeID() {
                    scheduleNodeSelection(
                        targetNodeID: targetNodeID,
                        rollbackNodeID: verifiedNodeID,
                        forceCatalogReload: true
                    )
                } else {
                    applyOverrideChangesAndReconnect()
                }
            }
            return true
        } catch {
            if showFailure { subscriptionUpdateFailureToast = true }
            await reloadSubscriptions()
            return false
        }
    }

    func renameSubscription(_ id: UUID, displayName: String) async {
        guard let database else { return }
        try? await database.renameSubscription(id: id, displayName: displayName)
        await reloadSubscriptions()
    }

    func deleteSubscription(_ id: UUID) async {
        guard let database,
              !deletingSubscriptionIDs.contains(id),
              let subscription = try? await database.subscription(id: id),
              let nodes = try? await database.nodes(subscriptionID: id)
        else { return }

        // A half-started tunnel must never outlive the configuration it was
        // built from. Once connected, `disconnect()` updates Home immediately
        // and sends provider teardown in the background. During startup, leave
        // the delete control unavailable until that attempt has settled.
        if subscription.isActive {
            if case .connecting = connectionState { return }
            if case .connected = connectionState { disconnect() }
        }

        deletingSubscriptionIDs.insert(id)
        defer { deletingSubscriptionIDs.remove(id) }

        let secretReferences = Set(
            [subscription.sourceSecretReference] + nodes.map(\.credentialReference)
        )

        do {
            try await database.deleteSubscription(id: id)
            await reloadSubscriptions()

            if let secrets {
                for reference in secretReferences {
                    // The database delete is authoritative. A failed cleanup
                    // cannot restore a deleted configuration, but retrying a
                    // future import safely overwrites an orphaned key.
                    try? await secrets.remove(reference: reference)
                }
            }
        } catch {
            await reloadSubscriptions()
        }
    }

    func selectPreferredNode(at index: Int) async {
        guard let database, let activeSubscription,
              activeSubscription.nodes.indices.contains(index) else { return }
        let target = activeSubscription.nodes[index]
        let intentID = UUID()
        nodeSelectionIntentID = intentID
        nodeSelectionTask?.cancel()
        cancelPostConnectProbe()
        let visibleSelectedNodeID = availableNodes.indices.contains(selectedNodeIndex)
            ? availableNodes[selectedNodeIndex].id
            : nil
        let rollbackNodeID = verifiedNodeID
            ?? activeSubscription.preferredNodeID
            ?? visibleSelectedNodeID
        do {
            try await nodeSelectionMutationGate.perform { [weak self] in
                guard let self, nodeSelectionIntentID == intentID else {
                    throw CancellationError()
                }
                try await database.setPreferredNode(
                    subscriptionID: activeSubscription.id,
                    nodeID: target.id
                )
            }
            guard nodeSelectionIntentID == intentID else { return }
            selectedNodeIndex = index
            await reloadSubscriptions()
            guard nodeSelectionIntentID == intentID else { return }
            if case .connected = connectionState {
                if connectedCore == .singBox {
                    scheduleNodeSelection(
                        targetNodeID: target.id,
                        rollbackNodeID: rollbackNodeID,
                        requestID: intentID
                    )
                } else {
                    applyOverrideChangesAndReconnect()
                }
            }
        } catch is CancellationError {
            // A later node tap owns both persistent desired state and runtime
            // selection. The mutation gate guarantees its database write runs
            // after any older write that was already in flight.
        } catch {
            await reloadSubscriptions()
        }
    }

    private func desiredVisibleNodeID() -> UUID? {
        if let preferredNodeID = activeSubscription?.preferredNodeID,
           availableNodes.contains(where: { $0.id == preferredNodeID }) {
            return preferredNodeID
        }
        guard availableNodes.indices.contains(selectedNodeIndex) else { return nil }
        return availableNodes[selectedNodeIndex].id
    }

    private func scheduleNodeSelection(
        targetNodeID: UUID,
        rollbackNodeID: UUID?,
        forceCatalogReload: Bool = false,
        requestID suppliedRequestID: UUID? = nil
    ) {
        guard connectedCore == .singBox, case .connected = connectionState else { return }
        nodeSelectionTask?.cancel()
        cancelPostConnectProbe()
        let requestID = suppliedRequestID ?? UUID()
        let previousRuntimeCatalogNodeIDs = runtimeCatalogNodeIDs
        let previousDirectRouteAddresses = connectedDirectRouteAddresses
        nodeSelectionIntentID = requestID
        nodeSelectionRequestID = requestID
        let controller = providerController
        nodeSelectionTask = Task { [weak self] in
            guard let self else { return }
            var reloadedManifestForRequest: RuntimeManifest?
            defer {
                if nodeSelectionRequestID == requestID {
                    nodeSelectionTask = nil
                    nodeSelectionRequestID = nil
                }
            }
            do {
                let baseline = try? await controller.queryDataPlane(core: .singBox)
                let mutation = try await performProviderNodeMutation(
                    targetNodeID: targetNodeID,
                    rollbackNodeID: rollbackNodeID,
                    requestID: requestID,
                    forceCatalogReload: forceCatalogReload,
                    controller: controller
                )
                try Task.checkCancellation()
                guard nodeSelectionRequestID == requestID,
                      nodeSelectionIntentID == requestID,
                      mutation.selectedNodeID == targetNodeID
                else { throw CancellationError() }
                if let manifest = mutation.reloadedManifest {
                    reloadedManifestForRequest = manifest
                    applyReloadedManifestState(manifest)
                }
                try await verifySelectedNode(
                    controller: controller,
                    baseline: baseline
                )
                try Task.checkCancellation()
                guard nodeSelectionRequestID == requestID else { return }
                _ = try? await finalizeProviderConfigurationReload(
                    expectedNodeID: mutation.selectedNodeID,
                    accept: true,
                    requestID: requestID,
                    controller: controller
                )
                try Task.checkCancellation()
                guard nodeSelectionRequestID == requestID else { return }
                verifiedNodeID = mutation.selectedNodeID
                if let name = availableNodes.first(where: {
                    $0.id == mutation.selectedNodeID
                })?.name {
                    nodeFailoverToast = name
                }
            } catch is CancellationError {
                // A later tap owns the selector now. Never let an older task
                // commit or roll back over that newer request.
            } catch {
                guard nodeSelectionRequestID == requestID else { return }
                await rollbackNodeSelection(
                    to: rollbackNodeID,
                    failedTargetID: targetNodeID,
                    requestID: requestID,
                    configurationWasReloaded: reloadedManifestForRequest != nil,
                    previousRuntimeCatalogNodeIDs: previousRuntimeCatalogNodeIDs,
                    previousDirectRouteAddresses: previousDirectRouteAddresses,
                    controller: controller
                )
            }
        }
    }

    private func performProviderNodeMutation(
        targetNodeID: UUID,
        rollbackNodeID: UUID?,
        requestID: UUID,
        forceCatalogReload: Bool,
        controller: VPNProviderController
    ) async throws -> NodeSelectionMutationResult {
        try await nodeSelectionMutationGate.perform { [weak self] in
            guard let self else { throw CancellationError() }
            try Task.checkCancellation()
            guard nodeSelectionRequestID == requestID,
                  nodeSelectionIntentID == requestID
            else { throw CancellationError() }

            if !forceCatalogReload, runtimeCatalogNodeIDs.contains(targetNodeID) {
                do {
                    return NodeSelectionMutationResult(
                        selectedNodeID: try await controller.selectNode(
                            core: .singBox,
                            nodeID: targetNodeID
                        ),
                        reloadedManifest: nil
                    )
                } catch {
                    guard isRuntimeCatalogMiss(error) else { throw error }
                    // A canceled older reload may have changed the Provider's
                    // catalog without committing App state. Rebuild the latest
                    // desired window instead of trusting that stale cache.
                }
            }

            let manifest = try await makeCurrentManifest(
                selectedNodeID: targetNodeID,
                preferredAdditionalNodeIDs: [rollbackNodeID].compactMap { $0 }
            )
            try Task.checkCancellation()
            guard nodeSelectionRequestID == requestID,
                  nodeSelectionIntentID == requestID
            else { throw CancellationError() }
            return NodeSelectionMutationResult(
                selectedNodeID: try await controller.reloadConfiguration(
                    core: .singBox,
                    manifestID: manifest.manifestID
                ),
                reloadedManifest: manifest
            )
        }
    }

    private func isRuntimeCatalogMiss(_ error: Error) -> Bool {
        guard let codecError = error as? ProviderMessageCodecError,
              case let .providerRejected(code) = codecError
        else { return false }
        return code == "provider.node_not_in_runtime_catalog"
    }

    private func applyReloadedManifestState(_ manifest: RuntimeManifest) {
        runtimeCatalogNodeIDs = Set(manifest.profiles.map(\.id))
        connectedDirectRouteAddresses = manifest.directRouteAddresses
    }

    private func finalizeProviderConfigurationReload(
        expectedNodeID: UUID,
        accept: Bool,
        requestID: UUID,
        controller: VPNProviderController
    ) async throws -> UUID {
        try await nodeSelectionMutationGate.perform { [weak self] in
            guard let self,
                  nodeSelectionRequestID == requestID,
                  nodeSelectionIntentID == requestID
            else { throw CancellationError() }
            return try await controller.finalizeConfigurationReload(
                core: .singBox,
                expectedNodeID: expectedNodeID,
                accept: accept
            )
        }
    }

    private func verifySelectedNode(
        controller: VPNProviderController,
        baseline: ProviderDataPlaneSnapshot?
    ) async throws {
        try await Task.sleep(for: .milliseconds(250))
        let tunnelProbeAddressSets = filteredTunnelProbeAddressSets(
            excluding: connectedDirectRouteAddresses
        )
        if #available(iOS 18.0, *), tunnelProbeAddressSets.isEmpty {
            // DNS preflight availability must not turn an accepted Libbox
            // selector command into a false node failure.
            return
        }
        do {
            _ = try await controller.probeCore(
                core: .singBox,
                tunnelProbeAddressSets: tunnelProbeAddressSets
            )
        } catch {
            let first = try? await controller.queryDataPlane(core: .singBox)
            try await Task.sleep(for: .milliseconds(1_200))
            try Task.checkCancellation()
            let second = try? await controller.queryDataPlane(core: .singBox)
            let preferred = ProviderDataPlaneSnapshot.preferredProbeSnapshot(
                first: first,
                second: second
            )
            let progressed = !preferred.countersReset
                && baseline.map { baseline in
                    preferred.snapshot?.provesBidirectionalIPv4TunnelProgress(
                        since: baseline
                    ) == true
                } == true
            guard progressed else { throw error }
        }
    }

    private func filteredTunnelProbeAddressSets(
        excluding directRouteAddresses: [String]
    ) -> [ProviderTunnelProbeAddressSet] {
        connectedTunnelProbeAddressSets.compactMap { addressSet in
            let addresses = addressSet.ipv4Addresses.filter {
                !directRouteAddresses.contains($0)
            }
            guard !addresses.isEmpty else { return nil }
            return ProviderTunnelProbeAddressSet(
                host: addressSet.host,
                ipv4Addresses: addresses
            )
        }
    }

    private func rollbackNodeSelection(
        to rollbackNodeID: UUID?,
        failedTargetID: UUID,
        requestID: UUID,
        configurationWasReloaded: Bool,
        previousRuntimeCatalogNodeIDs: Set<UUID>,
        previousDirectRouteAddresses: [String],
        controller: VPNProviderController
    ) async {
        guard let database, let activeSubscription,
              nodeSelectionRequestID == requestID,
              nodeSelectionIntentID == requestID
        else { return }
        var rolledBack = false
        var actualRollbackNodeID: UUID?

        if configurationWasReloaded || rollbackNodeID == nil
            || rollbackNodeID == failedTargetID {
            do {
                let actualNodeID = try await finalizeProviderConfigurationReload(
                    expectedNodeID: failedTargetID,
                    accept: false,
                    requestID: requestID,
                    controller: controller
                )
                guard nodeSelectionRequestID == requestID,
                      nodeSelectionIntentID == requestID else { return }
                runtimeCatalogNodeIDs = previousRuntimeCatalogNodeIDs
                connectedDirectRouteAddresses = previousDirectRouteAddresses
                actualRollbackNodeID = actualNodeID
                rolledBack = rollbackNodeID.map { $0 == actualNodeID } ?? true
            } catch is CancellationError {
                return
            } catch {
                rolledBack = false
            }
        } else if let rollbackNodeID, rollbackNodeID != failedTargetID {
            do {
                let mutation = try await performProviderNodeMutation(
                    targetNodeID: rollbackNodeID,
                    rollbackNodeID: nil,
                    requestID: requestID,
                    forceCatalogReload: false,
                    controller: controller
                )
                guard nodeSelectionRequestID == requestID,
                      nodeSelectionIntentID == requestID else { return }
                if let manifest = mutation.reloadedManifest {
                    applyReloadedManifestState(manifest)
                    _ = try? await finalizeProviderConfigurationReload(
                        expectedNodeID: mutation.selectedNodeID,
                        accept: true,
                        requestID: requestID,
                        controller: controller
                    )
                }
                actualRollbackNodeID = mutation.selectedNodeID
                rolledBack = mutation.selectedNodeID == rollbackNodeID
            } catch is CancellationError {
                return
            } catch {
                rolledBack = false
            }
        }

        if let rollbackNodeID {
            do {
                try await nodeSelectionMutationGate.perform { [weak self] in
                    guard let self,
                          nodeSelectionRequestID == requestID,
                          nodeSelectionIntentID == requestID
                    else { throw CancellationError() }
                    try await database.setPreferredNode(
                        subscriptionID: activeSubscription.id,
                        nodeID: rollbackNodeID
                    )
                }
            } catch is CancellationError {
                return
            } catch {
                // Runtime rollback remains authoritative for this live session;
                // foreground reconciliation will retry persistent convergence.
            }
        }
        guard nodeSelectionRequestID == requestID,
              nodeSelectionIntentID == requestID else { return }
        await reloadSubscriptions()
        guard nodeSelectionRequestID == requestID,
              nodeSelectionIntentID == requestID else { return }
        connectionFailureMessage = String(
            localized: "Couldn’t switch node. Kept previous connection."
        )
        if rolledBack {
            verifiedNodeID = actualRollbackNodeID
        } else {
            // The selector no longer has a confirmed route. Only this
            // exceptional rollback failure falls back to a full rebuild.
            applyOverrideChangesAndReconnect()
        }
    }

    private func reconcileSelectedNodeIfNeeded() async {
        let visibleSelectedNodeID = availableNodes.indices.contains(selectedNodeIndex)
            ? availableNodes[selectedNodeIndex].id
            : nil
        guard nodeSelectionTask == nil,
              connectedCore == .singBox,
              case .connected = connectionState,
              let desiredNodeID = activeSubscription?.preferredNodeID
                ?? visibleSelectedNodeID
        else { return }
        do {
            let actualNodeID = try await providerController.selectedNode(core: .singBox)
            if actualNodeID == desiredNodeID {
                verifiedNodeID = actualNodeID
            } else {
                scheduleNodeSelection(
                    targetNodeID: desiredNodeID,
                    rollbackNodeID: actualNodeID
                )
            }
        } catch {
            // Traffic polling remains authoritative for provider lifetime.
            // A transient foreground IPC miss must not disturb Connected.
        }
    }

    private func cancelNodeSelection() {
        nodeSelectionTask?.cancel()
        nodeSelectionTask = nil
        nodeSelectionRequestID = nil
        nodeSelectionIntentID = nil
    }

    private func clearConnectedNodeState() {
        verifiedNodeID = nil
        runtimeCatalogNodeIDs.removeAll(keepingCapacity: false)
        connectedTunnelProbeAddressSets = []
        connectedDirectRouteAddresses = []
    }

    func testNodeLatencies() async {
        guard !isTestingNodes, let database, let activeSubscription else { return }
        guard let records = try? await database.nodes(subscriptionID: activeSubscription.id) else { return }
        isTestingNodes = true
        defer { isTestingNodes = false }
        nodeLatencies = Dictionary(uniqueKeysWithValues: records.map { ($0.id, .testing) })

        for start in stride(from: 0, to: records.count, by: 6) {
            let batch = Array(records[start..<min(start + 6, records.count)])
            await withTaskGroup(of: (UUID, Int?).self) { group in
                for record in batch {
                    group.addTask {
                        guard record.protocolKind != .hysteria2 else { return (record.id, nil) }
                        return (
                            record.id,
                            await NodeLatencyProbe.measure(
                                host: record.endpointHost,
                                port: record.endpointPort,
                                timeout: 2
                            )
                        )
                    }
                }
                for await (id, milliseconds) in group {
                    nodeLatencies[id] = milliseconds.map(NodeLatencyStatus.measured) ?? .unavailable
                }
            }
        }
    }

    func reloadSubscriptions() async {
        guard let database else { return }
        guard let records = try? await database.subscriptions() else { return }
        var summaries: [SubscriptionSummary] = []
        for record in records {
            guard let nodes = try? await database.nodes(subscriptionID: record.id) else { continue }
            summaries.append(SubscriptionSummary(
                id: record.id,
                displayName: Self.localizedSubscriptionDisplayName(record.displayName),
                isActive: record.isActive,
                nodes: nodes.map(Self.nodeSummary),
                usedGigabytes: record.usedBytes.map(Self.gigabytes),
                totalGigabytes: record.totalBytes.map(Self.gigabytes),
                expiresAt: record.expiresAt,
                lastUpdatedDescription: Self.relativeUpdateDescription(record.updatedAt),
                preferredNodeID: record.preferredNodeID,
                canUpdateAutomatically: record.sourceKind == "remote-url"
            ))
        }
        subscriptions = summaries
        if let preferredNodeID = activeSubscription?.preferredNodeID,
           let preferredIndex = availableNodes.firstIndex(where: { $0.id == preferredNodeID }) {
            selectedNodeIndex = preferredIndex
        } else if selectedNodeIndex >= availableNodes.count {
            selectedNodeIndex = 0
        }
    }

    func reloadOverrides() async {
        guard let database,
              let records = try? await database.overridesIncludingTombstones() else { return }
        overrides = records.filter { !$0.isDeleted }.map {
            DomainOverrideSummary(
                id: UUID(),
                domain: $0.domain,
                action: .init(storageValue: $0.action),
                isEnabled: $0.isEnabled
            )
        }
    }

    private func importResolvedPayload(_ resolved: ResolvedSubscriptionPayload) async throws -> SubscriptionImportResult {
        guard let importService else { throw RoutevaAppDataError.persistenceUnavailable }
        let result = try await importService.importPayload(
            resolved.data,
            source: resolved.source,
            usage: resolved.usage,
            makeActive: subscriptions.isEmpty
        )
        await reloadSubscriptions()
        importConfirmation = ImportConfirmation(
            displayName: Self.localizedSubscriptionDisplayName(result.displayName),
            nodeCount: result.nodeCount
        )
        return result
    }

    private func refreshActiveSubscriptionOnColdLaunchIfNeeded() async {
        guard autoUpdateEnabled, let database,
              let active = try? await database.subscriptions().first(where: \.isActive),
              active.sourceKind == "remote-url"
        else { return }
        if let lastRefreshAt = active.lastRefreshAt,
           Date().timeIntervalSince(lastRefreshAt) < 24 * 60 * 60 { return }
        _ = await updateSubscription(active.id, showFailure: false)
    }

    private func makeCurrentManifest(
        selectedNodeID: UUID? = nil,
        preferredAdditionalNodeIDs: [UUID] = []
    ) async throws -> RuntimeManifest {
        guard let database else { throw RoutevaAppDataError.persistenceUnavailable }
        guard let activeSubscription,
              let subscriptionRecord = try await database.subscription(id: activeSubscription.id)
        else { throw RoutevaAppDataError.nodeUnavailable }
        let nodes = availableNodes
        guard !nodes.isEmpty else { throw RoutevaAppDataError.nodeUnavailable }
        let index = min(selectedNodeIndex, nodes.count - 1)
        let targetNodeID = selectedNodeID ?? nodes[index].id
        guard let record = try await database.node(id: targetNodeID) else {
            throw RoutevaAppDataError.nodeUnavailable
        }
        let subscriptionNodes = try await database.nodes(subscriptionID: activeSubscription.id)
        let supportedNodes = subscriptionNodes.filter { candidate in
            CoreIdentifier.singBox.declaredCapabilities.supports(
                protocolKind: candidate.protocolKind,
                transport: candidate.transport,
                security: candidate.security,
                requiresUDP: candidate.requiresUDP
            )
        }
        guard supportedNodes.contains(where: { $0.id == record.id }) else {
            throw RoutevaAppDataError.nodeUnavailable
        }
        // Keep the desired node first so it is never dropped by the bounded
        // startup catalog. Nodes outside this safe route window are handled by
        // the running-catalog reload path rather than receiving incomplete
        // endpoint exclusions.
        let supportedNodesByID = Dictionary(
            uniqueKeysWithValues: supportedNodes.map { ($0.id, $0) }
        )
        let catalogNodes = SingBoxRuntimeCatalogPlanner.nodeIDs(
            selectedNodeID: record.id,
            preferredAdditionalNodeIDs: preferredAdditionalNodeIDs.filter {
                supportedNodesByID[$0] != nil
            },
            availableNodeIDs: supportedNodes.map(\.id)
        ).compactMap { supportedNodesByID[$0] }
        let profiles = catalogNodes.map { candidate in
            RuntimeProfile(
                id: candidate.id,
                protocolKind: candidate.protocolKind,
                transport: candidate.transport,
                security: candidate.security,
                requiresUDP: candidate.requiresUDP,
                credential: SecretReference(
                    keychainIdentifier: candidate.credentialReference
                )
            )
        }
        let providerRoutePolicy = try subscriptionRecord.routePolicyJSON.map {
            try JSONDecoder().decode(ProviderRoutePolicy.self, from: $0)
        }
        let runtimeOverrides = overrides.compactMap { item -> RuntimeDomainOverride? in
            guard item.isEnabled else { return nil }
            return RuntimeDomainOverride(
                domain: item.domain,
                action: item.action == .direct ? .direct : .proxyCurrentNode
            )
        }
        // Resolve every runtime-catalog endpoint while the device still uses
        // its physical network. These addresses are installed as host-sized
        // excluded routes by the Packet Tunnel provider, preventing the
        // selected or newly switched transport from re-entering Routeva's own
        // default tunnel route.
        let catalogEndpointHosts = catalogNodes.map(\.endpointHost)
        let resolvedEndpointAddresses = await DomainRouteResolver().resolveAddressSets(
            domains: catalogEndpointHosts
        )
        let selectedEndpointAddresses = DirectRouteAddressValidator.validated(
            [record.endpointHost] + (resolvedEndpointAddresses[record.endpointHost] ?? [])
        )
        guard !selectedEndpointAddresses.isEmpty else {
            // Without a numeric host exclusion the newly selected transport
            // can recursively enter Routeva's own default route. Fail before
            // touching the running service and leave the verified node intact.
            throw RoutevaAppDataError.nodeUnavailable
        }
        let directRouteAddresses = DirectRouteAddressValidator.validated(
            catalogEndpointHosts
                + resolvedEndpointAddresses.values.flatMap { $0 }
        )
        try Task.checkCancellation()
        let manifest = RuntimeManifest(
            // The release runtime is sing-box-only.
            corePolicy: .singBox,
            profile: RuntimeProfile(
                id: record.id,
                protocolKind: record.protocolKind,
                transport: record.transport,
                security: record.security,
                requiresUDP: record.requiresUDP,
                credential: SecretReference(keychainIdentifier: record.credentialReference)
            ),
            profiles: profiles,
            routingMode: routingMode.runtimeValue,
            dnsPreset: dnsPreset.runtimeValue,
            directRouteAddresses: directRouteAddresses,
            providerRoutePolicy: providerRoutePolicy,
            domainOverrides: runtimeOverrides
        )
        try Task.checkCancellation()
        try await database.saveRuntimeManifest(RuntimeManifestRecord(
            id: manifest.manifestID,
            schemaVersion: manifest.schemaVersion,
            manifestData: try JSONEncoder().encode(manifest),
            isCurrent: true
        ))
        return manifest
    }

    private func establishConnection(trace: ConnectionDiagnosticTrace) async throws {
        probeCounterSummary = nil
        let candidates = NodeFailoverPlanner().candidates(
            routingMode: routingMode.runtimeValue,
            isPreferredPinned: activeSubscription?.preferredNodeID != nil,
            currentIndex: min(selectedNodeIndex, max(0, availableNodes.count - 1)),
            available: availableNodes.enumerated().map { index, node in
                let score: Int?
                if case let .measured(milliseconds) = nodeLatencies[node.id] {
                    score = milliseconds
                } else {
                    score = nil
                }
                return NodeFailoverCandidate(index: index, healthScore: score)
            }
        )
        var lastError: (any Error)?
        let originalIndex = selectedNodeIndex

        for candidate in candidates {
            selectedNodeIndex = candidate
            do {
                try await establishSelectedNodeConnection(trace: trace)
                if candidate != originalIndex {
                    nodeFailoverToast = availableNodes[candidate].name
                }
                return
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastError = error
            }
        }
        selectedNodeIndex = originalIndex
        throw lastError ?? RoutevaAppDataError.nodeUnavailable
    }

    private func establishSelectedNodeConnection(
        trace: ConnectionDiagnosticTrace
    ) async throws {
        let manifest: RuntimeManifest
        do {
            manifest = try await makeCurrentManifest()
            await trace.record(.init(layer: .configuration, status: .passed))
        } catch {
            await trace.record(.init(
                layer: .configuration,
                status: .failed,
                errorCode: "configuration.manifest_failed"
            ))
            throw error
        }
        let controller = providerController
        let excludedNodeAddresses = manifest.directRouteAddresses
        let startupTiming = StartupTimingBox()
        let result: ProviderConnectionResult
        do {
            result = try await connectionCoordinator.start(
                manifest: manifest,
                health: [.singBox: CoreHealth(isAvailable: true)],
                startProvider: { core, manifestID in
                #if DEBUG
                let providerStartedAt = Date()
                defer {
                    let duration = Date().timeIntervalSince(providerStartedAt)
                    startupTiming.storeProviderDuration(duration)
                    print(String(
                        format: "Routeva VPN startup timing: provider=%.3fs",
                        duration
                    ))
                }
                #endif
                do {
                    try await controller.start(core: core, manifestID: manifestID)
                    await trace.record(.init(layer: .tunnel, status: .passed))
                } catch {
                    let errorCode = VPNProviderController.stableDiagnosticCode(for: error)
                    await trace.record(.init(
                        layer: .tunnel,
                        status: .failed,
                        errorCode: errorCode
                    ))
                    #if DEBUG
                    print("Routeva VPN startup diagnostic: \(errorCode)")
                    #endif
                    throw error
                }
            },
                stopProvider: { core in await controller.stop(core: core) },
                probe: { _ in
                    // NE reports Connected only after the provider has loaded
                    // the manifest, started Libbox/gVisor, and started the
                    // public PacketFlow bridge. Internet/CDN reachability is a
                    // post-connect health signal and must not hold the power
                    // control in Connecting or trigger serial node retries.
                    await trace.record(.init(layer: .probe, status: .passed))
                }
            )
        } catch let error as ProviderConnectionError {
            // These failures can happen before a provider closure runs. Record
            // an explicit layer so the UI never degrades to diagnostic.unknown.
            switch error {
            case .failureBudgetExhausted:
                await trace.record(.init(
                    layer: .tunnel,
                    status: .failed,
                    errorCode: "provider.failure_budget_exhausted"
                ))
            case .startAlreadyInProgress:
                await trace.record(.init(
                    layer: .tunnel,
                    status: .failed,
                    errorCode: "provider.start_already_in_progress"
                ))
            case .allCandidatesFailed:
                break // Provider/probe closures have already written the cause.
            }
            throw error
        }
        try Task.checkCancellation()
        #if DEBUG
        if let duration = startupTiming.providerDuration {
            defaults.set(duration, forKey: Self.debugProviderStartupDurationKey)
        }
        #endif
        connectedCore = result.core
        verifiedNodeID = manifest.profile.id
        runtimeCatalogNodeIDs = Set(manifest.profiles.map(\.id))
        connectedTunnelProbeAddressSets = []
        connectedDirectRouteAddresses = excludedNodeAddresses
        trafficRateSampler.reset()
        currentDiagnosticResult = nil
        connectionState = .connected(sessionStartedAt: .now)
        refreshTrafficPolling()
        startPostConnectProbe(
            core: result.core,
            excludedNodeAddresses: excludedNodeAddresses
        )
    }

    private func startPostConnectProbe(
        core: CoreIdentifier,
        excludedNodeAddresses: [String]
    ) {
        cancelPostConnectProbe()
        let taskID = UUID()
        postConnectProbeTaskID = taskID
        let controller = providerController
        let probe = connectivityProbe
        postConnectProbeTask = Task { [weak self] in
            guard let self else { return }
            defer {
                if postConnectProbeTaskID == taskID {
                    postConnectProbeTask = nil
                    postConnectProbeTaskID = nil
                }
            }
            do {
                // Keep the health request away from the traffic sampler's
                // immediate warm-up pair and from the provider's 200ms IPC
                // pacing window.
                try await Task.sleep(for: .milliseconds(500))
                guard connectedCore == core else { return }
                let tunnelProbeAddressSets: [ProviderTunnelProbeAddressSet]
                if core == .singBox {
                    let resolvedAddressSets = await DomainRouteResolver()
                        .resolveIPv4AddressSets(
                            domains: ProviderTunnelProbeCatalog.ipv4ResolutionHosts
                        )
                    guard !Task.isCancelled,
                          postConnectProbeTaskID == taskID,
                          connectedCore == core else { return }
                    connectedTunnelProbeAddressSets = resolvedAddressSets
                    tunnelProbeAddressSets = filteredTunnelProbeAddressSets(
                        excluding: excludedNodeAddresses
                    )
                    if #available(iOS 18.0, *), tunnelProbeAddressSets.isEmpty {
                        // Probe DNS is post-connect telemetry. Its absence must
                        // neither delay startup nor create a false health warning.
                        return
                    }
                } else {
                    tunnelProbeAddressSets = []
                }
                let baseline = core == .singBox
                    ? try? await controller.queryDataPlane(core: core)
                    : nil
                let probeStartedAt = Date()
                do {
                    if core == .singBox {
                        _ = try await controller.probeCore(
                            core: core,
                            tunnelProbeAddressSets: tunnelProbeAddressSets
                        )
                    } else {
                        try await probe.run(excludedRouteAddresses: excludedNodeAddresses)
                    }
                    guard !Task.isCancelled,
                          postConnectProbeTaskID == taskID,
                          connectedCore == core else { return }
                    #if DEBUG
                    print(String(
                        format: "Routeva VPN post-connect health probe: passed in %.3fs",
                        Date().timeIntervalSince(probeStartedAt)
                    ))
                    #endif
                } catch is CancellationError {
                    return
                } catch {
                    var dataPlane: ProviderDataPlaneSnapshot?
                    var countersReset = false
                    if core == .singBox {
                        let first = try? await controller.queryDataPlane(core: core)
                        try? await Task.sleep(for: .milliseconds(1_200))
                        guard !Task.isCancelled, connectedCore == core else { return }
                        let second = try? await controller.queryDataPlane(core: core)
                        let preferred = ProviderDataPlaneSnapshot.preferredProbeSnapshot(
                            first: first,
                            second: second
                        )
                        dataPlane = preferred.snapshot
                        countersReset = preferred.countersReset
                    }
                    let fallback = VPNProviderController.stableCoreProbeDiagnosticCode(for: error)
                    let diagnosticSummary = (dataPlane?.probeCounterSummary ?? "snapshot=none")
                        + " " + SystemProxyDiagnostics.summary
                    let trafficProvesTunnel = !countersReset
                        && baseline.map { baseline in
                            dataPlane?.provesBidirectionalIPv4TunnelProgress(since: baseline)
                                == true
                        } == true
                    let errorCode = trafficProvesTunnel
                        ? "probe.post_connect_endpoint_unavailable"
                        : (countersReset
                            ? "probe.bridge_counters_reset"
                            : dataPlaneProbeDiagnosticCode(dataPlane, fallback: fallback))
                    probeCounterSummary = diagnosticSummary
                    #if DEBUG
                    print(
                        "Routeva VPN post-connect health warning: \(errorCode) "
                            + "[\(diagnosticSummary)]"
                    )
                    #endif
                    // This is telemetry only. NE/provider teardown is still
                    // authoritative and is handled by traffic polling. A
                    // public health endpoint must not turn a running VPN into
                    // a false startup failure or serially rotate nodes.
                }
            } catch is CancellationError {
                return
            } catch {
                return
            }
        }
    }

    private func cancelPostConnectProbe() {
        postConnectProbeTask?.cancel()
        postConnectProbeTask = nil
        postConnectProbeTaskID = nil
    }

    private func presentDiagnostic(from trace: ConnectionDiagnosticTrace) async {
        let result = await recordDiagnostic(from: trace)
        connectionState = .idle
        clearConnectedNodeState()
        #if DEBUG
        let evidenceCode = result.evidence.last(where: {
            $0.checkStatus == .failed
        })?.errorCode ?? result.stableErrorCode
        var message = "Couldn’t connect. Try again. [\(evidenceCode)]"
        if let probeCounterSummary {
            message += " {\(probeCounterSummary)}"
        }
        connectionFailureMessage = message
        #else
        connectionFailureMessage = "Couldn’t connect. Try again."
        #endif
    }

    @discardableResult
    private func recordDiagnostic(from trace: ConnectionDiagnosticTrace) async -> DiagnosticResult {
        let result = diagnosticEngine.evaluate(await trace.checks)
        currentDiagnosticResult = result
        let record = ActivityRecord(
            id: UUID(),
            eventCode: result.stableErrorCode,
            failureBucket: result.bucket.rawValue,
            redactedSummary: result.evidence.map {
                "\($0.layer.rawValue):\($0.checkStatus.rawValue):\($0.errorCode ?? "none")"
            }.joined(separator: ",")
        )
        latestActivityRecord = record
        try? await database?.appendActivity(record)
        return result
    }

    private func reloadLatestActivity() async {
        latestActivityRecord = try? await database?.latestActivity()
    }

    private func makeRepairSnapshot() async throws -> UUID {
        guard let database, let current = try await database.currentRuntimeManifest() else {
            throw RoutevaAppDataError.runtimeManifestUnavailable
        }
        let snapshot = ConfigSnapshotRecord(
            id: UUID(),
            manifestID: current.id,
            manifestData: current.manifestData,
            reasonCode: "repair.before"
        )
        try await database.saveSnapshot(snapshot)
        return snapshot.id
    }

    private func applyRepairAction(_ action: RepairAction) async throws {
        switch action {
        case .switchHealthyNode:
            guard availableNodes.count > 1 else { throw RoutevaAppDataError.nodeUnavailable }
            selectedNodeIndex = (selectedNodeIndex + 1) % availableNodes.count
        case .switchDNSPreset:
            dnsPreset = .compatibility
        case .rebuildTunnel:
            try? await providerController.disconnectAll()
        default:
            throw RoutevaAppDataError.unsupportedRepairAction
        }
    }

    private func rollbackRepair(snapshotID: UUID) async {
        guard let database,
              let restored = try? await database.restoreSnapshot(id: snapshotID),
              let manifest = try? JSONDecoder().decode(RuntimeManifest.self, from: restored.manifestData)
        else { return }
        routingMode = RoutingMode(manifest.routingMode)
        dnsPreset = DNSPreset(manifest.dnsPreset)
    }

    private func refreshTrafficPolling() {
        guard isHomeVisible, isSceneActive, connectedCore != nil,
              case .connected = connectionState else {
            stopTrafficPolling()
            return
        }
        guard trafficTask == nil else { return }
        let taskID = UUID()
        trafficTaskID = taskID
        trafficTask = Task { [weak self] in
            guard let self else { return }
            defer {
                if trafficTaskID == taskID {
                    trafficTask = nil
                    trafficTaskID = nil
                }
            }
            #if DEBUG
            var pollingIteration = 0
            var lastDataPlaneSummary: String?
            #endif
            while !Task.isCancelled {
                guard let core = connectedCore else { break }
                var needsWarmupSample = false
                do {
                    let snapshot = try await providerController.queryTraffic(core: core)
                    guard !Task.isCancelled, trafficTaskID == taskID else { break }
                    let now = Date()
                    if let rate = trafficRateSampler.sample(snapshot, at: now) {
                        liveUploadMbps = rate.uploadMbps
                        liveDownloadMbps = rate.downloadMbps
                    } else {
                        liveUploadMbps = 0
                        liveDownloadMbps = 0
                        needsWarmupSample = true
                    }
                } catch {
                    guard !Task.isCancelled, trafficTaskID == taskID else { break }
                    liveUploadMbps = 0
                    liveDownloadMbps = 0
                    if !(await providerController.isConnectionActive(core: core)) {
                        connectedCore = nil
                        clearConnectedNodeState()
                        trafficRateSampler.reset()
                        connectionState = .idle
                        #if DEBUG
                        connectionFailureMessage =
                            "VPN stopped unexpectedly. Try again. [provider.session_ended]"
                        #else
                        connectionFailureMessage = "VPN stopped unexpectedly. Try again."
                        #endif
                        break
                    }
                    needsWarmupSample = true
                }
                #if DEBUG
                // Provider IPC is globally limited to one request per 200 ms.
                // Sample the existing privacy-safe data-plane snapshot only
                // every third traffic tick and keep a deliberate gap from the
                // traffic request. This makes post-Connected Safari failures
                // visible in the host Xcode console without logging payloads,
                // hosts, node details, or raw core errors.
                pollingIteration += 1
                if pollingIteration.isMultiple(of: 3) {
                    try? await Task.sleep(for: .milliseconds(250))
                    guard !Task.isCancelled else { break }
                    if let snapshot = try? await providerController.queryDataPlane(core: core) {
                        let summary = snapshot.probeCounterSummary
                        if summary != lastDataPlaneSummary {
                            print("Routeva VPN live data-plane: [\(summary)]")
                            lastDataPlaneSummary = summary
                        }
                    }
                }
                #endif
                try? await Task.sleep(
                    for: needsWarmupSample ? .milliseconds(250) : .milliseconds(500)
                )
            }
        }
    }

    private func stopTrafficPolling() {
        trafficTask?.cancel()
        trafficTask = nil
        trafficTaskID = nil
        liveDownloadMbps = 0
        liveUploadMbps = 0
    }

    private static func nodeSummary(_ record: NodeRecord) -> NodeSummary {
        let support = ProtocolSupportClassifier().classify(
            protocolKind: record.protocolKind,
            transport: record.transport,
            security: record.security,
            requiresUDP: record.requiresUDP
        )
        let country = NodeCountryResolver.resolve(
            displayName: record.displayName,
            storedCountryCode: record.countryCode
        )
        let countryName = record.countryName
            ?? country.flatMap { NodeCountryResolver.localizedName(for: $0.countryCode) }
            ?? String(localized: "Unknown location")
        return NodeSummary(
            id: record.id,
            flag: country?.flag ?? "🌐",
            country: countryName,
            name: NodeCountryResolver.removingLeadingFlag(from: record.displayName),
            protocolName: record.protocolKind.displayName,
            supportLevel: support.level
        )
    }

    private static func gigabytes(_ bytes: Int64) -> Double {
        Double(bytes) / 1_000_000_000
    }

    private static func relativeUpdateDescription(_ date: Date) -> String {
        let seconds = max(0, Int(Date().timeIntervalSince(date)))
        if seconds < 60 { return "just now" }
        if seconds < 3_600 { return "\(seconds / 60)m ago" }
        if seconds < 86_400 { return "\(seconds / 3_600)h ago" }
        return "\(seconds / 86_400)d ago"
    }

    private static func localizedSubscriptionDisplayName(_ value: String) -> String {
        value == "Imported subscription" ? String(localized: "Imported subscription") : value
    }

    private func markOverrideChangePendingIfConnected() {
        if case .connected = connectionState { overrideReconnectPrompt = true }
    }

    private static func normalizedDomain(_ rawValue: String) -> String? {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
        guard value.count <= 253, value.contains("."), !value.contains("/"),
              !value.contains(":"), !value.contains(" "),
              value.split(separator: ".").allSatisfy({ label in
                  !label.isEmpty && label.count <= 63
                      && label.first != "-" && label.last != "-"
                      && label.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }
              }) else { return nil }
        return value
    }

    private static func loadOrCreateDeviceID(defaults: UserDefaults) -> String {
        let key = "routeva.override.device-id"
        if let existing = defaults.string(forKey: key), !existing.isEmpty { return existing }
        let value = UUID().uuidString.lowercased()
        defaults.set(value, forKey: key)
        return value
    }
}

private func dataPlaneProbeDiagnosticCode(
    _ snapshot: ProviderDataPlaneSnapshot?,
    fallback: String
) -> String {
    snapshot?.probeFailureDiagnosticCode(fallback: fallback) ?? fallback
}

private final class StartupTimingBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storedProviderDuration: TimeInterval?

    var providerDuration: TimeInterval? { lock.withLock { storedProviderDuration } }

    func storeProviderDuration(_ value: TimeInterval) {
        lock.withLock { storedProviderDuration = value }
    }
}

enum RoutevaAppDataError: Error, Equatable {
    case persistenceUnavailable
    case invalidImportFile
    case nodeUnavailable
    case runtimeManifestUnavailable
    case unsupportedRepairAction
}

struct ImportConfirmation: Equatable {
    let displayName: String
    let nodeCount: Int
}

enum RoutingMode: String, CaseIterable, Identifiable {
    case automatic = "Smart"
    case global = "Global"
    case direct = "Direct"

    var id: String { rawValue }

    var runtimeValue: RuntimeManifest.RoutingMode {
        switch self {
        case .automatic: .automatic
        case .global: .global
        case .direct: .direct
        }
    }

    init(_ value: RuntimeManifest.RoutingMode) {
        switch value {
        case .automatic: self = .automatic
        case .global: self = .global
        case .direct: self = .direct
        }
    }

    var detail: String {
        switch self {
        case .automatic: "Provider rules + selected node"
        case .global: "All traffic via proxy"
        case .direct: "Direct by default; Overrides still apply"
        }
    }
}

enum DNSPreset: String, CaseIterable, Identifiable {
    case automatic = "Automatic"
    case privacy = "Privacy"
    case compatibility = "Compatibility"

    var id: String { rawValue }

    var runtimeValue: RuntimeManifest.DNSPreset {
        switch self {
        case .automatic: .automatic
        case .privacy: .privacy
        case .compatibility: .compatibility
        }
    }

    init(_ value: RuntimeManifest.DNSPreset) {
        switch value {
        case .automatic: self = .automatic
        case .privacy: self = .privacy
        case .compatibility: self = .compatibility
        }
    }

    var detail: String {
        switch self {
        case .automatic: "System / tunnel default"
        case .privacy: "Encrypted DNS when possible"
        case .compatibility: "Prefer widely reachable resolvers"
        }
    }
}

struct NodeSummary: Identifiable, Equatable {
    let id: UUID
    let flag: String
    let country: String
    let name: String
    let protocolName: String
    let supportLevel: ProtocolSupportLevel
}

enum NodeLatencyStatus: Equatable {
    case testing
    case measured(Int)
    case unavailable

    var label: String {
        switch self {
        case .testing: "…"
        case let .measured(value): "\(value) ms"
        case .unavailable: "Timeout"
        }
    }
}

private enum NodeLatencyProbe {
    static func measure(host: String, port: Int, timeout: TimeInterval) async -> Int? {
        guard (1...65_535).contains(port),
              let endpointPort = NWEndpoint.Port(rawValue: UInt16(port)) else { return nil }
        return await withCheckedContinuation { continuation in
            let connection = NWConnection(
                host: NWEndpoint.Host(host),
                port: endpointPort,
                using: .tcp
            )
            let completion = NodeLatencyCompletion(
                continuation: continuation,
                connection: connection,
                startedAt: Date()
            )
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    completion.finish(Int(Date().timeIntervalSince(completion.startedAt) * 1_000))
                case .failed, .cancelled:
                    completion.finish(nil)
                default:
                    break
                }
            }
            connection.start(queue: DispatchQueue(label: "com.yilinglabs.routeva.node-latency"))
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) {
                completion.finish(nil)
            }
        }
    }
}

private final class NodeLatencyCompletion: @unchecked Sendable {
    let startedAt: Date
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Int?, Never>?
    private let connection: NWConnection

    init(
        continuation: CheckedContinuation<Int?, Never>,
        connection: NWConnection,
        startedAt: Date
    ) {
        self.continuation = continuation
        self.connection = connection
        self.startedAt = startedAt
    }

    func finish(_ result: Int?) {
        lock.lock()
        guard let continuation else {
            lock.unlock()
            return
        }
        self.continuation = nil
        lock.unlock()
        connection.cancel()
        continuation.resume(returning: result)
    }
}

struct SubscriptionSummary: Identifiable, Equatable {
    let id: UUID
    var displayName: String
    var isActive: Bool
    var nodes: [NodeSummary]
    var usedGigabytes: Double?
    var totalGigabytes: Double?
    var expiresAt: Date?
    var lastUpdatedDescription: String
    var preferredNodeID: UUID?
    var canUpdateAutomatically: Bool
}

struct DomainOverrideSummary: Identifiable, Equatable {
    enum Action: String, CaseIterable, Identifiable {
        case proxy = "Proxy"
        case direct = "Direct"
        var id: String { rawValue }

        var storageValue: String { rawValue.lowercased() }

        init(storageValue: String) {
            self = storageValue == "direct" ? .direct : .proxy
        }
    }

    let id: UUID
    var domain: String
    var action: Action
    var isEnabled: Bool
}

enum DiagnosticCase: String, CaseIterable, Identifiable {
    case clientFixable
    case provider
    case environment
    case unknown
    var id: String { rawValue }

    init(_ bucket: FailureBucket) {
        switch bucket {
        case .clientFixable: self = .clientFixable
        case .providerSide: self = .provider
        case .environment: self = .environment
        case .unknown: self = .unknown
        }
    }
}

private actor ConnectionDiagnosticTrace {
    private(set) var checks: [DiagnosticCheck] = []
    func record(_ check: DiagnosticCheck) { checks.append(check) }
}

/// Serializes only Provider mutations, not UI intent or verification. A later
/// tap can cancel an older request immediately, then waits for any already-sent
/// provider message to return before installing its own final selector state.
/// This prevents an older slow catalog reload from landing after a newer tap.
private actor NodeSelectionMutationGate {
    private var isLocked = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func perform<Value: Sendable>(
        _ operation: @escaping @MainActor @Sendable () async throws -> Value
    ) async throws -> Value {
        await acquire()
        defer { release() }
        try Task.checkCancellation()
        return try await operation()
    }

    private func acquire() async {
        guard isLocked else {
            isLocked = true
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    private func release() {
        guard !waiters.isEmpty else {
            isLocked = false
            return
        }
        waiters.removeFirst().resume()
    }
}

private struct NodeSelectionMutationResult: Sendable {
    let selectedNodeID: UUID
    let reloadedManifest: RuntimeManifest?
}

#if DEBUG
private actor UITestMemorySecretStore: SecretStoring {
    private var values: [String: Data] = [:]
    func set(_ data: Data, for reference: String) { values[reference] = data }
    func data(for reference: String) throws -> Data {
        guard let value = values[reference] else { throw KeychainStoreError.notFound }
        return value
    }
    func remove(reference: String) { values.removeValue(forKey: reference) }
}
#endif

private extension ProxyProtocol {
    var displayName: String {
        switch self {
        case .shadowsocks: "Shadowsocks"
        case .vmess: "VMess"
        case .vless: "VLESS"
        case .trojan: "Trojan"
        case .hysteria2: "Hysteria 2"
        }
    }
}
