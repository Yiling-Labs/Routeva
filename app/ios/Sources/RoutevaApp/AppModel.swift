import CoreBridge
import DataKit
import Foundation
import Network
@preconcurrency import NetworkExtension
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
    /// Tunnel session cumulative traffic (this connection only).
    @Published var sessionDownloadedBytes: UInt64 = 0
    @Published var sessionUploadedBytes: UInt64 = 0
    @Published var importConfirmation: ImportConfirmation?
    @Published var currentDiagnosticResult: DiagnosticResult?
    @Published private(set) var latestActivityRecord: ActivityRecord?
    @Published var repairState: RepairPresentationState = .idle
    @Published var overrideReconnectPrompt = false
    @Published var connectionFailureMessage: String?
    @Published var nodeFailoverToast: String?
    @Published var latencyTestUnavailableToast = false
    @Published var nodeLatencies: [UUID: NodeLatencyStatus] = [:]
    @Published var isTestingNodes = false
    /// Location list order after a completed latency round (node IDs). Empty = subscription order.
    @Published private(set) var locationOrderIDs: [UUID] = []
    @Published var updatingSubscriptionIDs: Set<UUID> = []
    @Published var deletingSubscriptionIDs: Set<UUID> = []
    @Published var subscriptionUpdateFailureToast = false
    @Published var autoUpdateEnabled = true

    private static let onboardingKey = "routeva.onboarding.data-privacy.completed"
    private static let autoUpdateKey = "routeva.subscription.auto-update.enabled"
    private static let latencyRoundCompletedAtKey = "routeva.latency.round-completed-at"
    /// Weak cache TTL for silent full-table latency (implementation constant S).
    private static let latencyCacheTTL: TimeInterval = 6 * 60 * 60
    private static let orphanedProviderConnectingTimeout: Duration = .seconds(20)
    /// 整轮 Connecting 的上限：含预检、startTunnel、probe。超时回 Idle + toast。
    private static let connectionAttemptTimeout: Duration = .seconds(45)
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
    /// Latest *Set active* target. A newer tap only updates this; the in-flight
    /// switch applies the last id after teardown.
    private var pendingActiveSubscriptionID: UUID?
    private var isSwitchingActiveSubscription = false
    private var nodeSelectionTask: Task<Void, Never>?
    private var nodeSelectionRequestID: UUID?
    private var nodeSelectionIntentID: UUID?
    private var repairTask: Task<Void, Never>?
    private var trafficTask: Task<Void, Never>?
    private var trafficTaskID: UUID?
    private var postConnectProbeTask: Task<Void, Never>?
    private var postConnectProbeTaskID: UUID?
    private var connectedCore: CoreIdentifier?
    private var verifiedNodeID: UUID?
    private var runtimeCatalogNodeIDs: Set<UUID> = []
    private var connectedTunnelProbeAddressSets: [ProviderTunnelProbeAddressSet] = []
    private var connectedDirectRouteAddresses: [String] = []
    /// Privacy-safe probe counter vector (counts only) from the latest failed
    /// connection attempt. Surfaced only in the DEBUG failure notice.
    private var probeCounterSummary: String?
    private var dnsHealthMonitor = ProviderDNSHealthMonitor()
    private var isHomeVisible = false
    private var isSceneActive = true
    private let deviceID: String
    private var overrideSyncService: CloudOverrideSyncService?
    private var silentLatencyTask: Task<Void, Never>?
    private var latencyRoundGeneration = 0
    private var latencyRoundBaseline: [UUID: NodeLatencyStatus] = [:]
    private var latencyRoundIsUserInitiated = false
    private var providerStatusObservationTask: Task<Void, Never>?
    private var providerConnectingRecoveryTask: Task<Void, Never>?
    private var providerConnectingRecoveryID: UUID?
    private var providerStatusRefreshGate = ProviderStatusRefreshGate()
    private var providerStatusNotificationRevision = 0
    private var lastObservedProviderStatus: NEVPNStatus?
    private var hasResolvedProviderStatus = false
    /// Once the user picks a Cover Flow card or Location Preferred, silent
    /// latency pre-stop / reload must not steal that focus.
    private var nodeSelectionOwnedByUser = false
    /// App 已结束本轮 Connecting（取消 / 失败 / 超时）后，禁止 leftover
    /// `.connecting` 快照把 Home 重新锁死。
    private var suppressProviderConnectingPresentation = false

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
        observeProviderStatusChanges()
        Task { [weak self] in
            guard let self else { return }
            // Resolve the system tunnel before loading the node catalog. A
            // surviving tunnel must suppress idle-only latency work from the
            // first cold-launch database refresh onward.
            await reconcileProviderConnectionStatus()
            await reloadSubscriptions()
            await refreshActiveSubscriptionOnColdLaunchIfNeeded()
            await reconcileSelectedNodeIfNeeded()
            await reloadOverrides()
            await reloadLatestActivity()
            await syncOverrides()
            scheduleSilentLatencyTestIfNeeded()
        }
    }

    deinit {
        providerStatusObservationTask?.cancel()
        providerConnectingRecoveryTask?.cancel()
    }

    var activeSubscription: SubscriptionSummary? {
        subscriptions.first(where: \.isActive)
    }

    var availableNodes: [NodeSummary] {
        activeSubscription?.nodes ?? []
    }

    /// Location list: latency-ascending after a completed round; else subscription order.
    var locationDisplayNodes: [NodeSummary] {
        let nodes = availableNodes
        guard !locationOrderIDs.isEmpty else { return nodes }
        let byID = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        var ordered: [NodeSummary] = []
        ordered.reserveCapacity(nodes.count)
        for id in locationOrderIDs {
            if let node = byID[id] { ordered.append(node) }
        }
        for node in nodes where !locationOrderIDs.contains(node.id) {
            ordered.append(node)
        }
        return ordered
    }

    /// Home Cover Flow: full Active node list in subscription order.
    /// Provider metadata / quota banner rows are already dropped at import.
    var coverFlowNodes: [NodeSummary] {
        availableNodes
    }

    var coverFlowSelectedIndex: Int {
        guard !availableNodes.isEmpty else { return 0 }
        return min(max(selectedNodeIndex, 0), availableNodes.count - 1)
    }

    func setCoverFlowSelectedIndex(_ index: Int) {
        guard availableNodes.indices.contains(index) else { return }
        if selectedNodeIndex != index {
            selectedNodeIndex = index
            nodeSelectionOwnedByUser = true
        }
    }

    func selectPreferredNode(id: UUID) async {
        guard let index = activeSubscription?.nodes.firstIndex(where: { $0.id == id }) else { return }
        await selectPreferredNode(at: index)
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
        cancelProviderConnectingRecovery()
        suppressProviderConnectingPresentation = false
        connectionFailureMessage = nil
        nodeFailoverToast = nil
        cancelNodeSelection()
        probeCounterSummary = nil
        cancelPostConnectProbe()
        cancelLatencyRound()
        #if DEBUG && targetEnvironment(simulator)
        connectionState = .idle
        connectionFailureMessage = "VPN connection testing requires a signed build on a physical iPhone."
        return
        #endif
        connectionState = .connecting
        let startupStartedAt = Date()
        connectionTask = Task { [weak self] in
            guard let self else { return }
            defer { finishConnectionTransaction() }
            let trace = ConnectionDiagnosticTrace()
            do {
                try await raceConnectionAttempt(trace: trace)
                #if DEBUG
                let duration = Date().timeIntervalSince(startupStartedAt)
                defaults.set(duration, forKey: Self.debugStartupDurationKey)
                print(String(format: "Routeva VPN startup timing: total=%.3fs", duration))
                #endif
            } catch is CancellationError {
                if case .connecting = connectionState {
                    connectionState = .idle
                }
                scheduleSilentLatencyTestIfNeeded()
            } catch ConnectionAttemptOutcomeError.timedOut {
                await handleConnectionAttemptTimeout(trace: trace)
                scheduleSilentLatencyTestIfNeeded()
            } catch {
                suppressProviderConnectingPresentation = true
                await presentDiagnostic(from: trace)
                scheduleSilentLatencyTestIfNeeded()
            }
        }
    }

    /// Connecting 或 Connected：同一电源键都是停会话。Connecting 立即回 Idle。
    func stopSession() {
        switch connectionState {
        case .connecting:
            cancelConnecting()
        case .connected:
            disconnect()
        case .idle, .failed:
            break
        }
    }

    func disconnect() {
        guard case .connected = connectionState, disconnectionTask == nil else { return }
        let core = connectedCore ?? .singBox
        connectionTask?.cancel()
        connectionTask = nil
        cancelProviderConnectingRecovery()
        cancelNodeSelection()
        cancelPostConnectProbe()
        stopTrafficPolling()
        connectedCore = nil
        clearConnectedNodeState()
        // Do not keep Home visually connected while iOS asynchronously reaps
        // a provider whose stop command is being submitted immediately below.
        connectionState = .idle
        sessionDownloadedBytes = 0
        sessionUploadedBytes = 0
        let controller = providerController
        let stopStartedAt = Date()
        disconnectionTask = Task { [weak self] in
            guard let self else { return }
            defer {
                disconnectionTask = nil
                Task { [weak self] in
                    await self?.reconcileProviderConnectionStatus()
                }
                scheduleSilentLatencyTestIfNeeded()
            }
            await controller.requestStop(core: core)
            await connectionCoordinator.reconcile(.disconnected)
            #if DEBUG
            print(String(
                format: "Routeva VPN stop command submitted in %.3fs",
                Date().timeIntervalSince(stopStartedAt)
            ))
            #endif
        }
    }

    func cancelConnecting() {
        guard case .connecting = connectionState else { return }
        abortConnectingSession()
    }

    func setHomeVisible(_ visible: Bool) {
        isHomeVisible = visible
        refreshTrafficPolling()
        if visible {
            scheduleSilentLatencyTestIfNeeded()
        }
    }

    func setSceneActive(_ active: Bool) {
        isSceneActive = active
        refreshTrafficPolling()
        if active {
            Task {
                await reconcileProviderConnectionStatus()
                await syncOverrides()
                await reconcileSelectedNodeIfNeeded()
                scheduleSilentLatencyTestIfNeeded()
            }
        }
    }

    private func observeProviderStatusChanges() {
        providerStatusObservationTask = Task { [weak self] in
            for await notification in NotificationCenter.default.notifications(
                named: .NEVPNStatusDidChange
            ) {
                guard !Task.isCancelled, let self else { return }
                guard let connection = notification.object as? NEVPNConnection else { continue }
                // The notification already carries the live connection object.
                // Do not reload manager preferences here: doing so creates a
                // fresh extended-status request and another notification.
                let status = connection.status
                guard status != lastObservedProviderStatus,
                      let snapshot = Self.providerConnectionSnapshot(for: status)
                else { continue }
                lastObservedProviderStatus = status
                await applyProviderStatusNotification(snapshot)
            }
        }
    }

    private static func providerConnectionSnapshot(
        for status: NEVPNStatus
    ) -> ProviderConnectionSnapshot? {
        switch status {
        case .invalid, .disconnected:
            .disconnected
        case .connecting:
            .connecting(core: .singBox)
        case .connected:
            .connected(core: .singBox, since: nil)
        case .reasserting:
            .reasserting(core: .singBox, since: nil)
        case .disconnecting:
            .disconnecting(core: .singBox)
        @unknown default:
            nil
        }
    }

    private func applyProviderStatusNotification(
        _ snapshot: ProviderConnectionSnapshot
    ) async {
        guard connectionTask == nil,
              disconnectionTask == nil,
              repairTask == nil
        else { return }

        providerStatusNotificationRevision += 1
        await connectionCoordinator.reconcile(snapshot)
        guard connectionTask == nil,
              disconnectionTask == nil,
              repairTask == nil
        else { return }

        hasResolvedProviderStatus = true
        applyProviderConnectionSnapshot(snapshot)
        await reconcileSelectedNodeIfNeeded()
    }

    private func finishConnectionTransaction() {
        connectionTask = nil
        Task { [weak self] in
            await self?.reconcileProviderConnectionStatus()
        }
    }

    /// Reconciles only when no App-owned connection transaction is active.
    /// This prevents transient `.disconnected` notifications from the
    /// stop-before-reconnect path from overwriting the in-flight UI state.
    private func reconcileProviderConnectionStatus() async {
        guard connectionTask == nil,
              disconnectionTask == nil,
              repairTask == nil
        else { return }
        guard providerStatusRefreshGate.requestRefresh() else { return }

        while true {
            guard connectionTask == nil,
                  disconnectionTask == nil,
                  repairTask == nil
            else {
                providerStatusRefreshGate.cancel()
                return
            }

            let snapshot: ProviderConnectionSnapshot
            do {
                snapshot = try await providerController.connectionSnapshot()
            } catch {
                // A preferences read failure is unknown, not Disconnected. Keep
                // the last honest UI state and retry on the next lifecycle event.
                #if DEBUG
                print("Routeva VPN status reconciliation: provider.preferences_unavailable")
                #endif
                guard providerStatusRefreshGate.finishPass() else { return }
                continue
            }
            guard connectionTask == nil,
                  disconnectionTask == nil,
                  repairTask == nil
            else {
                providerStatusRefreshGate.cancel()
                return
            }

            // Capture this after the system read completes. A notification
            // arriving later is newer and must win while the coordinator call
            // below is suspended.
            let notificationRevisionAtSnapshot = providerStatusNotificationRevision
            await connectionCoordinator.reconcile(snapshot)
            guard connectionTask == nil,
                  disconnectionTask == nil,
                  repairTask == nil
            else {
                providerStatusRefreshGate.cancel()
                return
            }
            if notificationRevisionAtSnapshot == providerStatusNotificationRevision {
                hasResolvedProviderStatus = true
                applyProviderConnectionSnapshot(snapshot)
            }

            guard providerStatusRefreshGate.finishPass() else { return }
        }
    }

    private func applyProviderConnectionSnapshot(_ snapshot: ProviderConnectionSnapshot) {
        if snapshot.presentsAsConnected, let core = snapshot.core {
            cancelProviderConnectingRecovery()
            let shouldProbeRecoveredSession: Bool
            let existingStart: Date?
            if connectedCore == core,
               case let .connected(sessionStartedAt) = connectionState {
                existingStart = sessionStartedAt
                shouldProbeRecoveredSession = false
            } else {
                existingStart = nil
                shouldProbeRecoveredSession = true
                cancelNodeSelection()
                cancelPostConnectProbe()
                clearConnectedNodeState()
                sessionDownloadedBytes = 0
                sessionUploadedBytes = 0
            }
            pauseSilentLatencyTest()
            connectedCore = core
            currentDiagnosticResult = nil
            connectionFailureMessage = nil
            connectionState = .connected(
                sessionStartedAt: snapshot.connectedSince ?? existingStart ?? .now
            )
            refreshTrafficPolling()
            if shouldProbeRecoveredSession {
                startPostConnectProbe(core: core, excludedNodeAddresses: nil)
            }
            return
        }

        switch snapshot {
        case let .connecting(core):
            cancelLatencyRound()
            cancelNodeSelection()
            cancelPostConnectProbe()
            stopTrafficPolling()
            clearConnectedNodeState()
            scheduleProviderConnectingRecovery(for: core)
            switch ProviderConnectingPresentation.evaluate(
                appReleasedConnecting: suppressProviderConnectingPresentation
            ) {
            case .suppressAndReap:
                return
            case .presentOrphaned:
                connectedCore = core
                connectionState = .connecting
            }

        case .disconnecting:
            cancelProviderConnectingRecovery()
            clearProviderConnectionPresentationIfNeeded()

        case .disconnected:
            suppressProviderConnectingPresentation = false
            cancelProviderConnectingRecovery()
            clearProviderConnectionPresentationIfNeeded()
            scheduleSilentLatencyTestIfNeeded()

        case .connected, .reasserting:
            break
        }
    }

    private func clearProviderConnectionPresentationIfNeeded() {
        let hadManagedSession = connectedCore != nil || {
            switch connectionState {
            case .connecting, .connected:
                true
            case .idle, .failed:
                false
            }
        }()
        guard hadManagedSession else { return }
        cancelNodeSelection()
        cancelPostConnectProbe()
        stopTrafficPolling()
        connectedCore = nil
        clearConnectedNodeState()
        connectionState = .idle
        sessionDownloadedBytes = 0
        sessionUploadedBytes = 0
    }

    /// A `.connecting` snapshot without an App-owned transaction can be left
    /// behind by a terminated host process. Recheck it once at the same bound
    /// used by normal startup, then stop only Routeva's still-stuck provider.
    private func scheduleProviderConnectingRecovery(for core: CoreIdentifier) {
        guard providerConnectingRecoveryTask == nil else { return }
        let recoveryID = UUID()
        providerConnectingRecoveryID = recoveryID
        let controller = providerController
        providerConnectingRecoveryTask = Task { [weak self] in
            guard let self else { return }
            defer {
                if providerConnectingRecoveryID == recoveryID {
                    providerConnectingRecoveryTask = nil
                    providerConnectingRecoveryID = nil
                }
            }
            do {
                try await Task.sleep(for: Self.orphanedProviderConnectingTimeout)
            } catch {
                return
            }
            guard providerConnectingRecoveryID == recoveryID,
                  connectionTask == nil,
                  disconnectionTask == nil,
                  repairTask == nil
            else { return }
            if !suppressProviderConnectingPresentation {
                guard connectedCore == core, case .connecting = connectionState else { return }
            }

            let snapshot: ProviderConnectionSnapshot
            do {
                snapshot = try await controller.connectionSnapshot()
            } catch {
                return
            }
            guard !Task.isCancelled,
                  providerConnectingRecoveryID == recoveryID,
                  connectionTask == nil,
                  disconnectionTask == nil,
                  repairTask == nil
            else { return }

            guard snapshot == .connecting(core: core) else {
                await connectionCoordinator.reconcile(snapshot)
                guard !Task.isCancelled,
                      providerConnectingRecoveryID == recoveryID,
                      connectionTask == nil,
                      disconnectionTask == nil,
                      repairTask == nil
                else { return }
                hasResolvedProviderStatus = true
                applyProviderConnectionSnapshot(snapshot)
                return
            }

            await controller.requestStop(core: core)
            guard !Task.isCancelled,
                  providerConnectingRecoveryID == recoveryID,
                  connectionTask == nil,
                  disconnectionTask == nil,
                  repairTask == nil
            else { return }
            suppressProviderConnectingPresentation = true
            await connectionCoordinator.reconcile(.disconnected)
            hasResolvedProviderStatus = true
            clearProviderConnectionPresentationIfNeeded()
            #if DEBUG
            connectionFailureMessage =
                "VPN connection timed out. Try again. [provider.orphaned_connecting_timeout]"
            #else
            connectionFailureMessage = "VPN connection timed out. Try again."
            #endif
        }
    }

    private func cancelProviderConnectingRecovery() {
        providerConnectingRecoveryTask?.cancel()
        providerConnectingRecoveryTask = nil
        providerConnectingRecoveryID = nil
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
        let coreToStop = connectedCore
        cancelProviderConnectingRecovery()
        suppressProviderConnectingPresentation = false
        cancelNodeSelection()
        cancelPostConnectProbe()
        stopTrafficPolling()
        connectionState = .connecting
        let controller = providerController
        let startupStartedAt = Date()
        connectionTask = Task { [weak self] in
            guard let self else { return }
            defer { finishConnectionTransaction() }
            if let coreToStop {
                await controller.stop(core: coreToStop)
            } else {
                try? await controller.disconnectAll()
            }
            await connectionCoordinator.reconcile(.disconnected)
            connectedCore = nil
            clearConnectedNodeState()
            let trace = ConnectionDiagnosticTrace()
            do {
                try await raceConnectionAttempt(trace: trace)
                #if DEBUG
                let duration = Date().timeIntervalSince(startupStartedAt)
                defaults.set(duration, forKey: Self.debugStartupDurationKey)
                print(String(format: "Routeva VPN startup timing: total=%.3fs", duration))
                #endif
            } catch is CancellationError {
                if case .connecting = connectionState {
                    connectionState = .idle
                }
            } catch ConnectionAttemptOutcomeError.timedOut {
                await handleConnectionAttemptTimeout(trace: trace)
            } catch {
                suppressProviderConnectingPresentation = true
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
                Task { [weak self] in
                    await self?.reconcileProviderConnectionStatus()
                }
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
        if activeSubscription?.id == id, !isSwitchingActiveSubscription { return }
        pendingActiveSubscriptionID = id
        guard !isSwitchingActiveSubscription else { return }
        isSwitchingActiveSubscription = true
        defer { isSwitchingActiveSubscription = false }

        // A live session is bound to the current Active catalog. Switching
        // Active stops that session first and does not reconnect — unlike
        // node selection, which stays inside one subscription.
        await stopSessionBeforeSwitchingActiveSubscription(
            for: pendingActiveSubscriptionID ?? id
        )
        // `disconnect()` may have started a silent round against the old
        // catalog. Drop it so `reloadSubscriptions` can test the new one.
        cancelLatencyRound()

        while let target = pendingActiveSubscriptionID {
            if target == activeSubscription?.id {
                pendingActiveSubscriptionID = nil
                break
            }
            do {
                try await database.setActiveSubscription(target)
                await reloadSubscriptions()
            } catch {
                await reloadSubscriptions()
                if pendingActiveSubscriptionID == target {
                    pendingActiveSubscriptionID = nil
                }
                return
            }
            if pendingActiveSubscriptionID == target {
                pendingActiveSubscriptionID = nil
                break
            }
        }
    }

    /// Stops Connecting / Connected before Active can change. Does not start a
    /// new session — the user reconnects from Home with the new catalog.
    private func stopSessionBeforeSwitchingActiveSubscription(for id: UUID) async {
        cancelLatencyRound()
        switch ActiveSubscriptionSwitch.evaluate(
            isAlreadyActive: activeSubscription?.id == id,
            isConnecting: isConnectingForLatency,
            isConnected: isConnectedForLatency
        ) {
        case .ignore, .apply:
            break
        case .stopConnected:
            disconnect()
        case .abortConnecting:
            abortConnectingSession()
        }
        await disconnectionTask?.value
    }

    /// 立刻把 Home 拉回 Idle，再在后台停 provider。Connecting 电源键与切 Active 共用。
    private func abortConnectingSession() {
        suppressProviderConnectingPresentation = true
        let core = connectedCore ?? .singBox
        connectionTask?.cancel()
        cancelProviderConnectingRecovery()
        cancelNodeSelection()
        cancelPostConnectProbe()
        stopTrafficPolling()
        connectedCore = nil
        clearConnectedNodeState()
        connectionState = .idle
        sessionDownloadedBytes = 0
        sessionUploadedBytes = 0
        guard disconnectionTask == nil else { return }
        let controller = providerController
        disconnectionTask = Task { [weak self] in
            guard let self else { return }
            defer {
                disconnectionTask = nil
                Task { [weak self] in
                    await self?.reconcileProviderConnectionStatus()
                }
                scheduleSilentLatencyTestIfNeeded()
            }
            await connectionTask?.value
            await controller.requestStop(core: core)
            await connectionCoordinator.reconcile(.disconnected)
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
        cancelLatencyRound()
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
            nodeSelectionOwnedByUser = true
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
        Self.filteredTunnelProbeAddressSets(
            connectedTunnelProbeAddressSets,
            excluding: directRouteAddresses
        )
    }

    private static func filteredTunnelProbeAddressSets(
        _ addressSets: [ProviderTunnelProbeAddressSet],
        excluding directRouteAddresses: [String]
    ) -> [ProviderTunnelProbeAddressSet] {
        addressSets.compactMap { addressSet in
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
        dnsHealthMonitor.reset()
    }

    /// User-visible Location *Test* — same measurement as silent latency.
    func testNodeLatencies() async {
        await runLatencyRound(userInitiated: true)
    }

    /// Location 离开 / 点选 / Connecting：取消本轮，保留已写出的 ms。
    func cancelLocationLatencyTest() {
        cancelLatencyRound()
    }

    var canStartLocationLatencyTest: Bool {
        switch connectionState {
        case .connecting: false
        case .idle, .failed, .connected: !availableNodes.isEmpty
        }
    }

    /// Schedule a silent full-table TCP latency round when idle and cache is cold.
    func scheduleSilentLatencyTestIfNeeded() {
        // Until NetworkExtension preferences have been read, `.idle` is only
        // a launch placeholder and must not start work beside a surviving VPN.
        guard hasResolvedProviderStatus else { return }
        guard isIdleForLatencyWork else { return }
        guard activeSubscription != nil, !availableNodes.isEmpty else { return }
        guard !isTestingNodes, silentLatencyTask == nil else { return }
        if let completedAt = defaults.object(forKey: Self.latencyRoundCompletedAtKey) as? Date,
           Date().timeIntervalSince(completedAt) < Self.latencyCacheTTL,
           !locationOrderIDs.isEmpty {
            return
        }
        silentLatencyTask = Task { [weak self] in
            guard let self else { return }
            defer { silentLatencyTask = nil }
            await runLatencyRound(userInitiated: false)
        }
    }

    private var isIdleForLatencyWork: Bool {
        switch connectionState {
        case .idle, .failed: true
        case .connecting, .connected: false
        }
    }

    private var isConnectingForLatency: Bool {
        if case .connecting = connectionState { true } else { false }
    }

    private var isConnectedForLatency: Bool {
        if case .connected = connectionState { true } else { false }
    }

    private func pauseSilentLatencyTest() {
        silentLatencyTask?.cancel()
        silentLatencyTask = nil
        // 用户 *Test* 进行中不要被 Connected 快照刷新杀掉。
        guard !latencyRoundIsUserInitiated else { return }
        latencyRoundGeneration += 1
        isTestingNodes = false
    }

    private func cancelLatencyRound() {
        silentLatencyTask?.cancel()
        silentLatencyTask = nil
        latencyRoundGeneration += 1
        isTestingNodes = false
        latencyRoundIsUserInitiated = false
        restoreIncompleteLatencyRound()
    }

    private func restoreIncompleteLatencyRound() {
        guard !latencyRoundBaseline.isEmpty || isTestingNodes else { return }
        var restored = latencyRoundBaseline
        for (id, status) in nodeLatencies {
            switch status {
            case .measured, .unavailable:
                restored[id] = status
            case .testing:
                break
            }
        }
        nodeLatencies = restored
        latencyRoundBaseline = [:]
    }

    private func presentLatencyTestUnavailable() {
        latencyTestUnavailableToast = true
    }

    private func runLatencyRound(userInitiated: Bool) async {
        guard let database, let activeSubscription else { return }
        guard let records = try? await database.nodes(subscriptionID: activeSubscription.id),
              !records.isEmpty else { return }

        switch LatencyTestAdmission.evaluate(
            userInitiated: userInitiated,
            isConnecting: isConnectingForLatency,
            isConnected: isConnectedForLatency
        ) {
        case .run:
            break
        case .ignoreSilent:
            return
        case .refuseConnecting:
            cancelLatencyRound()
            return
        }

        let useProviderEntryPath = userInitiated && isConnectedForLatency
        if useProviderEntryPath, connectedCore != .singBox {
            presentLatencyTestUnavailable()
            return
        }

        let generation = latencyRoundGeneration + 1
        latencyRoundGeneration = generation
        latencyRoundBaseline = nodeLatencies
        latencyRoundIsUserInitiated = userInitiated
        isTestingNodes = true
        defer {
            if latencyRoundGeneration == generation {
                isTestingNodes = false
                latencyRoundIsUserInitiated = false
                latencyRoundBaseline = [:]
            }
        }

        // Mark outstanding as testing without wiping prior ms until replaced.
        for record in records {
            if nodeLatencies[record.id] == nil || userInitiated {
                nodeLatencies[record.id] = .testing
            } else if case .measured = nodeLatencies[record.id] {
                // Keep last good ms while re-probing silently.
            } else {
                nodeLatencies[record.id] = .testing
            }
        }
        if userInitiated {
            nodeLatencies = Dictionary(uniqueKeysWithValues: records.map { ($0.id, .testing) })
        }

        let batchSize = ProviderEntryLatencyCode.maximumBatchCount
        for start in stride(from: 0, to: records.count, by: batchSize) {
            if Task.isCancelled || latencyRoundGeneration != generation {
                restoreIncompleteLatencyRound()
                return
            }
            if case .connecting = connectionState {
                cancelLatencyRound()
                return
            }
            if !userInitiated, case .connected = connectionState {
                restoreIncompleteLatencyRound()
                return
            }

            let batch = Array(records[start..<min(start + batchSize, records.count)])
            let samples: [(UUID, NodeLatencyProbeResult)]
            if useProviderEntryPath {
                do {
                    samples = try await measureConnectedEntryLatencies(batch)
                } catch {
                    nodeLatencies = latencyRoundBaseline
                    presentLatencyTestUnavailable()
                    return
                }
            } else {
                samples = await measureLocalEntryLatencies(batch)
            }

            if samples.contains(where: {
                if case .pathUnavailable = $0.1 { return true }
                return false
            }) {
                nodeLatencies = latencyRoundBaseline
                presentLatencyTestUnavailable()
                return
            }

            for (id, result) in samples {
                guard latencyRoundGeneration == generation else {
                    restoreIncompleteLatencyRound()
                    return
                }
                switch result {
                case let .measured(milliseconds):
                    nodeLatencies[id] = .measured(milliseconds)
                case .timeout:
                    nodeLatencies[id] = .unavailable
                case .pathUnavailable:
                    break
                }
            }
        }

        guard latencyRoundGeneration == generation else {
            restoreIncompleteLatencyRound()
            return
        }
        if case .connecting = connectionState {
            cancelLatencyRound()
            return
        }

        applyLatencyRoundResults(
            nodes: availableNodes,
            updateCoverFlowPrestop: !isConnectedForLatency
        )
        defaults.set(Date(), forKey: Self.latencyRoundCompletedAtKey)
    }

    private func measureLocalEntryLatencies(
        _ records: [NodeRecord]
    ) async -> [(UUID, NodeLatencyProbeResult)] {
        await withTaskGroup(of: (UUID, NodeLatencyProbeResult).self) { group in
            for record in records {
                group.addTask {
                    guard record.protocolKind != .hysteria2 else {
                        return (record.id, .timeout)
                    }
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
            var samples: [(UUID, NodeLatencyProbeResult)] = []
            samples.reserveCapacity(records.count)
            for await sample in group {
                samples.append(sample)
            }
            return samples
        }
    }

    private func measureConnectedEntryLatencies(
        _ records: [NodeRecord]
    ) async throws -> [(UUID, NodeLatencyProbeResult)] {
        let samples = try await providerController.measureEntryLatencies(
            core: .singBox,
            nodeIDs: records.map(\.id)
        )
        let byID = Dictionary(uniqueKeysWithValues: samples.map { ($0.nodeID, $0) })
        return records.map { record in
            guard let sample = byID[record.id] else {
                return (record.id, .timeout)
            }
            if let milliseconds = sample.milliseconds {
                return (record.id, .measured(Int(milliseconds)))
            }
            return (record.id, .timeout)
        }
    }

    private func applyLatencyRoundResults(
        nodes: [NodeSummary],
        updateCoverFlowPrestop: Bool
    ) {
        // Always refresh Location order. Cover Flow stays subscription order.
        locationOrderIDs = Self.sortedNodeIDsByLatency(nodes: nodes, latencies: nodeLatencies)

        // Connected *Test* 不得改 Cover Flow 下标（ADR 0069）。
        // Cover Flow / Location pick owns focus until the catalog changes.
        // Pre-stop must not yank the user back to Preferred or lowest-ms.
        guard updateCoverFlowPrestop, !nodeSelectionOwnedByUser else { return }

        let preferredID = activeSubscription?.preferredNodeID
        if let preferredID,
           let preferredIndex = nodes.firstIndex(where: { $0.id == preferredID }) {
            selectedNodeIndex = preferredIndex
            return
        }
        // No Preferred: pre-stop on lowest ms among measured nodes.
        if let bestID = locationOrderIDs.first(where: {
            if case .measured = nodeLatencies[$0] { return true }
            return false
        }), let bestIndex = nodes.firstIndex(where: { $0.id == bestID }) {
            selectedNodeIndex = bestIndex
        }
    }

    private static func sortedNodeIDsByLatency(
        nodes: [NodeSummary],
        latencies: [UUID: NodeLatencyStatus]
    ) -> [UUID] {
        let indexed = nodes.enumerated().map { offset, node in (offset, node) }
        return indexed.sorted { lhs, rhs in
            let l = latencySortKey(latencies[lhs.1.id])
            let r = latencySortKey(latencies[rhs.1.id])
            if l.bucket != r.bucket { return l.bucket < r.bucket }
            if l.ms != r.ms { return l.ms < r.ms }
            return lhs.0 < rhs.0
        }.map(\.1.id)
    }

    /// bucket: 0 = measured, 1 = timeout, 2 = unknown/testing
    private static func latencySortKey(_ status: NodeLatencyStatus?) -> (bucket: Int, ms: Int) {
        switch status {
        case let .measured(ms): return (0, ms)
        case .unavailable: return (1, Int.max)
        case .testing, .none: return (2, Int.max)
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
        let previousActiveID = activeSubscription?.id
        let previousNodeIDs = Set(availableNodes.map(\.id))
        // Preserve temporary Cover Flow focus across reloads when possible.
        let previousSelectedID = availableNodes.indices.contains(selectedNodeIndex)
            ? availableNodes[selectedNodeIndex].id
            : nil
        subscriptions = summaries
        let newNodeIDs = Set(availableNodes.map(\.id))
        let catalogChanged = activeSubscription?.id != previousActiveID || newNodeIDs != previousNodeIDs
        if catalogChanged {
            // New node set: system owns focus again (Preferred / index 0).
            nodeSelectionOwnedByUser = false
            locationOrderIDs = []
            defaults.removeObject(forKey: Self.latencyRoundCompletedAtKey)
        }

        if nodeSelectionOwnedByUser,
           let previousSelectedID,
           let keptIndex = availableNodes.firstIndex(where: { $0.id == previousSelectedID }) {
            selectedNodeIndex = keptIndex
        } else if let preferredNodeID = activeSubscription?.preferredNodeID,
                  let preferredIndex = availableNodes.firstIndex(where: { $0.id == preferredNodeID }) {
            selectedNodeIndex = preferredIndex
        } else if selectedNodeIndex >= availableNodes.count {
            selectedNodeIndex = 0
        }

        if catalogChanged {
            scheduleSilentLatencyTestIfNeeded()
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
        guard let secrets else { throw RoutevaAppDataError.persistenceUnavailable }
        var echResolverHosts: [String] = []
        for candidate in catalogNodes {
            let credentialData = try await secrets.data(for: candidate.credentialReference)
            let credential = try JSONDecoder().decode(
                ProxyCredentialEnvelope.self,
                from: credentialData
            )
            if let host = Self.echResolverHost(in: credential.options) {
                echResolverHosts.append(host)
            }
        }
        let catalogEndpointHosts = catalogNodes.map(\.endpointHost)
        let resolvedEndpointAddresses = await DomainRouteResolver().resolveAddressSets(
            domains: catalogEndpointHosts
        )
        let resolvedECHAddresses = await DomainRouteResolver().resolveAddressSets(
            domains: echResolverHosts
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
            resolvedECHAddresses.values.flatMap { $0 }
                + catalogEndpointHosts
                + resolvedEndpointAddresses.values.flatMap { $0 }
        )
        var bootstrapAddressMap: [String: [String]] = [:]
        for (host, addresses) in resolvedEndpointAddresses {
            bootstrapAddressMap[host.lowercased(), default: []].append(contentsOf: addresses)
        }
        for (host, addresses) in resolvedECHAddresses {
            bootstrapAddressMap[host.lowercased(), default: []].append(contentsOf: addresses)
        }
        bootstrapAddressMap = bootstrapAddressMap.mapValues {
            DirectRouteAddressValidator.validated($0)
        }
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
            dnsBootstrapAddressMap: bootstrapAddressMap,
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

    private static func echResolverHost(in options: [String: String]) -> String? {
        let normalized = Dictionary(
            options.map { ($0.key.lowercased(), $0.value) },
            uniquingKeysWith: { _, rhs in rhs }
        )
        guard let raw = normalized["ech"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty,
              !raw.contains("BEGIN")
        else { return nil }
        let ranges = ["+https://", " https://"].compactMap { marker in
            raw.range(of: marker, options: [.caseInsensitive])
        }
        guard let range = ranges.min(by: { $0.lowerBound < $1.lowerBound }) else { return nil }
        let schemeStart = raw.index(range.lowerBound, offsetBy: 1)
        guard let components = URLComponents(string: String(raw[schemeStart...])),
              components.scheme?.lowercased() == "https",
              let host = components.host?.lowercased(),
              !host.isEmpty
        else { return nil }
        return host
    }

    private func raceConnectionAttempt(trace: ConnectionDiagnosticTrace) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await self.establishConnection(trace: trace)
            }
            group.addTask {
                try await Task.sleep(for: Self.connectionAttemptTimeout)
                throw ConnectionAttemptOutcomeError.timedOut
            }
            try await group.next()
            group.cancelAll()
        }
    }

    private func handleConnectionAttemptTimeout(trace: ConnectionDiagnosticTrace) async {
        suppressProviderConnectingPresentation = true
        let core = connectedCore ?? .singBox
        await providerController.requestStop(core: core)
        await connectionCoordinator.reconcile(.disconnected)
        await trace.record(.init(
            layer: .tunnel,
            status: .failed,
            errorCode: "provider.connection_attempt_timeout"
        ))
        await presentDiagnostic(from: trace)
    }

    private func establishConnection(trace: ConnectionDiagnosticTrace) async throws {
        probeCounterSummary = nil
        // NetworkExtension is authoritative. A coordinator retained from an
        // earlier externally-ended session must not reject this fresh request.
        await connectionCoordinator.reconcile(.disconnected)
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
                if selectedNodeIndex != originalIndex,
                   availableNodes.indices.contains(selectedNodeIndex) {
                    nodeFailoverToast = availableNodes[selectedNodeIndex].name
                }
                return
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as NonFailoverConnectionError {
                throw error
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

        // Quick TCP reachability on the selected node before bringing the
        // tunnel up — rejects obviously dead endpoints (avoids a "connected"
        // shell that cannot forward). Hysteria2 is UDP-only; skip and rely on
        // the post-connect core probe.
        try await verifySelectedNodeReachable(trace: trace)

        let controller = providerController
        let excludedNodeAddresses = manifest.directRouteAddresses
        let tunnelProbeAddressSets = await DomainRouteResolver()
            .resolveIPv4AddressSets(
                domains: ProviderTunnelProbeCatalog.ipv4ResolutionHosts
            )
        let filteredProbeAddressSets = Self.filteredTunnelProbeAddressSets(
            tunnelProbeAddressSets,
            excluding: excludedNodeAddresses
        )
        let startupTiming = StartupTimingBox()
        let verifiedSelection = StartupNodeSelectionBox()
        let automaticFailoverNodeIDs = NodeFailoverPlanner().candidates(
            routingMode: routingMode.runtimeValue,
            isPreferredPinned: activeSubscription?.preferredNodeID != nil,
            currentIndex: selectedNodeIndex,
            available: availableNodes.enumerated().map { index, node in
                let score: Int?
                if case let .measured(milliseconds) = nodeLatencies[node.id] {
                    score = milliseconds
                } else {
                    score = nil
                }
                return NodeFailoverCandidate(index: index, healthScore: score)
            }
        ).map { availableNodes[$0].id }
        let runtimeNodeIDs = Set(manifest.profiles.map(\.id))
        let probeNodeIDs = automaticFailoverNodeIDs.filter { runtimeNodeIDs.contains($0) }
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
                stopProvider: { core in await controller.requestStop(core: core) },
                probe: { core in
                    var lastError: (any Error)?
                    for (index, nodeID) in probeNodeIDs.enumerated() {
                        do {
                            if index > 0 {
                                let actualNodeID = try await controller.selectNode(
                                    core: core,
                                    nodeID: nodeID
                                )
                                guard actualNodeID == nodeID else {
                                    throw RoutevaAppDataError.nodeUnavailable
                                }
                            }
                            _ = try await controller.probeCore(
                                core: core,
                                tunnelProbeAddressSets: filteredProbeAddressSets
                            )
                            verifiedSelection.store(nodeID)
                            await trace.record(.init(layer: .probe, status: .passed))
                            return
                        } catch {
                            lastError = error
                        }
                    }
                    let error = lastError ?? RoutevaAppDataError.nodeUnavailable
                    await trace.record(.init(
                        layer: .probe,
                        status: .failed,
                        errorCode: VPNProviderController
                            .stableCoreProbeDiagnosticCode(for: error)
                    ))
                    throw error
                }
            )
        } catch is CancellationError {
            throw CancellationError()
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
            throw NonFailoverConnectionError.providerUnavailable
        } catch {
            // A provider that reached its through-proxy probe can fail because
            // this exact node cannot relay traffic. Let Smart mode advance to
            // the next subscription node; pinned modes still have one candidate.
            throw error
        }
        try Task.checkCancellation()
        #if DEBUG
        if let duration = startupTiming.providerDuration {
            defaults.set(duration, forKey: Self.debugProviderStartupDurationKey)
        }
        #endif
        let connectedNodeID = verifiedSelection.nodeID ?? manifest.profile.id
        if let connectedNodeIndex = availableNodes.firstIndex(where: {
            $0.id == connectedNodeID
        }) {
            selectedNodeIndex = connectedNodeIndex
        }
        connectedCore = result.core
        verifiedNodeID = connectedNodeID
        runtimeCatalogNodeIDs = Set(manifest.profiles.map(\.id))
        connectedTunnelProbeAddressSets = tunnelProbeAddressSets
        connectedDirectRouteAddresses = excludedNodeAddresses
        sessionDownloadedBytes = 0
        sessionUploadedBytes = 0
        currentDiagnosticResult = nil
        hasResolvedProviderStatus = true
        connectionState = .connected(sessionStartedAt: .now)
        refreshTrafficPolling()
        startPostConnectProbe(
            core: result.core,
            excludedNodeAddresses: excludedNodeAddresses
        )
    }

    private func startPostConnectProbe(
        core: CoreIdentifier,
        excludedNodeAddresses suppliedExcludedNodeAddresses: [String]?
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
                var excludedNodeAddresses = suppliedExcludedNodeAddresses
                if excludedNodeAddresses == nil,
                   let manifest = await currentRuntimeManifest() {
                    guard !Task.isCancelled,
                          postConnectProbeTaskID == taskID,
                          connectedCore == core else { return }
                    applyReloadedManifestState(manifest)
                    excludedNodeAddresses = manifest.directRouteAddresses
                }
                let resolvedExcludedNodeAddresses = excludedNodeAddresses ?? []
                // Keep the health request away from the traffic sampler's
                // immediate warm-up pair and from the provider's 200ms IPC
                // pacing window.
                try await Task.sleep(for: .milliseconds(500))
                guard connectedCore == core else { return }
                let baseline = core == .singBox
                    ? try? await controller.queryDataPlane(core: core)
                    : nil
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
                        excluding: resolvedExcludedNodeAddresses
                    )
                    if #available(iOS 18.0, *), tunnelProbeAddressSets.isEmpty {
                        // DNS-SD can return no usable IPv4 callback while an
                        // existing tunnel remains healthy (for example after
                        // foreground recovery or a cache-only answer). Treat the
                        // empty probe result as inconclusive unless this exact
                        // counter window proves an upstream DNS failure.
                        try? await Task.sleep(for: .milliseconds(250))
                        guard !Task.isCancelled,
                              postConnectProbeTaskID == taskID,
                              connectedCore == core else { return }
                        let dataPlane = try? await controller.queryDataPlane(core: core)
                        probeCounterSummary = (dataPlane?.probeCounterSummary ?? "snapshot=none")
                            + " " + SystemProxyDiagnostics.summary
                        #if DEBUG
                        let errorCode = dataPlane?
                            .dnsResolutionFailureDiagnosticCode(since: baseline)
                            ?? "probe.dns_preflight_inconclusive"
                        print(
                            "Routeva VPN DNS preflight warning: \(errorCode); "
                                + "keeping connected session "
                                + "[\(probeCounterSummary ?? "snapshot=none")]"
                        )
                        #endif
                        return
                    }
                } else {
                    tunnelProbeAddressSets = []
                }
                let probeStartedAt = Date()
                do {
                    if core == .singBox {
                        _ = try await controller.probeCore(
                            core: core,
                            tunnelProbeAddressSets: tunnelProbeAddressSets
                        )
                    } else {
                        try await probe.run(
                            excludedRouteAddresses: resolvedExcludedNodeAddresses
                        )
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
                    let dnsFailureCode = dataPlane?
                        .dnsUpstreamFailureDiagnosticCode(since: baseline)
                    let trafficProvesTunnel = dnsFailureCode == nil
                        && !countersReset
                        && baseline.map { baseline in
                            dataPlane?.provesBidirectionalIPv4TunnelProgress(since: baseline)
                                == true
                        } == true
                    let nonDNSFailureCode = trafficProvesTunnel
                        ? "probe.post_connect_endpoint_unavailable"
                        : (countersReset
                            ? "probe.bridge_counters_reset"
                            : dataPlaneProbeDiagnosticCode(dataPlane, fallback: fallback))
                    let errorCode = dnsFailureCode ?? nonDNSFailureCode
                    probeCounterSummary = diagnosticSummary
                    #if DEBUG
                    print(
                        "Routeva VPN post-connect health warning: \(errorCode) "
                            + "[\(diagnosticSummary)]"
                    )
                    #endif
                    // A health target or resolver can be temporarily blocked
                    // while the selected node remains usable. Mature proxy
                    // clients keep an established user session alive and make
                    // health checks advisory; only provider/runtime failure or
                    // an explicit user action should stop the system tunnel.
                }
            } catch is CancellationError {
                return
            } catch {
                return
            }
        }
    }

    private func currentRuntimeManifest() async -> RuntimeManifest? {
        guard let database,
              let record = try? await database.currentRuntimeManifest()
        else { return nil }
        return try? JSONDecoder().decode(RuntimeManifest.self, from: record.manifestData)
    }

    private func cancelPostConnectProbe() {
        postConnectProbeTask?.cancel()
        postConnectProbeTask = nil
        postConnectProbeTaskID = nil
    }

    private static let nodeUnreachableUserMessage =
        "This node isn’t responding. Try another node."

    private func presentDiagnostic(from trace: ConnectionDiagnosticTrace) async {
        suppressProviderConnectingPresentation = true
        let result = await recordDiagnostic(from: trace)
        connectionState = .idle
        clearConnectedNodeState()
        let evidenceCode = result.evidence.last(where: {
            $0.checkStatus == .failed
        })?.errorCode ?? result.stableErrorCode
        let isNodeUnreachable = evidenceCode == "probe.node_unreachable"
            || evidenceCode == "probe.core_url_test_failed"
            || evidenceCode == "probe.core_url_test_unavailable"
            || evidenceCode == "probe.tunnel_http_failed"
            || evidenceCode == "probe.tunnel_http_invalid_response"
            || evidenceCode == "probe.tunnel_http_body_mismatch"
            || evidenceCode == "probe.tunnel_http_response_too_large"
            || evidenceCode == "probe.tunnel_probe_address_unavailable"
            || evidenceCode.hasPrefix("probe.core_proxy_")
        #if DEBUG
        if isNodeUnreachable {
            var message = "\(Self.nodeUnreachableUserMessage) [\(evidenceCode)]"
            if let probeCounterSummary {
                message += " {\(probeCounterSummary)}"
            }
            connectionFailureMessage = message
        } else {
            var message = "Couldn’t connect. Try again. [\(evidenceCode)]"
            if let probeCounterSummary {
                message += " {\(probeCounterSummary)}"
            }
            connectionFailureMessage = message
        }
        #else
        connectionFailureMessage = isNodeUnreachable
            ? Self.nodeUnreachableUserMessage
            : "Couldn’t connect. Try again."
        #endif
    }

    /// TCP open to the selected node's host:port before tunnel start.
    private func verifySelectedNodeReachable(trace: ConnectionDiagnosticTrace) async throws {
        guard let database else { return }
        guard availableNodes.indices.contains(selectedNodeIndex) else {
            await trace.record(.init(
                layer: .probe,
                status: .failed,
                errorCode: "probe.node_unreachable"
            ))
            throw RoutevaAppDataError.nodeUnavailable
        }
        let nodeID = availableNodes[selectedNodeIndex].id
        guard let record = try? await database.node(id: nodeID) else {
            await trace.record(.init(
                layer: .probe,
                status: .failed,
                errorCode: "probe.node_unreachable"
            ))
            throw RoutevaAppDataError.nodeUnavailable
        }
        // UDP transports cannot be validated with a TCP open.
        if record.protocolKind == .hysteria2 {
            await trace.record(.init(layer: .probe, status: .passed, errorCode: "probe.node_udp_skipped"))
            return
        }
        let latency = await NodeLatencyProbe.measure(
            host: record.endpointHost,
            port: record.endpointPort,
            timeout: 2.5
        )
        if case let .measured(milliseconds) = latency {
            nodeLatencies[record.id] = .measured(milliseconds)
            await trace.record(.init(layer: .probe, status: .passed))
            return
        }
        nodeLatencies[record.id] = .unavailable
        await trace.record(.init(
            layer: .probe,
            status: .failed,
            errorCode: "probe.node_unreachable"
        ))
        #if DEBUG
        print(
            "Routeva VPN pre-connect node probe failed: "
                + "\(record.endpointHost):\(record.endpointPort)"
        )
        #endif
        throw RoutevaAppDataError.nodeUnavailable
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
            var pollingIteration = 0
            #if DEBUG
            var lastDataPlaneSummary: String?
            #endif
            while !Task.isCancelled {
                guard let core = connectedCore else { break }
                do {
                    let snapshot = try await providerController.queryTraffic(core: core)
                    guard !Task.isCancelled, trafficTaskID == taskID else { break }
                    // Provider counters are cumulative for this tunnel session.
                    sessionUploadedBytes = snapshot.uploadedBytes
                    sessionDownloadedBytes = snapshot.downloadedBytes
                } catch {
                    guard !Task.isCancelled, trafficTaskID == taskID else { break }
                    if !(await providerController.isConnectionActive(core: core)) {
                        await connectionCoordinator.reconcile(.disconnected)
                        connectedCore = nil
                        clearConnectedNodeState()
                        connectionState = .idle
                        sessionDownloadedBytes = 0
                        sessionUploadedBytes = 0
                        #if DEBUG
                        connectionFailureMessage =
                            "VPN stopped unexpectedly. Try again. [provider.session_ended]"
                        #else
                        connectionFailureMessage = "VPN stopped unexpectedly. Try again."
                        #endif
                        break
                    }
                }
                // Provider IPC is globally limited to one request per 200 ms.
                // Sample the existing privacy-safe data-plane snapshot only
                // every third traffic tick. DNS health is observational: an
                // established system tunnel is never stopped by this sampler.
                pollingIteration += 1
                if pollingIteration.isMultiple(of: 3) {
                    try? await Task.sleep(for: .milliseconds(250))
                    guard !Task.isCancelled else { break }
                    if let snapshot = try? await providerController.queryDataPlane(core: core) {
                        let dnsWarningCode = dnsHealthMonitor.observe(snapshot)
                        #if DEBUG
                        let summary = snapshot.probeCounterSummary
                        if summary != lastDataPlaneSummary {
                            print("Routeva VPN live data-plane: [\(summary)]")
                            lastDataPlaneSummary = summary
                        }
                        if let dnsWarningCode {
                            print(
                                "Routeva VPN live DNS warning: \(dnsWarningCode); "
                                    + "keeping connected session"
                            )
                        }
                        #endif
                    }
                }
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    private func stopTrafficPolling() {
        trafficTask?.cancel()
        trafficTask = nil
        trafficTaskID = nil
        sessionDownloadedBytes = 0
        sessionUploadedBytes = 0
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

private final class StartupNodeSelectionBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storedNodeID: UUID?

    var nodeID: UUID? { lock.withLock { storedNodeID } }

    func store(_ value: UUID) {
        lock.withLock { storedNodeID = value }
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

    /// Home 与 Settings 共用的用户可选闭集。Direct 仅作运行时遗留态，不再出现在选择器里。
    static let userSelectable: [RoutingMode] = [.automatic, .global]

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
        case .automatic: "Resolve by how traffic is routed"
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

private enum NonFailoverConnectionError: Error {
    case providerUnavailable
}

private enum ConnectionAttemptOutcomeError: Error {
    case timedOut
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
