import Foundation
import SharedKit

public enum TunnelLifecycleState: Equatable, Sendable {
    case idle
    case selecting
    case validating(CoreIdentifier)
    case starting(CoreIdentifier)
    case probing(CoreIdentifier)
    case connected(CoreIdentifier, sessionID: UUID)
    case stopping(CoreIdentifier)
    case failed(code: String)
}

public struct CoreStartResult: Equatable, Sendable {
    public let core: CoreIdentifier
    public let sessionID: UUID
    public let attemptedCores: [CoreIdentifier]

    public init(core: CoreIdentifier, sessionID: UUID, attemptedCores: [CoreIdentifier]) {
        self.core = core
        self.sessionID = sessionID
        self.attemptedCores = attemptedCores
    }
}

public enum CoreCoordinatorError: Error, Equatable, Sendable {
    case startAlreadyInProgress
    case allCandidatesFailed([CoreIdentifier])
}

public actor CoreRuntimeCoordinator {
    public typealias ConfigurationProvider = @Sendable (CoreIdentifier) async throws -> SensitiveRuntimeConfig
    public typealias Probe = @Sendable (CoreIdentifier) async throws -> Void

    private let registry: CoreRegistry
    private let selector: CoreSelector
    private var health: [CoreIdentifier: CoreHealth]
    public private(set) var state: TunnelLifecycleState = .idle

    public init(
        registry: CoreRegistry,
        selector: CoreSelector = CoreSelector(),
        initialHealth: [CoreIdentifier: CoreHealth] = [:]
    ) {
        self.registry = registry
        self.selector = selector
        self.health = initialHealth
    }

    public func start(
        manifest: RuntimeManifest,
        configuration: ConfigurationProvider,
        probe: Probe
    ) async throws -> CoreStartResult {
        guard state == .idle || isTerminalFailure(state) else {
            throw CoreCoordinatorError.startAlreadyInProgress
        }

        state = .selecting
        await mergeAvailability()
        var attempted: [CoreIdentifier] = []

        while attempted.count < CoreIdentifier.allCases.count {
            let decision: CoreSelectionDecision
            do {
                decision = try selector.select(
                    manifest: manifest,
                    health: health,
                    excluding: Set(attempted)
                )
            } catch {
                state = .failed(code: "core.selection.unavailable")
                throw attempted.isEmpty ? error : CoreCoordinatorError.allCandidatesFailed(attempted)
            }

            let identifier = decision.selected
            attempted.append(identifier)
            guard let adapter = await registry.adapter(for: identifier) else {
                recordFailure(identifier)
                continue
            }

            do {
                let config = try await configuration(identifier)
                state = .validating(identifier)
                try await adapter.validate(config)
                state = .starting(identifier)
                try await adapter.start(config)
                state = .probing(identifier)
                try await probe(identifier)

                let sessionID = UUID()
                recordSuccess(identifier)
                state = .connected(identifier, sessionID: sessionID)
                return CoreStartResult(core: identifier, sessionID: sessionID, attemptedCores: attempted)
            } catch {
                await adapter.stop()
                recordFailure(identifier)
                if manifest.corePolicy != .automatic {
                    state = .failed(code: "core.start.pinned_failed")
                    throw error
                }
                state = .selecting
            }
        }

        state = .failed(code: "core.start.all_failed")
        throw CoreCoordinatorError.allCandidatesFailed(attempted)
    }

    public func stop() async {
        guard case let .connected(identifier, _) = state,
              let adapter = await registry.adapter(for: identifier)
        else {
            state = .idle
            return
        }

        state = .stopping(identifier)
        await adapter.stop()
        state = .idle
    }

    private func mergeAvailability() async {
        let availability = await registry.availability()
        for identifier in CoreIdentifier.allCases {
            let existing = health[identifier]
            health[identifier] = CoreHealth(
                isAvailable: availability[identifier]?.isAvailable == true,
                consecutiveFailures: existing?.consecutiveFailures ?? 0,
                lastSuccessfulConnection: existing?.lastSuccessfulConnection
            )
        }
    }

    private func recordFailure(_ identifier: CoreIdentifier) {
        let current = health[identifier]
        health[identifier] = CoreHealth(
            isAvailable: current?.isAvailable ?? false,
            consecutiveFailures: (current?.consecutiveFailures ?? 0) + 1,
            lastSuccessfulConnection: current?.lastSuccessfulConnection
        )
    }

    private func recordSuccess(_ identifier: CoreIdentifier) {
        health[identifier] = CoreHealth(
            isAvailable: true,
            consecutiveFailures: 0,
            lastSuccessfulConnection: Date()
        )
    }

    private func isTerminalFailure(_ state: TunnelLifecycleState) -> Bool {
        if case .failed = state { true } else { false }
    }
}
