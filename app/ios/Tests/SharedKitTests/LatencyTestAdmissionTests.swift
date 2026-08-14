import Network
import SharedKit
import XCTest

final class LatencyTestAdmissionTests: XCTestCase {
    func testIdleAllowsSilentAndUserTest() {
        XCTAssertEqual(
            LatencyTestAdmission.evaluate(
                userInitiated: false,
                isConnecting: false,
                isConnected: false
            ),
            .run
        )
        XCTAssertEqual(
            LatencyTestAdmission.evaluate(
                userInitiated: true,
                isConnecting: false,
                isConnected: false
            ),
            .run
        )
    }

    func testConnectedAllowsOnlyUserTest() {
        XCTAssertEqual(
            LatencyTestAdmission.evaluate(
                userInitiated: true,
                isConnecting: false,
                isConnected: true
            ),
            .run
        )
        XCTAssertEqual(
            LatencyTestAdmission.evaluate(
                userInitiated: false,
                isConnecting: false,
                isConnected: true
            ),
            .ignoreSilent
        )
    }

    func testConnectingRefusesEveryTrigger() {
        XCTAssertEqual(
            LatencyTestAdmission.evaluate(
                userInitiated: true,
                isConnecting: true,
                isConnected: false
            ),
            .refuseConnecting
        )
        XCTAssertEqual(
            LatencyTestAdmission.evaluate(
                userInitiated: false,
                isConnecting: true,
                isConnected: false
            ),
            .refuseConnecting
        )
    }

    func testPhysicalInterfacePrefersWifiAndSkipsTunnel() {
        let types = [
            (name: "utun3", type: NWInterface.InterfaceType.other),
            (name: "pdp_ip0", type: NWInterface.InterfaceType.cellular),
            (name: "en0", type: NWInterface.InterfaceType.wifi),
        ]
        XCTAssertEqual(
            PhysicalNetworkInterface.preferredType(from: types),
            .wifi
        )
        XCTAssertEqual(
            PhysicalNetworkInterface.preferredType(from: types, excludingName: "en0"),
            .cellular
        )
        XCTAssertNil(
            PhysicalNetworkInterface.preferredType(
                from: [(name: "utun3", type: .other)]
            )
        )
        XCTAssertTrue(PhysicalNetworkInterface.isPhysical(.wifi))
        XCTAssertFalse(PhysicalNetworkInterface.isPhysical(.other))
    }
}
