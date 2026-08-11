import Foundation
import GRDB
import SharedKit

public struct SubscriptionRecord: Codable, FetchableRecord, PersistableRecord, Sendable, Equatable {
    public static let databaseTableName = "subscriptions"

    public let id: UUID
    public var displayName: String
    public var sourceKind: String
    public var sourceSecretReference: String
    public var isActive: Bool
    public var createdAt: Date
    public var updatedAt: Date
    public var lastRefreshAt: Date?
    public var expiresAt: Date?
    public var usedBytes: Int64?
    public var totalBytes: Int64?
    public var routePolicyJSON: Data?
    public var preferredNodeID: UUID?

    public init(
        id: UUID,
        displayName: String,
        sourceKind: String,
        sourceSecretReference: String,
        isActive: Bool,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        lastRefreshAt: Date? = nil,
        expiresAt: Date? = nil,
        usedBytes: Int64? = nil,
        totalBytes: Int64? = nil,
        routePolicyJSON: Data? = nil,
        preferredNodeID: UUID? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.sourceKind = sourceKind
        self.sourceSecretReference = sourceSecretReference
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastRefreshAt = lastRefreshAt
        self.expiresAt = expiresAt
        self.usedBytes = usedBytes
        self.totalBytes = totalBytes
        self.routePolicyJSON = routePolicyJSON
        self.preferredNodeID = preferredNodeID
    }
}

public struct NodeRecord: Codable, FetchableRecord, PersistableRecord, Sendable, Equatable {
    public static let databaseTableName = "nodes"

    public let id: UUID
    public let subscriptionID: UUID
    public var sortIndex: Int
    public var displayName: String
    public var countryCode: String?
    public var countryName: String?
    public var protocolKind: ProxyProtocol
    public var transport: TransportKind
    public var security: SecurityKind
    public var requiresUDP: Bool
    public var endpointHost: String
    public var endpointPort: Int
    public var credentialReference: String
    public var nonSecretOptionsJSON: Data

    public init(
        id: UUID,
        subscriptionID: UUID,
        sortIndex: Int,
        displayName: String,
        countryCode: String? = nil,
        countryName: String? = nil,
        protocolKind: ProxyProtocol,
        transport: TransportKind,
        security: SecurityKind,
        requiresUDP: Bool,
        endpointHost: String,
        endpointPort: Int,
        credentialReference: String,
        nonSecretOptionsJSON: Data = Data("{}".utf8)
    ) {
        self.id = id
        self.subscriptionID = subscriptionID
        self.sortIndex = sortIndex
        self.displayName = displayName
        self.countryCode = countryCode
        self.countryName = countryName
        self.protocolKind = protocolKind
        self.transport = transport
        self.security = security
        self.requiresUDP = requiresUDP
        self.endpointHost = endpointHost
        self.endpointPort = endpointPort
        self.credentialReference = credentialReference
        self.nonSecretOptionsJSON = nonSecretOptionsJSON
    }
}

public struct ActivityRecord: Codable, FetchableRecord, PersistableRecord, Sendable, Equatable {
    public static let databaseTableName = "activity"

    public let id: UUID
    public let createdAt: Date
    public let eventCode: String
    public let failureBucket: String?
    public let redactedSummary: String

    public init(
        id: UUID,
        createdAt: Date = .now,
        eventCode: String,
        failureBucket: String? = nil,
        redactedSummary: String
    ) {
        self.id = id
        self.createdAt = createdAt
        self.eventCode = eventCode
        self.failureBucket = failureBucket
        self.redactedSummary = redactedSummary
    }
}

public struct ConfigSnapshotRecord: Codable, FetchableRecord, PersistableRecord, Sendable, Equatable {
    public static let databaseTableName = "configSnapshots"

    public let id: UUID
    public let createdAt: Date
    public let manifestID: UUID
    public let manifestData: Data
    public let reasonCode: String

    public init(
        id: UUID,
        createdAt: Date = .now,
        manifestID: UUID,
        manifestData: Data,
        reasonCode: String
    ) {
        self.id = id
        self.createdAt = createdAt
        self.manifestID = manifestID
        self.manifestData = manifestData
        self.reasonCode = reasonCode
    }
}

public struct RuntimeManifestRecord: Codable, FetchableRecord, PersistableRecord, Sendable, Equatable {
    public static let databaseTableName = "runtimeManifests"

    public let id: UUID
    public let schemaVersion: Int
    public let createdAt: Date
    public let manifestData: Data
    public var isCurrent: Bool

    public init(
        id: UUID,
        schemaVersion: Int,
        createdAt: Date = .now,
        manifestData: Data,
        isCurrent: Bool
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.createdAt = createdAt
        self.manifestData = manifestData
        self.isCurrent = isCurrent
    }
}

public struct DomainOverrideRecord: Codable, FetchableRecord, PersistableRecord, Sendable, Equatable {
    public static let databaseTableName = "domainOverrides"

    public let domain: String
    public var action: String
    public var isEnabled: Bool
    public var updatedAt: Date
    public var isDeleted: Bool
    public var deviceID: String

    public init(
        domain: String,
        action: String,
        isEnabled: Bool,
        updatedAt: Date = .now,
        isDeleted: Bool = false,
        deviceID: String
    ) {
        self.domain = domain
        self.action = action
        self.isEnabled = isEnabled
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
        self.deviceID = deviceID
    }
}

public struct SubscriptionCandidate: Sendable {
    public var subscription: SubscriptionRecord
    public var nodes: [NodeRecord]

    public init(subscription: SubscriptionRecord, nodes: [NodeRecord]) {
        self.subscription = subscription
        self.nodes = nodes
    }
}
