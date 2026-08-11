import Foundation
import SharedKit

public struct RepairCandidate: Equatable, Sendable {
    public let action: RepairAction
    public let verificationCode: String

    public init(action: RepairAction, verificationCode: String) {
        self.action = action
        self.verificationCode = verificationCode
    }
}

public struct RepairPlan: Equatable, Sendable {
    public static let maximumCandidates = 3
    public let candidates: [RepairCandidate]

    public init(candidates: [RepairCandidate]) {
        var seen: Set<RepairAction> = []
        self.candidates = candidates.filter { seen.insert($0.action).inserted }
            .prefix(Self.maximumCandidates)
            .map { $0 }
    }
}

public struct RepairExecutionResult: Equatable, Sendable {
    public let successfulAction: RepairAction
    public let attemptedActions: [RepairAction]

    public init(successfulAction: RepairAction, attemptedActions: [RepairAction]) {
        self.successfulAction = successfulAction
        self.attemptedActions = attemptedActions
    }
}

public enum RepairCoordinatorError: Error, Equatable, Sendable {
    case approvalRequired
    case actionNotAllowed(RepairAction)
    case noCandidates
    case verificationFailed([RepairAction])
}

public actor RepairCoordinator {
    public typealias MakeSnapshot = @Sendable () async throws -> UUID
    public typealias Apply = @Sendable (RepairAction) async throws -> Void
    public typealias Verify = @Sendable (String) async throws -> Bool
    public typealias Rollback = @Sendable (UUID) async -> Void

    public init() {}

    public func execute(
        diagnostic: DiagnosticResult,
        plan: RepairPlan,
        userApproved: Bool,
        makeSnapshot: MakeSnapshot,
        apply: Apply,
        verify: Verify,
        rollback: Rollback
    ) async throws -> RepairExecutionResult {
        if diagnostic.bucket == .clientFixable, !userApproved {
            throw RepairCoordinatorError.approvalRequired
        }
        guard !plan.candidates.isEmpty else { throw RepairCoordinatorError.noCandidates }
        for candidate in plan.candidates where !diagnostic.allowedActions.contains(candidate.action) {
            throw RepairCoordinatorError.actionNotAllowed(candidate.action)
        }

        let snapshotID = try await makeSnapshot()
        var attempted: [RepairAction] = []
        do {
            for candidate in plan.candidates {
                try Task.checkCancellation()
                attempted.append(candidate.action)
                do {
                    try await apply(candidate.action)
                    if try await verify(candidate.verificationCode) {
                        return RepairExecutionResult(
                            successfulAction: candidate.action,
                            attemptedActions: attempted
                        )
                    }
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    // The same snapshot is restored before the next bounded candidate.
                }
                await rollback(snapshotID)
            }
        } catch {
            await rollback(snapshotID)
            throw error
        }
        await rollback(snapshotID)
        throw RepairCoordinatorError.verificationFailed(attempted)
    }
}
