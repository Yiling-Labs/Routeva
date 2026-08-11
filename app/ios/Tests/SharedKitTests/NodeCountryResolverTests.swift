import Foundation
import SharedKit
import XCTest

final class NodeCountryResolverTests: XCTestCase {
    func testUsesProviderFlagBeforeOtherHints() throws {
        let result = try XCTUnwrap(NodeCountryResolver.resolve(
            displayName: "🇯🇵 Free Japan 1",
            storedCountryCode: "US"
        ))

        XCTAssertEqual(result.countryCode, "JP")
        XCTAssertEqual(result.flag, "🇯🇵")
    }

    func testRemovesOnlyLeadingProviderFlagFromDisplayName() {
        XCTAssertEqual(
            NodeCountryResolver.removingLeadingFlag(from: "🇭🇰 香港 Z02 | IEPL"),
            "香港 Z02 | IEPL"
        )
        XCTAssertEqual(
            NodeCountryResolver.removingLeadingFlag(from: "Hong Kong 🇭🇰 Z02"),
            "Hong Kong 🇭🇰 Z02"
        )
    }

    func testInfersCountryFromLocalizedNameAndISOToken() {
        XCTAssertEqual(
            NodeCountryResolver.resolve(displayName: "免费-日本 1")?.countryCode,
            "JP"
        )
        XCTAssertEqual(
            NodeCountryResolver.resolve(displayName: "Premium-HK-02")?.flag,
            "🇭🇰"
        )
    }

    func testDoesNotRewriteTaiwanCountryCode() {
        XCTAssertEqual(NodeCountryResolver.flag(for: "TW"), "🇹🇼")
    }

    func testUnknownNodeHasNoCountryPresentation() {
        XCTAssertNil(NodeCountryResolver.resolve(displayName: "Synthetic edge 7"))
    }
}
