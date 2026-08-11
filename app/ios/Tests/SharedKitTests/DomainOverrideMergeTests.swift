import DataKit
import Foundation
import XCTest

final class DomainOverrideMergeTests: XCTestCase {
    private let merge = DomainOverrideMerge()

    func testNewerWholeRecordWins() {
        let old = record(
            domain: "example.com", action: "proxy", enabled: true,
            date: Date(timeIntervalSince1970: 100), deleted: false, device: "local"
        )
        let newerTombstone = record(
            domain: "example.com", action: "direct", enabled: false,
            date: Date(timeIntervalSince1970: 101), deleted: true, device: "remote"
        )
        XCTAssertEqual(merge.merge(local: [old], remote: [newerTombstone]), [newerTombstone])
    }

    func testEqualTimestampRetainsLocalWholeRecord() {
        let date = Date(timeIntervalSince1970: 100)
        let local = record(
            domain: "example.com", action: "proxy", enabled: true,
            date: date, deleted: false, device: "local"
        )
        let remote = record(
            domain: "example.com", action: "direct", enabled: false,
            date: date, deleted: true, device: "remote"
        )
        XCTAssertEqual(merge.merge(local: [local], remote: [remote]), [local])
    }

    func testIndependentDomainsArePreservedInStableOrder() {
        let local = record(domain: "z.example", device: "local")
        let remote = record(domain: "a.example", device: "remote")
        XCTAssertEqual(merge.merge(local: [local], remote: [remote]).map(\.domain), [
            "a.example", "z.example",
        ])
    }

    private func record(
        domain: String,
        action: String = "proxy",
        enabled: Bool = true,
        date: Date = Date(timeIntervalSince1970: 100),
        deleted: Bool = false,
        device: String
    ) -> DomainOverrideRecord {
        DomainOverrideRecord(
            domain: domain, action: action, isEnabled: enabled, updatedAt: date,
            isDeleted: deleted, deviceID: device
        )
    }
}
