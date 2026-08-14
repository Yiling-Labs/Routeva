import DataKit
import Foundation
import SharedKit
import XCTest

final class RoutevaDatabaseTests: XCTestCase {
    private var temporaryDirectory: URL!
    private var database: RoutevaDatabase!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RoutevaDatabaseTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        database = try RoutevaDatabase(databaseURL: temporaryDirectory.appendingPathComponent("test.sqlite"))
    }

    override func tearDownWithError() throws {
        database = nil
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }

    func testFirstSavedSubscriptionCanBecomeActive() async throws {
        let candidate = makeCandidate(name: "Synthetic One")

        try await database.replaceSubscriptionAtomically(candidate, makeActive: true)

        let subscriptions = try await database.subscriptions()
        XCTAssertEqual(subscriptions.count, 1)
        XCTAssertTrue(subscriptions[0].isActive)
        let nodes = try await database.nodes(subscriptionID: candidate.subscription.id)
        XCTAssertEqual(nodes.count, 1)
        XCTAssertEqual(nodes[0].displayName, "TEST-01")
    }

    func testMismatchedNodeRollsBackSubscriptionReplacement() async throws {
        let existing = makeCandidate(name: "Existing")
        try await database.replaceSubscriptionAtomically(existing, makeActive: true)

        var invalid = makeCandidate(name: "Invalid")
        invalid.nodes[0] = makeNode(subscriptionID: UUID())

        do {
            try await database.replaceSubscriptionAtomically(invalid, makeActive: false)
            XCTFail("Expected mismatch")
        } catch {
            XCTAssertEqual(error as? RoutevaDatabaseError, .nodeSubscriptionMismatch)
        }

        let subscriptions = try await database.subscriptions()
        XCTAssertEqual(subscriptions.map(\.displayName), ["Existing"])
    }

    func testOnlyOneSubscriptionIsActive() async throws {
        let first = makeCandidate(name: "First")
        let second = makeCandidate(name: "Second")
        try await database.replaceSubscriptionAtomically(first, makeActive: true)
        try await database.replaceSubscriptionAtomically(second, makeActive: true)

        let subscriptions = try await database.subscriptions()
        XCTAssertEqual(subscriptions.filter(\.isActive).map(\.displayName), ["Second"])
    }

    func testSubscriptionCatalogSnapshotCountsAllNodesAndLoadsOnlyActiveNodes() async throws {
        let first = makeCandidate(name: "First")
        var second = makeCandidate(name: "Second")
        second.nodes.append(makeNode(subscriptionID: second.subscription.id, sortIndex: 1))
        try await database.replaceSubscriptionAtomically(first, makeActive: true)
        try await database.replaceSubscriptionAtomically(second, makeActive: false)

        let snapshot = try await database.subscriptionCatalogSnapshot()

        XCTAssertEqual(snapshot.nodeCounts[first.subscription.id], 1)
        XCTAssertEqual(snapshot.nodeCounts[second.subscription.id], 2)
        XCTAssertEqual(snapshot.activeNodes.map(\.subscriptionID), [first.subscription.id])
    }

    func testDeletingActiveSubscriptionCascadesNodesAndPromotesRemainingSubscription() async throws {
        let first = makeCandidate(name: "First")
        let second = makeCandidate(name: "Second")
        try await database.replaceSubscriptionAtomically(first, makeActive: true)
        try await database.replaceSubscriptionAtomically(second, makeActive: false)

        try await database.deleteSubscription(id: first.subscription.id)

        let subscriptions = try await database.subscriptions()
        let deletedNodes = try await database.nodes(subscriptionID: first.subscription.id)
        let remainingNodes = try await database.nodes(subscriptionID: second.subscription.id)
        XCTAssertEqual(subscriptions.map(\.id), [second.subscription.id])
        XCTAssertTrue(subscriptions[0].isActive)
        XCTAssertTrue(deletedNodes.isEmpty)
        XCTAssertEqual(remainingNodes.count, 1)
    }

    func testDeletingUnknownSubscriptionFailsWithoutChangingRecords() async throws {
        let candidate = makeCandidate(name: "Existing")
        try await database.replaceSubscriptionAtomically(candidate, makeActive: true)

        do {
            try await database.deleteSubscription(id: UUID())
            XCTFail("Expected subscriptionNotFound")
        } catch {
            XCTAssertEqual(error as? RoutevaDatabaseError, .subscriptionNotFound)
        }

        let subscriptions = try await database.subscriptions()
        XCTAssertEqual(subscriptions.map(\.id), [candidate.subscription.id])
    }

    func testSnapshotRetentionKeepsAtMostTenAndSevenDays() async throws {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        for offset in 0..<12 {
            let snapshot = ConfigSnapshotRecord(
                id: UUID(),
                createdAt: now.addingTimeInterval(TimeInterval(-offset * 3600)),
                manifestID: UUID(),
                manifestData: Data("{}".utf8),
                reasonCode: "synthetic"
            )
            try await database.saveSnapshot(snapshot, now: now)
        }
        let old = ConfigSnapshotRecord(
            id: UUID(),
            createdAt: now.addingTimeInterval(-8 * 86_400),
            manifestID: UUID(),
            manifestData: Data("{}".utf8),
            reasonCode: "old"
        )
        try await database.saveSnapshot(old, now: now)

        let snapshots = try await database.snapshots()
        XCTAssertLessThanOrEqual(snapshots.count, 10)
        XCTAssertFalse(snapshots.contains { $0.reasonCode == "old" })
    }

    func testRestoreSnapshotAtomicallyMakesItsManifestCurrent() async throws {
        let manifest = RuntimeManifest(
            manifestID: UUID(),
            corePolicy: .automatic,
            profile: RuntimeProfile(
                id: UUID(),
                protocolKind: .trojan,
                transport: .tcp,
                security: .tls,
                requiresUDP: true,
                credential: SecretReference(keychainIdentifier: "synthetic.snapshot")
            )
        )
        let data = try JSONEncoder().encode(manifest)
        let snapshot = ConfigSnapshotRecord(
            id: UUID(),
            manifestID: manifest.manifestID,
            manifestData: data,
            reasonCode: "repair.before"
        )
        try await database.saveSnapshot(snapshot)
        let restored = try await database.restoreSnapshot(id: snapshot.id)
        XCTAssertEqual(restored.id, manifest.manifestID)
        XCTAssertTrue(restored.isCurrent)
        let current = try await database.currentRuntimeManifest()
        XCTAssertEqual(current?.manifestData, data)
    }

    func testInvalidSnapshotCannotReplaceCurrentManifest() async throws {
        let currentManifest = RuntimeManifest(
            corePolicy: .automatic,
            profile: RuntimeProfile(
                id: UUID(), protocolKind: .shadowsocks, transport: .tcp,
                security: .none, requiresUDP: true,
                credential: SecretReference(keychainIdentifier: "synthetic.current")
            )
        )
        let current = RuntimeManifestRecord(
            id: currentManifest.manifestID,
            schemaVersion: currentManifest.schemaVersion,
            manifestData: try JSONEncoder().encode(currentManifest),
            isCurrent: true
        )
        try await database.saveRuntimeManifest(current)
        let invalid = ConfigSnapshotRecord(
            id: UUID(), manifestID: UUID(), manifestData: Data("not-json".utf8),
            reasonCode: "repair.invalid"
        )
        try await database.saveSnapshot(invalid)
        do {
            _ = try await database.restoreSnapshot(id: invalid.id)
            XCTFail("Expected invalid snapshot")
        } catch {
            // Decoding fails before the current manifest is touched.
        }
        let stillCurrent = try await database.currentRuntimeManifest()
        XCTAssertEqual(stillCurrent?.id, current.id)
    }

    func testLatestActivityReturnsNewestRedactedDiagnostic() async throws {
        let older = ActivityRecord(
            id: UUID(),
            createdAt: Date(timeIntervalSince1970: 100),
            eventCode: "probe.older",
            failureBucket: "transport",
            redactedSummary: "probe:failed:probe.older"
        )
        let newer = ActivityRecord(
            id: UUID(),
            createdAt: Date(timeIntervalSince1970: 200),
            eventCode: "probe.newer",
            failureBucket: "transport",
            redactedSummary: "probe:failed:probe.newer"
        )
        try await database.appendActivity(newer)
        try await database.appendActivity(older)

        let latest = try await database.latestActivity()
        XCTAssertEqual(latest, newer)
    }

    private func makeCandidate(name: String) -> SubscriptionCandidate {
        let id = UUID()
        return SubscriptionCandidate(
            subscription: SubscriptionRecord(
                id: id,
                displayName: name,
                sourceKind: "synthetic",
                sourceSecretReference: "synthetic-source-\(id.uuidString)",
                isActive: false
            ),
            nodes: [makeNode(subscriptionID: id)]
        )
    }

    private func makeNode(subscriptionID: UUID, sortIndex: Int = 0) -> NodeRecord {
        NodeRecord(
            id: UUID(),
            subscriptionID: subscriptionID,
            sortIndex: sortIndex,
            displayName: "TEST-01",
            countryCode: "ZZ",
            countryName: "Synthetic",
            protocolKind: .vless,
            transport: .tcp,
            security: .tls,
            requiresUDP: false,
            endpointHost: "example.invalid",
            endpointPort: 443,
            credentialReference: "synthetic-credential"
        )
    }
}
