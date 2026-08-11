import Foundation
import SharedKit

public struct ProviderConnectionResult: Equatable, Sendable {
    public let core: CoreIdentifier
    public let sessionID: UUID
    public let attemptedCores: [CoreIdentifier]

    public init(core: CoreIdentifier, sessionID: UUID, attemptedCores: [CoreIdentifier]) {
        self.core = core
        self.sessionID = sessionID
        self.attemptedCores = attemptedCores
    }
}

public enum ProviderConnectionError: Error, Equatable, Sendable {
    case startAlreadyInProgress
    case failureBudgetExhausted
    case allCandidatesFailed([CoreIdentifier])
}

public actor ProviderConnectionCoordinator {
    public typealias StartProvider = @Sendable (CoreIdentifier, UUID) async throws -> Void
    public typealias StopProvider = @Sendable (CoreIdentifier) async -> Void
    public typealias Probe = @Sendable (CoreIdentifier) async throws -> Void
    public typealias StateObserver = @Sendable (TunnelLifecycleState) async -> Void

    private let selector: CoreSelector
    private let maximumAttempts: Int
    private let failureWindow: TimeInterval
    private let now: @Sendable () -> Date
    private var attemptDates: [Date] = []
    public private(set) var state: TunnelLifecycleState = .idle

    public init(
        selector: CoreSelector = CoreSelector(),
        maximumAttempts: Int = 3,
        failureWindow: TimeInterval = 15 * 60,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.selector = selector
        self.maximumAttempts = maximumAttempts
        self.failureWindow = failureWindow
        self.now = now
    }

    public func start(
        manifest: RuntimeManifest,
        health: [CoreIdentifier: CoreHealth],
        startProvider: StartProvider,
        stopProvider: StopProvider,
        probe: Probe,
        observe: StateObserver = { _ in }
    ) async throws -> ProviderConnectionResult {
        guard state == .idle || isFailure(state) else {
            throw ProviderConnectionError.startAlreadyInProgress
        }
        await transition(.selecting, observe: observe)
        var attempted: [CoreIdentifier] = []

        while attempted.count < CoreIdentifier.allCases.count {
            pruneAttemptBudget()
            guard attemptDates.count < maximumAttempts else {
                await transition(.failed(code: "provider.failure_budget_exhausted"), observe: observe)
                throw ProviderConnectionError.failureBudgetExhausted
            }

            let decision: CoreSelectionDecision
            do {
                decision = try selector.select(
                    manifest: manifest,
                    health: health,
                    excluding: Set(attempted)
                )
            } catch {
                await transition(.failed(code: "provider.selection_unavailable"), observe: observe)
                throw attempted.isEmpty ? error : ProviderConnectionError.allCandidatesFailed(attempted)
            }

            let core = decision.selected
            attempted.append(core)
            attemptDates.append(now())
            do {
                await transition(.starting(core), observe: observe)
                try await startProvider(core, manifest.manifestID)
                await transition(.probing(core), observe: observe)
                try await probe(core)
                let sessionID = UUID()
                // The budget limits repeated *failed* provider starts, not
                // ordinary reconnects after a successful node or mode change.
                // Keeping successful attempts here caused the next request to
                // be rejected after three healthy reconnects within the
                // window, before any provider work or diagnostic trace began.
                attemptDates.removeAll()
                await transition(.connected(core, sessionID: sessionID), observe: observe)
                return ProviderConnectionResult(core: core, sessionID: sessionID, attemptedCores: attempted)
            } catch {
                await stopProvider(core)
                guard manifest.corePolicy == .automatic else {
                    await transition(.failed(code: "provider.pinned_failed"), observe: observe)
                    throw error
                }
                await transition(.selecting, observe: observe)
            }
        }

        await transition(.failed(code: "provider.all_candidates_failed"), observe: observe)
        throw ProviderConnectionError.allCandidatesFailed(attempted)
    }

    public func stop(stopProvider: StopProvider, observe: StateObserver = { _ in }) async {
        guard case let .connected(core, _) = state else {
            await transition(.idle, observe: observe)
            return
        }
        await transition(.stopping(core), observe: observe)
        await stopProvider(core)
        await transition(.idle, observe: observe)
    }

    private func transition(_ next: TunnelLifecycleState, observe: StateObserver) async {
        state = next
        await observe(next)
    }

    private func pruneAttemptBudget() {
        let cutoff = now().addingTimeInterval(-failureWindow)
        attemptDates.removeAll(where: { $0 < cutoff })
    }

    private func isFailure(_ value: TunnelLifecycleState) -> Bool {
        if case .failed = value { true } else { false }
    }
}
