import Foundation

public enum RouteAction: String, Codable, Equatable, Sendable {
    case direct
    case proxyCurrentNode
    case reject
    /// Mihomo PASS/RULE-PASS: this rule has no egress and matching continues
    /// with the next ordered provider rule.
    case continueMatching
}

public enum ProviderLogicalRuleMode: String, Codable, Equatable, Sendable {
    case and
    case or
}

/// A provider rule condition kept independently from its Routeva egress
/// action. Cases mirror the metadata that an Apple TUN-capable core can
/// actually observe; unsupported provider kinds are rejected during import
/// instead of being silently discarded or changing the final action.
public indirect enum RouteRuleMatch: Codable, Equatable, Sendable {
    case domain(String)
    case domainSuffix(String)
    case domainKeyword(String)
    case domainRegex(String)
    case ipCIDR(String)
    case sourceIPCIDR(String)
    case destinationPort(String)
    case sourcePort(String)
    case inboundPort(String)
    case network(String)
    case protocolName(String)
    case geoIP(String)
    case sourceGeoIP(String)
    case geoSite(String)
    case ruleSet(String)
    case sourceRuleSet(String)
    case logical(mode: ProviderLogicalRuleMode, rules: [RouteRuleMatch])
    case not(RouteRuleMatch)
}

public enum ProviderRuleSetBehavior: String, Codable, Equatable, Sendable {
    case domain
    case ipCIDR
    case classical
}

public enum ProviderRuleSetFormat: String, Codable, Equatable, Sendable {
    case yaml
    case text
    case binary
}

/// Remote sources exist only between parsing and import resolution. Import
/// replaces them with inline conditions before persistence so credential-
/// bearing provider URLs never enter SQLite or a runtime manifest.
public enum ProviderRuleSetSource: Codable, Equatable, Sendable {
    case inline([RouteRuleMatch])
    case remoteHTTPS(url: String, format: ProviderRuleSetFormat)
}

public struct ProviderRuleSet: Codable, Equatable, Sendable {
    public let tag: String
    public let behavior: ProviderRuleSetBehavior
    public let source: ProviderRuleSetSource

    public init(
        tag: String,
        behavior: ProviderRuleSetBehavior,
        source: ProviderRuleSetSource
    ) {
        self.tag = tag
        self.behavior = behavior
        self.source = source
    }
}

public struct ProviderRouteRule: Codable, Equatable, Sendable {
    public let match: RouteRuleMatch
    public let action: RouteAction
    public let requiresDestinationResolution: Bool

    public init(
        match: RouteRuleMatch,
        action: RouteAction,
        requiresDestinationResolution: Bool = false
    ) {
        self.match = match
        self.action = action
        self.requiresDestinationResolution = requiresDestinationResolution
    }

    private enum CodingKeys: String, CodingKey {
        case match, action, requiresDestinationResolution
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        match = try values.decode(RouteRuleMatch.self, forKey: .match)
        action = try values.decode(RouteAction.self, forKey: .action)
        requiresDestinationResolution = try values.decodeIfPresent(
            Bool.self,
            forKey: .requiresDestinationResolution
        ) ?? false
    }
}

public struct ProviderRoutePolicy: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 3

    public let schemaVersion: Int
    public let rules: [ProviderRouteRule]
    public let defaultAction: RouteAction
    public let ruleSets: [ProviderRuleSet]

    public init(
        schemaVersion: Int = ProviderRoutePolicy.currentSchemaVersion,
        rules: [ProviderRouteRule],
        defaultAction: RouteAction = .proxyCurrentNode,
        ruleSets: [ProviderRuleSet] = []
    ) {
        self.schemaVersion = schemaVersion
        self.rules = rules
        self.defaultAction = defaultAction
        self.ruleSets = ruleSets
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, rules, defaultAction, ruleSets
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        guard (1...Self.currentSchemaVersion).contains(schemaVersion) else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion,
                in: values,
                debugDescription: "Unsupported provider route-policy schema."
            )
        }
        rules = try values.decode([ProviderRouteRule].self, forKey: .rules)
        defaultAction = try values.decode(RouteAction.self, forKey: .defaultAction)
        ruleSets = try values.decodeIfPresent([ProviderRuleSet].self, forKey: .ruleSets) ?? []
    }
}

public struct RuntimeDomainOverride: Codable, Equatable, Sendable {
    public let domain: String
    public let action: RouteAction

    public init(domain: String, action: RouteAction) {
        self.domain = domain
        self.action = action
    }
}

public struct ProviderProxyGroup: Equatable, Sendable {
    public let name: String
    public let members: [String]

    public init(name: String, members: [String]) {
        self.name = name
        self.members = members
    }
}

/// Collapses provider group selection into Routeva's intentionally simple
/// direct/proxy-current-node/reject contract. Group membership never constrains
/// the final proxy node; it is consulted only to preserve a recursively chosen
/// DIRECT or REJECT default.
public struct BinarySmartPolicyNormalizer: Sendable {
    public init() {}

    public func action(
        for target: String,
        groups: [ProviderProxyGroup],
        maximumDepth: Int = 16
    ) -> RouteAction {
        let byName = Dictionary(groups.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        return resolve(target, groups: byName, visited: [], depthRemaining: maximumDepth)
    }

    private func resolve(
        _ rawTarget: String,
        groups: [String: ProviderProxyGroup],
        visited: Set<String>,
        depthRemaining: Int
    ) -> RouteAction {
        let target = rawTarget.trimmingCharacters(in: .whitespacesAndNewlines)
        switch target.uppercased() {
        case "DIRECT", "COMPATIBLE": return .direct
        case "REJECT", "REJECT-DROP", "REJECT-NO-DROP", "REJECT-TINYGIF",
             "REJECT-IMG", "REJECT-200", "REJECT-DICT", "REJECT-ARRAY",
             "REJECT-VIDEO", "BLOCK":
            return .reject
        case "PASS", "RULE-PASS": return .continueMatching
        default: break
        }

        guard depthRemaining > 0,
              !visited.contains(target),
              let group = groups[target],
              let first = group.members.first
        else { return .proxyCurrentNode }

        var nextVisited = visited
        nextVisited.insert(target)
        return resolve(
            first,
            groups: groups,
            visited: nextVisited,
            depthRemaining: depthRemaining - 1
        )
    }
}
