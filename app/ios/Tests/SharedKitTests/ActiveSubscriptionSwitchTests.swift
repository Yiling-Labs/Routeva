import SharedKit
import XCTest

final class ActiveSubscriptionSwitchTests: XCTestCase {
    func testSameSubscriptionIsIgnored() {
        XCTAssertEqual(
            ActiveSubscriptionSwitch.evaluate(
                isAlreadyActive: true,
                isConnecting: false,
                isConnected: true
            ),
            .ignore
        )
        XCTAssertEqual(
            ActiveSubscriptionSwitch.evaluate(
                isAlreadyActive: true,
                isConnecting: true,
                isConnected: false
            ),
            .ignore
        )
    }

    func testConnectedStopsSessionBeforeApply() {
        XCTAssertEqual(
            ActiveSubscriptionSwitch.evaluate(
                isAlreadyActive: false,
                isConnecting: false,
                isConnected: true
            ),
            .stopConnected
        )
    }

    func testConnectingAbortsStartupBeforeApply() {
        XCTAssertEqual(
            ActiveSubscriptionSwitch.evaluate(
                isAlreadyActive: false,
                isConnecting: true,
                isConnected: false
            ),
            .abortConnecting
        )
    }

    func testIdleAppliesWithoutStopping() {
        XCTAssertEqual(
            ActiveSubscriptionSwitch.evaluate(
                isAlreadyActive: false,
                isConnecting: false,
                isConnected: false
            ),
            .apply
        )
    }
}
