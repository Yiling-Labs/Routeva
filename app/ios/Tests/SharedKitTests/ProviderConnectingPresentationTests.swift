import SharedKit
import XCTest

final class ProviderConnectingPresentationTests: XCTestCase {
    func testOrphanedConnectingIsPresented() {
        XCTAssertEqual(
            ProviderConnectingPresentation.evaluate(appReleasedConnecting: false),
            .presentOrphaned
        )
    }

    func testReleasedConnectingStaysIdle() {
        XCTAssertEqual(
            ProviderConnectingPresentation.evaluate(appReleasedConnecting: true),
            .suppressAndReap
        )
    }
}
