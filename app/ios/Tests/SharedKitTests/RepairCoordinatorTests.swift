import CoreBridge
import Foundation
import SharedKit
import XCTest

final class RepairCoordinatorTests: XCTestCase {
    func testClientFixableRepairRequiresApproval() async {
        let coordinator = RepairCoordinator()
        let diagnostic = clientDiagnostic(actions: [.rebuildTunnel])
        do {
            _ = try await coordinator.execute(
                diagnostic: diagnostic,
                plan: RepairPlan(candidates: [RepairCandidate(
                    action: .rebuildTunnel,
                    verificationCode: "probe"
                )]),
                userApproved: false,
                makeSnapshot: { UUID() },
                apply: { _ in },
                verify: { _ in true },
                rollback: { _ in }
            )
            XCTFail("Expected approvalRequired")
        } catch {
            XCTAssertEqual(error as? RepairCoordinatorError, .approvalRequired)
        }
    }

    func testFailedCandidateRollsBackBeforeBoundedSuccessfulCandidate() async throws {
        let recorder = RepairRecorder()
        let coordinator = RepairCoordinator()
        let diagnostic = clientDiagnostic(actions: [
            .switchDNSPreset, .rebuildTunnel, .preferCompatibilityParameters,
        ])
        let result = try await coordinator.execute(
            diagnostic: diagnostic,
            plan: RepairPlan(candidates: [
                RepairCandidate(action: .switchDNSPreset, verificationCode: "dns"),
                RepairCandidate(action: .rebuildTunnel, verificationCode: "probe"),
                RepairCandidate(action: .preferCompatibilityParameters, verificationCode: "compatibility"),
                RepairCandidate(action: .refreshSubscription, verificationCode: "over-limit"),
            ]),
            userApproved: true,
            makeSnapshot: {
                await recorder.record("snapshot")
                return UUID()
            },
            apply: { action in await recorder.record("apply:\(action.rawValue)") },
            verify: { code in
                await recorder.record("verify:\(code)")
                return code == "probe"
            },
            rollback: { _ in await recorder.record("rollback") }
        )
        XCTAssertEqual(result.successfulAction, .rebuildTunnel)
        XCTAssertEqual(result.attemptedActions, [.switchDNSPreset, .rebuildTunnel])
        let events = await recorder.events
        XCTAssertEqual(events, [
            "snapshot",
            "apply:switch_dns_preset",
            "verify:dns",
            "rollback",
            "apply:rebuild_tunnel",
            "verify:probe",
        ])
    }

    func testDisallowedActionIsRejectedBeforeSnapshot() async {
        let recorder = RepairRecorder()
        let coordinator = RepairCoordinator()
        do {
            _ = try await coordinator.execute(
                diagnostic: clientDiagnostic(actions: [.rebuildTunnel]),
                plan: RepairPlan(candidates: [RepairCandidate(
                    action: .refreshSubscription,
                    verificationCode: "subscription"
                )]),
                userApproved: true,
                makeSnapshot: {
                    await recorder.record("snapshot")
                    return UUID()
                },
                apply: { _ in },
                verify: { _ in true },
                rollback: { _ in }
            )
            XCTFail("Expected actionNotAllowed")
        } catch {
            XCTAssertEqual(error as? RepairCoordinatorError, .actionNotAllowed(.refreshSubscription))
        }
        let events = await recorder.events
        XCTAssertTrue(events.isEmpty)
    }

    private func clientDiagnostic(actions: [RepairAction]) -> DiagnosticResult {
        DiagnosticResult(
            bucket: .clientFixable,
            stableErrorCode: "diagnostic.test",
            evidence: [],
            confidence: .high,
            allowedActions: actions
        )
    }
}

private actor RepairRecorder {
    private(set) var events: [String] = []
    func record(_ event: String) { events.append(event) }
}
