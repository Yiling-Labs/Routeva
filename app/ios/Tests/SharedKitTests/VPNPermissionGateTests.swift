import SharedKit
import XCTest

final class VPNPermissionGateTests: XCTestCase {
    func testStartsOnlyWhenEnabledAndForeground() {
        XCTAssertEqual(
            VPNPermissionGate.decision(isEnabled: true, sceneIsActive: true),
            .startTunnel
        )
        XCTAssertEqual(
            VPNPermissionGate.decision(isEnabled: true, sceneIsActive: false),
            .waitForForeground
        )
        XCTAssertEqual(
            VPNPermissionGate.decision(isEnabled: false, sceneIsActive: false),
            .waitForForeground
        )
        XCTAssertEqual(
            VPNPermissionGate.decision(isEnabled: false, sceneIsActive: true),
            .failNotPersisted
        )
    }

    func testAbandonsConnectingWhenForegroundFindsNoEnabledConfiguration() {
        XCTAssertTrue(
            VPNPermissionGate.shouldAbandonConnectingOnForeground(
                isConnecting: true,
                hasInFlightConnection: true,
                hasEnabledConfiguration: false
            )
        )
        XCTAssertFalse(
            VPNPermissionGate.shouldAbandonConnectingOnForeground(
                isConnecting: true,
                hasInFlightConnection: true,
                hasEnabledConfiguration: true
            )
        )
        XCTAssertFalse(
            VPNPermissionGate.shouldAbandonConnectingOnForeground(
                isConnecting: false,
                hasInFlightConnection: true,
                hasEnabledConfiguration: false
            )
        )
    }

    func testAbandonableTimeoutDoesNotWaitForHungOperation() async throws {
        let started = ContinuousClock.now
        do {
            _ = try await AbandonableAsync.firstFinished(
                timeout: .milliseconds(80),
                operation: {
                    try await Task.sleep(for: .seconds(30))
                    return "late"
                },
                timeoutError: { TimeoutError() }
            )
            XCTFail("Hung operation should not win")
        } catch is TimeoutError {
            let elapsed = ContinuousClock.now - started
            XCTAssertLessThan(elapsed, .seconds(1))
        }
    }
}

private struct TimeoutError: Error {}
