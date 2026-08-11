import GRDB

enum DatabaseMigrations {
    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1-foundation") { db in
            try db.create(table: "subscriptions") { table in
                table.column("id", .text).primaryKey()
                table.column("displayName", .text).notNull()
                table.column("sourceKind", .text).notNull()
                table.column("sourceSecretReference", .text).notNull()
                table.column("isActive", .boolean).notNull().defaults(to: false)
                table.column("createdAt", .datetime).notNull()
                table.column("updatedAt", .datetime).notNull()
                table.column("lastRefreshAt", .datetime)
                table.column("expiresAt", .datetime)
                table.column("usedBytes", .integer)
                table.column("totalBytes", .integer)
            }
            try db.execute(sql: "CREATE UNIQUE INDEX subscriptions_single_active ON subscriptions(isActive) WHERE isActive = 1")

            try db.create(table: "nodes") { table in
                table.column("id", .text).primaryKey()
                table.column("subscriptionID", .text).notNull()
                    .references("subscriptions", column: "id", onDelete: .cascade)
                table.column("sortIndex", .integer).notNull()
                table.column("displayName", .text).notNull()
                table.column("countryCode", .text)
                table.column("countryName", .text)
                table.column("protocolKind", .text).notNull()
                table.column("transport", .text).notNull()
                table.column("security", .text).notNull()
                table.column("requiresUDP", .boolean).notNull()
                table.column("endpointHost", .text).notNull()
                table.column("endpointPort", .integer).notNull()
                table.column("credentialReference", .text).notNull()
                table.column("nonSecretOptionsJSON", .blob).notNull()
                table.uniqueKey(["subscriptionID", "sortIndex"])
            }
            try db.create(index: "nodes_subscription", on: "nodes", columns: ["subscriptionID"])

            try db.create(table: "activity") { table in
                table.column("id", .text).primaryKey()
                table.column("createdAt", .datetime).notNull().indexed()
                table.column("eventCode", .text).notNull()
                table.column("failureBucket", .text)
                table.column("redactedSummary", .text).notNull()
            }

            try db.create(table: "configSnapshots") { table in
                table.column("id", .text).primaryKey()
                table.column("createdAt", .datetime).notNull().indexed()
                table.column("manifestID", .text).notNull()
                table.column("manifestData", .blob).notNull()
                table.column("reasonCode", .text).notNull()
            }

            try db.create(table: "runtimeManifests") { table in
                table.column("id", .text).primaryKey()
                table.column("schemaVersion", .integer).notNull()
                table.column("createdAt", .datetime).notNull()
                table.column("manifestData", .blob).notNull()
                table.column("isCurrent", .boolean).notNull().defaults(to: false)
            }
            try db.execute(sql: "CREATE UNIQUE INDEX runtime_manifest_current ON runtimeManifests(isCurrent) WHERE isCurrent = 1")

            try db.create(table: "domainOverrides") { table in
                table.column("domain", .text).primaryKey()
                table.column("action", .text).notNull()
                table.column("isEnabled", .boolean).notNull()
                table.column("updatedAt", .datetime).notNull().indexed()
                table.column("isDeleted", .boolean).notNull().defaults(to: false)
                table.column("deviceID", .text).notNull()
            }
        }

        migrator.registerMigration("v2-provider-route-policy") { db in
            try db.alter(table: "subscriptions") { table in
                table.add(column: "routePolicyJSON", .blob)
            }
        }

        migrator.registerMigration("v3-preferred-node") { db in
            try db.alter(table: "subscriptions") { table in
                table.add(column: "preferredNodeID", .text)
            }
        }

        return migrator
    }
}
