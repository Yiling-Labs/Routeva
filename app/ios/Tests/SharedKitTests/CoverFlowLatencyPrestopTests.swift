import SharedKit
import XCTest

final class CoverFlowLatencyPrestopTests: XCTestCase {
    func testKeepsGreenCurrentNodeEvenWhenAnotherIsFaster() {
        let current = UUID()
        let faster = UUID()
        XCTAssertEqual(
            CoverFlowLatencyPrestop.index(
                currentIndex: 0,
                nodeIDs: [current, faster],
                measuredMilliseconds: [current: 80, faster: 20]
            ),
            0
        )
    }

    func testMovesOffYellowCurrentToLowestMeasured() {
        let current = UUID()
        let lowest = UUID()
        let other = UUID()
        XCTAssertEqual(
            CoverFlowLatencyPrestop.index(
                currentIndex: 0,
                nodeIDs: [current, lowest, other],
                measuredMilliseconds: [current: 150, lowest: 40, other: 90]
            ),
            1
        )
    }

    func testUntestedCurrentMovesToLowestMeasured() {
        let current = UUID()
        let lowest = UUID()
        XCTAssertEqual(
            CoverFlowLatencyPrestop.index(
                currentIndex: 0,
                nodeIDs: [current, lowest],
                measuredMilliseconds: [lowest: 70]
            ),
            1
        )
    }

    func testKeepsCurrentWhenNothingWasMeasured() {
        let current = UUID()
        XCTAssertEqual(
            CoverFlowLatencyPrestop.index(
                currentIndex: 2,
                nodeIDs: [UUID(), UUID(), current],
                measuredMilliseconds: [:]
            ),
            2
        )
    }

    func testGoodTierMatchesCoverFlowGreenBadge() {
        XCTAssertTrue(NodeLatencyTier.isGood(99))
        XCTAssertFalse(NodeLatencyTier.isGood(100))
        XCTAssertFalse(NodeLatencyTier.isGood(201))
    }
}
