import Foundation

public struct SecretReference: Codable, Equatable, Sendable {
    public let keychainIdentifier: String

    public init(keychainIdentifier: String) {
        self.keychainIdentifier = keychainIdentifier
    }
}

public struct RuntimeProfile: Codable, Equatable, Sendable {
    public let id: UUID
    public let protocolKind: ProxyProtocol
    public let transport: TransportKind
    public let security: SecurityKind
    public let requiresUDP: Bool
    public let credential: SecretReference

    public init(
        id: UUID,
        protocolKind: ProxyProtocol,
        transport: TransportKind,
        security: SecurityKind,
        requiresUDP: Bool,
        credential: SecretReference
    ) {
        self.id = id
        self.protocolKind = protocolKind
        self.transport = transport
        self.security = security
        self.requiresUDP = requiresUDP
        self.credential = credential
    }
}

/// Stable public tags shared by the configuration compiler and Packet Tunnel.
/// Only UUID-derived tags cross the App/extension boundary; endpoint and
/// credential data remain in the App Group database and shared Keychain.
public enum SingBoxNodeSelector {
    public static let groupTag = "proxy"
    public static let outboundTagPrefix = "routeva-node-"

    public static func outboundTag(for nodeID: UUID) -> String {
        outboundTagPrefix + nodeID.uuidString.lowercased()
    }

    public static func nodeID(fromOutboundTag tag: String) -> UUID? {
        guard tag.hasPrefix(outboundTagPrefix) else { return nil }
        return UUID(uuidString: String(tag.dropFirst(outboundTagPrefix.count)))
    }
}

/// Produces a deterministic bounded catalog with the desired and rollback
/// nodes first. Keeping this policy in SharedKit makes large-subscription
/// behavior independently testable without loading credentials or endpoints.
public enum SingBoxRuntimeCatalogPlanner {
    public static func nodeIDs(
        selectedNodeID: UUID,
        preferredAdditionalNodeIDs: [UUID] = [],
        availableNodeIDs: [UUID],
        limit: Int = RuntimeManifest.maximumSingBoxCatalogProfiles
    ) -> [UUID] {
        guard limit > 0 else { return [] }
        var result: [UUID] = []
        var seen: Set<UUID> = []
        for nodeID in [selectedNodeID] + preferredAdditionalNodeIDs + availableNodeIDs {
            guard seen.insert(nodeID).inserted else { continue }
            result.append(nodeID)
            if result.count == limit { break }
        }
        return result
    }
}

public struct RuntimeManifest: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 6
    /// Each endpoint hostname may preflight up to eight addresses and the
    /// Packet Tunnel accepts at most 256 host-sized excluded routes.
    public static let maximumSingBoxCatalogProfiles = 32

    public enum RoutingMode: String, Codable, Sendable {
        case automatic
        case global
        case direct
    }

    public enum DNSPreset: String, Codable, Sendable {
        case automatic
        case privacy
        case compatibility
    }

    public let schemaVersion: Int
    public let manifestID: UUID
    public let createdAt: Date
    public let corePolicy: CorePolicy
    /// Desired node at manifest creation time. Retained as the compatibility
    /// Selected profile retained for compatibility with earlier manifests.
    public let profile: RuntimeProfile
    /// Nodes available to the running sing-box selector. Schema 1...4
    /// manifests decode as a one-element catalog containing `profile`.
    public let profiles: [RuntimeProfile]
    public let routingMode: RoutingMode
    public let dnsPreset: DNSPreset
    public let directRouteAddresses: [String]
    /// Physical-network A/AAAA results captured before the Packet Tunnel
    /// publishes its DNS settings. Keys are proxy-endpoint or ECH-resolver
    /// bootstrap hostnames; values are numeric addresses only. Older manifests
    /// decode this as empty.
    public let dnsBootstrapAddressMap: [String: [String]]
    public let providerRoutePolicy: ProviderRoutePolicy?
    public let domainOverrides: [RuntimeDomainOverride]

    public init(
        schemaVersion: Int = RuntimeManifest.currentSchemaVersion,
        manifestID: UUID = UUID(),
        createdAt: Date = Date(),
        corePolicy: CorePolicy,
        profile: RuntimeProfile,
        profiles: [RuntimeProfile]? = nil,
        routingMode: RoutingMode = .automatic,
        dnsPreset: DNSPreset = .automatic,
        directRouteAddresses: [String] = [],
        dnsBootstrapAddressMap: [String: [String]] = [:],
        providerRoutePolicy: ProviderRoutePolicy? = nil,
        domainOverrides: [RuntimeDomainOverride] = []
    ) {
        self.schemaVersion = schemaVersion
        self.manifestID = manifestID
        self.createdAt = createdAt
        self.corePolicy = corePolicy
        self.profile = profile
        self.profiles = profiles ?? [profile]
        self.routingMode = routingMode
        self.dnsPreset = dnsPreset
        self.directRouteAddresses = directRouteAddresses
        self.dnsBootstrapAddressMap = dnsBootstrapAddressMap
        self.providerRoutePolicy = providerRoutePolicy
        self.domainOverrides = domainOverrides
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, manifestID, createdAt, corePolicy, profile, profiles, routingMode, dnsPreset
        case directRouteAddresses, dnsBootstrapAddressMap, providerRoutePolicy, domainOverrides
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decode(Int.self, forKey: .schemaVersion)
        manifestID = try values.decode(UUID.self, forKey: .manifestID)
        createdAt = try values.decode(Date.self, forKey: .createdAt)
        corePolicy = try values.decode(CorePolicy.self, forKey: .corePolicy)
        profile = try values.decode(RuntimeProfile.self, forKey: .profile)
        profiles = try values.decodeIfPresent([RuntimeProfile].self, forKey: .profiles) ?? [profile]
        routingMode = try values.decodeIfPresent(RoutingMode.self, forKey: .routingMode) ?? .automatic
        dnsPreset = try values.decodeIfPresent(DNSPreset.self, forKey: .dnsPreset) ?? .automatic
        directRouteAddresses = try values.decodeIfPresent([String].self, forKey: .directRouteAddresses) ?? []
        dnsBootstrapAddressMap = try values.decodeIfPresent(
            [String: [String]].self,
            forKey: .dnsBootstrapAddressMap
        ) ?? [:]
        providerRoutePolicy = try values.decodeIfPresent(ProviderRoutePolicy.self, forKey: .providerRoutePolicy)
        domainOverrides = try values.decodeIfPresent([RuntimeDomainOverride].self, forKey: .domainOverrides) ?? []
    }
}
