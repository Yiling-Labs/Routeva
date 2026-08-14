import SharedKit
import XCTest

final class NodeFailoverPlannerTests: XCTestCase {
    private let planner = NodeFailoverPlanner()

    func testSmartTriesCurrentThenHealthyCandidatesByDefault() {
        let result = planner.candidates(
            routingMode: .automatic,
            isPreferredPinned: false,
            currentIndex: 2,
            available: [
                .init(index: 0, healthScore: 90),
                .init(index: 1),
                .init(index: 2, healthScore: 200),
                .init(index: 3, healthScore: 40),
            ]
        )
        XCTAssertEqual(result, [2, 3, 0, 1])
    }

    func testSmartCapsAutomaticAttemptsForLargeCatalogs() {
        let nodes = (0..<10).map { NodeFailoverCandidate(index: $0) }
        XCTAssertEqual(
            planner.candidates(
                routingMode: .automatic,
                isPreferredPinned: false,
                currentIndex: 8,
                available: nodes
            ),
            [8, 0, 1, 2, 3, 4]
        )
    }

    func testSmartHonorsExplicitAttemptLimit() {
        let result = planner.candidates(
            routingMode: .automatic,
            isPreferredPinned: false,
            currentIndex: 2,
            available: [
                .init(index: 0, healthScore: 90),
                .init(index: 1),
                .init(index: 2, healthScore: 200),
                .init(index: 3, healthScore: 40),
            ],
            maximumAttempts: 3
        )
        XCTAssertEqual(result, [2, 3, 0])
    }

    func testPreferredSmartGlobalAndDirectNeverAutoSwitchNode() {
        let nodes = [NodeFailoverCandidate(index: 0), .init(index: 1, healthScore: 10)]
        XCTAssertEqual(planner.candidates(
            routingMode: .automatic,
            isPreferredPinned: true,
            currentIndex: 0,
            available: nodes
        ), [0])
        XCTAssertEqual(planner.candidates(
            routingMode: .global,
            isPreferredPinned: false,
            currentIndex: 0,
            available: nodes
        ), [0])
        XCTAssertEqual(planner.candidates(
            routingMode: .direct,
            isPreferredPinned: false,
            currentIndex: 0,
            available: nodes
        ), [0])
    }
}
