import Foundation
import GRDB
import SharedKit

public actor RoutevaDatabase {
    public static let appGroupIdentifier = "group.com.yilinglabs.routeva"
    public static let databaseFilename = "Routeva.sqlite"

    private let pool: DatabasePool
    public nonisolated let databaseURL: URL

    public init(databaseURL: URL) throws {
        self.databaseURL = databaseURL
        var configuration = Configuration()
        configuration.label = "RoutevaDatabase"
        configuration.maximumReaderCount = 4
        configuration.prepareDatabase { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")
            try db.execute(sql: "PRAGMA busy_timeout = 5000")
        }
        pool = try DatabasePool(path: databaseURL.path, configuration: configuration)
        try DatabaseMigrations.migrator.migrate(pool)
        try Self.applyFileProtection(at: databaseURL)
    }

    public static func openAppGroupDatabase(fileManager: FileManager = .default) throws -> RoutevaDatabase {
        guard let container = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            throw RoutevaDatabaseError.appGroupUnavailable
        }
        let directory = container.appendingPathComponent("Database", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return try RoutevaDatabase(databaseURL: directory.appendingPathComponent(databaseFilename))
    }

    public func replaceSubscriptionAtomically(
        _ candidate: SubscriptionCandidate,
        makeActive: Bool
    ) throws {
        try pool.write { db in
            var subscription = candidate.subscription
            if makeActive {
                try db.execute(sql: "UPDATE subscriptions SET isActive = 0 WHERE isActive = 1")
                subscription.isActive = true
            }
            try subscription.save(db)
            try db.execute(
                sql: "DELETE FROM nodes WHERE subscriptionID = ?",
                arguments: [subscription.id]
            )
            for node in candidate.nodes {
                guard node.subscriptionID == subscription.id else {
                    throw RoutevaDatabaseError.nodeSubscriptionMismatch
                }
                try node.insert(db)
            }
        }
    }

    public func subscriptions() throws -> [SubscriptionRecord] {
        try pool.read { db in
            try SubscriptionRecord
                .order(Column("isActive").desc, Column("updatedAt").desc)
                .fetchAll(db)
        }
    }

    public func subscription(id: UUID) throws -> SubscriptionRecord? {
        try pool.read { db in
            try SubscriptionRecord.fetchOne(db, key: id)
        }
    }

    public func nodes(subscriptionID: UUID) throws -> [NodeRecord] {
        try pool.read { db in
            try NodeRecord
                .filter(Column("subscriptionID") == subscriptionID)
                .order(Column("sortIndex"))
                .fetchAll(db)
        }
    }

    public func node(id: UUID) throws -> NodeRecord? {
        try pool.read { db in
            try NodeRecord.fetchOne(db, key: id)
        }
    }

    public func setActiveSubscription(_ id: UUID) throws {
        try pool.write { db in
            guard try SubscriptionRecord.fetchOne(db, key: id) != nil else {
                throw RoutevaDatabaseError.subscriptionNotFound
            }
            try db.execute(sql: "UPDATE subscriptions SET isActive = 0 WHERE isActive = 1")
            try db.execute(sql: "UPDATE subscriptions SET isActive = 1, updatedAt = ? WHERE id = ?", arguments: [Date(), id])
        }
    }

    public func setPreferredNode(subscriptionID: UUID, nodeID: UUID) throws {
        try pool.write { db in
            guard let node = try NodeRecord.fetchOne(db, key: nodeID),
                  node.subscriptionID == subscriptionID else {
                throw RoutevaDatabaseError.nodeSubscriptionMismatch
            }
            try db.execute(
                sql: "UPDATE subscriptions SET preferredNodeID = ?, updatedAt = ? WHERE id = ?",
                arguments: [nodeID, Date(), subscriptionID]
            )
        }
    }

    public func renameSubscription(id: UUID, displayName: String) throws {
        let value = String(displayName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
        guard !value.isEmpty else { throw RoutevaDatabaseError.invalidDisplayName }
        try pool.write { db in
            guard try SubscriptionRecord.fetchOne(db, key: id) != nil else {
                throw RoutevaDatabaseError.subscriptionNotFound
            }
            try db.execute(
                sql: "UPDATE subscriptions SET displayName = ?, updatedAt = ? WHERE id = ?",
                arguments: [value, Date(), id]
            )
        }
    }

    /// Removes the subscription and its cascading node records. If the removed
    /// subscription was active, promote the most recently updated remaining
    /// subscription so the app always has one clear configuration to use.
    public func deleteSubscription(id: UUID) throws {
        try pool.write { db in
            guard let subscription = try SubscriptionRecord.fetchOne(db, key: id) else {
                throw RoutevaDatabaseError.subscriptionNotFound
            }

            try db.execute(sql: "DELETE FROM subscriptions WHERE id = ?", arguments: [id])

            guard subscription.isActive,
                  let replacement = try SubscriptionRecord
                    .order(Column("updatedAt").desc, Column("createdAt").desc)
                    .fetchOne(db)
            else { return }

            try db.execute(
                sql: "UPDATE subscriptions SET isActive = 1, updatedAt = ? WHERE id = ?",
                arguments: [Date(), replacement.id]
            )
        }
    }

    public func saveRuntimeManifest(_ record: RuntimeManifestRecord) throws {
        try pool.write { db in
            try db.execute(sql: "UPDATE runtimeManifests SET isCurrent = 0 WHERE isCurrent = 1")
            var current = record
            current.isCurrent = true
            try current.save(db)
        }
    }

    public func currentRuntimeManifest() throws -> RuntimeManifestRecord? {
        try pool.read { db in
            try RuntimeManifestRecord.filter(Column("isCurrent") == true).fetchOne(db)
        }
    }

    public func runtimeManifest(id: UUID) throws -> RuntimeManifestRecord? {
        try pool.read { db in
            try RuntimeManifestRecord.fetchOne(db, key: id)
        }
    }

    public func saveSnapshot(_ snapshot: ConfigSnapshotRecord, now: Date = .now) throws {
        try pool.write { db in
            try snapshot.insert(db)
            let cutoff = Calendar(identifier: .gregorian).date(byAdding: .day, value: -7, to: now) ?? now
            try db.execute(sql: "DELETE FROM configSnapshots WHERE createdAt < ?", arguments: [cutoff])
            try db.execute(sql: "DELETE FROM configSnapshots WHERE id NOT IN (SELECT id FROM configSnapshots ORDER BY createdAt DESC LIMIT 10)")
        }
    }

    public func snapshots() throws -> [ConfigSnapshotRecord] {
        try pool.read { db in
            try ConfigSnapshotRecord.order(Column("createdAt").desc).fetchAll(db)
        }
    }

    public func restoreSnapshot(id: UUID) throws -> RuntimeManifestRecord {
        try pool.write { db in
            guard let snapshot = try ConfigSnapshotRecord.fetchOne(db, key: id) else {
                throw RoutevaDatabaseError.snapshotNotFound
            }
            let manifest = try JSONDecoder().decode(RuntimeManifest.self, from: snapshot.manifestData)
            guard manifest.manifestID == snapshot.manifestID,
                  manifest.schemaVersion <= RuntimeManifest.currentSchemaVersion else {
                throw RoutevaDatabaseError.invalidSnapshot
            }
            try db.execute(sql: "UPDATE runtimeManifests SET isCurrent = 0 WHERE isCurrent = 1")
            let record = RuntimeManifestRecord(
                id: manifest.manifestID,
                schemaVersion: manifest.schemaVersion,
                createdAt: manifest.createdAt,
                manifestData: snapshot.manifestData,
                isCurrent: true
            )
            try record.save(db)
            return record
        }
    }

    public func upsertOverride(_ record: DomainOverrideRecord) throws {
        try pool.write { db in try record.save(db) }
    }

    public func overridesIncludingTombstones() throws -> [DomainOverrideRecord] {
        try pool.read { db in
            try DomainOverrideRecord.order(Column("updatedAt").desc).fetchAll(db)
        }
    }

    public func appendActivity(_ record: ActivityRecord) throws {
        try pool.write { db in try record.insert(db) }
    }

    public func latestActivity() throws -> ActivityRecord? {
        try pool.read { db in
            try ActivityRecord
                .order(Column("createdAt").desc)
                .fetchOne(db)
        }
    }

    private static func applyFileProtection(at databaseURL: URL) throws {
        #if os(iOS)
        for suffix in ["", "-wal", "-shm"] {
            let url = URL(fileURLWithPath: databaseURL.path + suffix)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: url.path
            )
        }
        #endif
    }
}

public enum RoutevaDatabaseError: Error, Equatable {
    case appGroupUnavailable
    case nodeSubscriptionMismatch
    case subscriptionNotFound
    case snapshotNotFound
    case invalidSnapshot
    case invalidDisplayName
}
