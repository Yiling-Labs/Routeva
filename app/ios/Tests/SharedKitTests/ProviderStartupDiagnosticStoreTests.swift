import DataKit
import Foundation
import SharedKit
import XCTest

final class ProviderStartupDiagnosticStoreTests: XCTestCase {
    func testRoundTripsOnlyStableStartupEvidence() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = directory.appendingPathComponent(
            ProviderStartupDiagnosticStore.filename,
            isDirectory: false
        )
        let store = ProviderStartupDiagnosticStore(fileURL: fileURL)
        let timestamp = Date(timeIntervalSince1970: 1_786_000_000)

        store.record(
            core: .singBox,
            stage: .acquiringTunnelDescriptor,
            stableErrorCode: "provider.tun_descriptor_unavailable",
            now: timestamp
        )

        XCTAssertEqual(
            store.snapshot(),
            ProviderStartupDiagnosticSnapshot(
                core: .singBox,
                stage: .acquiringTunnelDescriptor,
                stableErrorCode: "provider.tun_descriptor_unavailable",
                updatedAt: timestamp
            )
        )
        let persistedText = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertFalse(persistedText.contains("password"))
        XCTAssertFalse(persistedText.contains("server"))

        store.clear()
        XCTAssertNil(store.snapshot())
    }

    func testRejectsOversizedDiagnosticFile() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try Data(repeating: 0x41, count: 2_049).write(to: fileURL)

        XCTAssertNil(ProviderStartupDiagnosticStore(fileURL: fileURL).snapshot())
    }
}
