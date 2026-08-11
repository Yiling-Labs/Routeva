import CloudKit
import DataKit
import Foundation

actor CloudOverrideSyncService {
    private static let recordType = "DomainOverride"
    private let localDatabase: RoutevaDatabase
    private let cloudDatabase: CKDatabase
    private let mergeEngine = DomainOverrideMerge()

    init(
        localDatabase: RoutevaDatabase,
        container: CKContainer = CKContainer(identifier: "iCloud.com.yilinglabs.routeva")
    ) {
        self.localDatabase = localDatabase
        cloudDatabase = container.privateCloudDatabase
    }

    func merge() async throws {
        let local = try await localDatabase.overridesIncludingTombstones()
        let remoteCloudRecords = try await fetchAll()
        let remote = remoteCloudRecords.compactMap(Self.localRecord)
        let merged = mergeEngine.merge(local: local, remote: remote)
        for record in merged { try await localDatabase.upsertOverride(record) }
        let existingByDomain = Dictionary(
            remoteCloudRecords.compactMap { cloudRecord in
                (cloudRecord["domain"] as? String).map { ($0, cloudRecord) }
            },
            uniquingKeysWith: { lhs, _ in lhs }
        )
        let cloudRecords = merged.map { Self.cloudRecord($0, existing: existingByDomain[$0.domain]) }
        guard !cloudRecords.isEmpty else { return }
        _ = try await cloudDatabase.modifyRecords(saving: cloudRecords, deleting: [])
    }

    private func fetchAll() async throws -> [CKRecord] {
        var records: [CKRecord] = []
        var result = try await cloudDatabase.records(
            matching: CKQuery(recordType: Self.recordType, predicate: NSPredicate(value: true))
        )
        records.append(contentsOf: result.matchResults.compactMap { try? $0.1.get() })
        while let cursor = result.queryCursor {
            result = try await cloudDatabase.records(continuingMatchFrom: cursor)
            records.append(contentsOf: result.matchResults.compactMap { try? $0.1.get() })
        }
        return records
    }

    private static func cloudRecord(_ value: DomainOverrideRecord, existing: CKRecord?) -> CKRecord {
        let record = existing ?? CKRecord(
            recordType: recordType,
            recordID: CKRecord.ID(recordName: recordName(for: value.domain))
        )
        record["domain"] = value.domain as CKRecordValue
        record["action"] = value.action as CKRecordValue
        record["enabled"] = value.isEnabled as CKRecordValue
        record["updatedAt"] = value.updatedAt as CKRecordValue
        record["deleted"] = value.isDeleted as CKRecordValue
        record["deviceID"] = value.deviceID as CKRecordValue
        return record
    }

    private static func localRecord(_ record: CKRecord) -> DomainOverrideRecord? {
        guard let domain = record["domain"] as? String,
              let action = record["action"] as? String,
              let enabled = record["enabled"] as? Bool,
              let updatedAt = record["updatedAt"] as? Date,
              let deleted = record["deleted"] as? Bool,
              let deviceID = record["deviceID"] as? String
        else { return nil }
        return DomainOverrideRecord(
            domain: domain,
            action: action,
            isEnabled: enabled,
            updatedAt: updatedAt,
            isDeleted: deleted,
            deviceID: deviceID
        )
    }

    private static func recordName(for domain: String) -> String {
        Data(domain.utf8).base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
    }
}
