import Foundation
import Yams

/// Decodes the provider-policy portion of Clash/Mihomo YAML without importing
/// its proxy-group UI model. Matching stays complete; only the matched target
/// is collapsed to Routeva's direct/current-node/reject egress contract.
struct ClashRoutePolicyDecoder {
    func decode(_ input: String) throws -> ProviderRoutePolicy? {
        let document: Document
        do {
            document = try YAMLDecoder().decode(Document.self, from: input)
        } catch {
            throw SubscriptionParserError.unsupportedFormat
        }
        guard !document.rules.isEmpty else { return nil }

        let groups = document.proxyGroups.map {
            ProviderProxyGroup(name: $0.name, members: $0.proxies)
        }
        let normalizer = BinarySmartPolicyNormalizer()
        let ruleSets = try document.ruleProviders
            .map { try decodeRuleSet(tag: $0.key, provider: $0.value) }
            .sorted { $0.tag < $1.tag }
        let ruleSetBehaviors = Dictionary(
            uniqueKeysWithValues: ruleSets.map { ($0.tag, $0.behavior) }
        )

        var rules: [ProviderRouteRule] = []
        var defaultAction: RouteAction = .proxyCurrentNode
        for line in document.rules {
            let fields = splitTopLevel(line)
            guard let rawKind = fields.first, !rawKind.isEmpty else {
                throw SubscriptionParserError.invalidRouteRule(line)
            }
            let kind = rawKind.uppercased()
            if kind == "MATCH" || kind == "FINAL" {
                guard fields.count >= 2 else {
                    throw SubscriptionParserError.invalidRouteRule(line)
                }
                let action = normalizer.action(for: fields[1], groups: groups)
                guard action != .continueMatching else {
                    throw SubscriptionParserError.invalidRouteRule(line)
                }
                defaultAction = action
                break
            }
            guard fields.count >= 3 else {
                throw SubscriptionParserError.invalidRouteRule(line)
            }
            let parsed = try decodeCondition(
                kind: kind,
                payload: fields[1],
                parameters: Array(fields.dropFirst(3)),
                ruleSetBehaviors: ruleSetBehaviors
            )
            rules.append(ProviderRouteRule(
                match: parsed.match,
                action: normalizer.action(for: fields[2], groups: groups),
                requiresDestinationResolution: parsed.requiresDestinationResolution
            ))
        }
        return ProviderRoutePolicy(
            rules: rules,
            defaultAction: defaultAction,
            ruleSets: ruleSets
        )
    }

    func decodeRuleProviderPayload(
        _ data: Data,
        behavior: ProviderRuleSetBehavior,
        format: ProviderRuleSetFormat
    ) throws -> [RouteRuleMatch] {
        guard data.count <= SubscriptionParser.maximumPayloadBytes,
              let text = String(data: data, encoding: .utf8)
        else { throw SubscriptionParserError.payloadTooLarge }
        let entries: [String]
        switch format {
        case .yaml:
            do {
                entries = try YAMLDecoder().decode(RuleProviderDocument.self, from: text).payload
            } catch {
                throw SubscriptionParserError.unsupportedFormat
            }
        case .text:
            entries = text.components(separatedBy: .newlines).compactMap { rawLine in
                let value = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !value.isEmpty, !value.hasPrefix("#") else { return nil }
                return value
            }
        case .binary:
            throw SubscriptionParserError.unsupportedRouteRule("RULE-SET-FORMAT:binary")
        }
        return try decodeRuleSetPayload(entries, behavior: behavior)
    }

    private func decodeRuleSet(tag: String, provider: RuleProvider) throws -> ProviderRuleSet {
        let normalizedTag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTag.isEmpty else {
            throw SubscriptionParserError.invalidRouteRule("RULE-SET,\(tag)")
        }
        let behavior: ProviderRuleSetBehavior
        switch provider.behavior.lowercased() {
        case "domain": behavior = .domain
        case "ipcidr": behavior = .ipCIDR
        case "classical", "": behavior = .classical
        default: throw SubscriptionParserError.invalidRouteRule("RULE-SET,\(tag)")
        }

        if let payload = provider.payload {
            return ProviderRuleSet(
                tag: normalizedTag,
                behavior: behavior,
                source: .inline(try decodeRuleSetPayload(payload, behavior: behavior))
            )
        }

        guard provider.type.lowercased() == "http",
              let rawURL = provider.url,
              let url = URL(string: rawURL),
              url.scheme?.lowercased() == "https",
              url.user == nil,
              url.password == nil
        else {
            if provider.url != nil { throw SubscriptionParserError.insecureRuleProviderURL }
            throw SubscriptionParserError.unresolvedRuleProvider(normalizedTag)
        }
        let format: ProviderRuleSetFormat
        switch provider.format.lowercased() {
        case "", "yaml", "yml": format = .yaml
        case "text": format = .text
        default: throw SubscriptionParserError.unsupportedRouteRule("RULE-SET-FORMAT:\(provider.format)")
        }
        return ProviderRuleSet(
            tag: normalizedTag,
            behavior: behavior,
            source: .remoteHTTPS(url: url.absoluteString, format: format)
        )
    }

    private func decodeRuleSetPayload(
        _ payload: [String],
        behavior: ProviderRuleSetBehavior
    ) throws -> [RouteRuleMatch] {
        try payload.map { entry in
            switch behavior {
            case .domain:
                return decodeDomainProviderEntry(entry)
            case .ipCIDR:
                return .ipCIDR(entry.trimmingCharacters(in: .whitespacesAndNewlines))
            case .classical:
                let fields = splitTopLevel(entry)
                guard fields.count >= 2 else {
                    throw SubscriptionParserError.invalidRouteRule(entry)
                }
                return try decodeCondition(
                    kind: fields[0].uppercased(),
                    payload: fields[1],
                    parameters: Array(fields.dropFirst(2)),
                    ruleSetBehaviors: [:]
                ).match
            }
        }
    }

    private func decodeDomainProviderEntry(_ rawEntry: String) -> RouteRuleMatch {
        let entry = rawEntry.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if entry.hasPrefix("+.") { return .domainSuffix(String(entry.dropFirst(2))) }
        if entry.hasPrefix(".") { return .domainSuffix(String(entry.dropFirst())) }
        if entry.contains("*") || entry.contains("?") {
            return .domainRegex(wildcardRegex(entry))
        }
        return .domainSuffix(entry)
    }

    private func decodeCondition(
        kind: String,
        payload rawPayload: String,
        parameters: [String],
        ruleSetBehaviors: [String: ProviderRuleSetBehavior]
    ) throws -> (match: RouteRuleMatch, requiresDestinationResolution: Bool) {
        let payload = rawPayload.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedParameters = Set(parameters.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        })
        let noResolve = normalizedParameters.contains("no-resolve")
        let matchSource = normalizedParameters.contains("src")

        switch kind {
        case "DOMAIN": return (.domain(payload.lowercased()), false)
        case "DOMAIN-SUFFIX": return (.domainSuffix(payload.lowercased()), false)
        case "DOMAIN-KEYWORD": return (.domainKeyword(payload.lowercased()), false)
        case "DOMAIN-REGEX": return (.domainRegex(payload), false)
        case "DOMAIN-WILDCARD": return (.domainRegex(wildcardRegex(payload)), false)
        case "IP-CIDR", "IP-CIDR6":
            return (
                matchSource ? .sourceIPCIDR(payload) : .ipCIDR(payload),
                !matchSource && !noResolve
            )
        case "SRC-IP-CIDR": return (.sourceIPCIDR(payload), false)
        case "DST-PORT": return (.destinationPort(payload), false)
        case "SRC-PORT": return (.sourcePort(payload), false)
        case "NETWORK": return (.network(payload.lowercased()), false)
        case "GEOSITE": return (.geoSite(payload.lowercased()), false)
        case "GEOIP":
            return (
                matchSource ? .sourceGeoIP(payload.uppercased()) : .geoIP(payload.uppercased()),
                !matchSource && !noResolve
            )
        case "SRC-GEOIP": return (.sourceGeoIP(payload.uppercased()), false)
        case "RULE-SET":
            guard let behavior = ruleSetBehaviors[payload] else {
                throw SubscriptionParserError.unresolvedRuleProvider(payload)
            }
            let source = matchSource
            return (
                source ? .sourceRuleSet(payload) : .ruleSet(payload),
                !source && behavior != .domain && !noResolve
            )
        case "AND", "OR", "NOT":
            let children = try decodeLogicalChildren(
                payload,
                ruleSetBehaviors: ruleSetBehaviors
            )
            let requiresResolution = children.contains(where: \.requiresDestinationResolution)
            let matches = children.map(\.match)
            if kind == "NOT" {
                guard matches.count == 1, let first = matches.first else {
                    throw SubscriptionParserError.invalidRouteRule("NOT,\(payload)")
                }
                return (.not(first), requiresResolution)
            }
            guard matches.count >= 2 else {
                throw SubscriptionParserError.invalidRouteRule("\(kind),\(payload)")
            }
            return (
                .logical(mode: kind == "AND" ? .and : .or, rules: matches),
                requiresResolution
            )
        case "IP-SUFFIX", "SRC-IP-SUFFIX", "IP-ASN", "SRC-IP-ASN", "IN-PORT",
             "IN-TYPE", "IN-USER", "IN-NAME", "REMATCH-NAME", "PROCESS-PATH",
             "PROCESS-PATH-WILDCARD", "PROCESS-PATH-REGEX", "PROCESS-NAME",
             "PROCESS-NAME-WILDCARD", "PROCESS-NAME-REGEX", "UID", "DSCP", "SUB-RULE":
            throw SubscriptionParserError.unsupportedRouteRule(kind)
        default:
            throw SubscriptionParserError.unsupportedRouteRule(kind)
        }
    }

    private func decodeLogicalChildren(
        _ payload: String,
        ruleSetBehaviors: [String: ProviderRuleSetBehavior]
    ) throws -> [(match: RouteRuleMatch, requiresDestinationResolution: Bool)] {
        let body = strippingEnclosingParentheses(payload)
        return try splitTopLevel(body).map { rawChild in
            let child = strippingEnclosingParentheses(rawChild)
            let fields = splitTopLevel(child)
            guard fields.count >= 2 else {
                throw SubscriptionParserError.invalidRouteRule(rawChild)
            }
            return try decodeCondition(
                kind: fields[0].uppercased(),
                payload: fields[1],
                parameters: Array(fields.dropFirst(2)),
                ruleSetBehaviors: ruleSetBehaviors
            )
        }
    }

    private func wildcardRegex(_ wildcard: String) -> String {
        var result = "^"
        for scalar in wildcard.unicodeScalars {
            switch scalar {
            case "*": result += ".*"
            case "?": result += "."
            case ".", "+", "(", ")", "[", "]", "{", "}", "^", "$", "|", "\\":
                result += "\\\(Character(scalar))"
            default: result.append(Character(scalar))
            }
        }
        return result + "$"
    }

    private func strippingEnclosingParentheses(_ input: String) -> String {
        var value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        while value.first == "(", value.last == ")", enclosesWholeValue(value) {
            value = String(value.dropFirst().dropLast())
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return value
    }

    private func enclosesWholeValue(_ input: String) -> Bool {
        var depth = 0
        for (index, character) in input.enumerated() {
            if character == "(" { depth += 1 }
            if character == ")" { depth -= 1 }
            if depth == 0 && index != input.count - 1 { return false }
            if depth < 0 { return false }
        }
        return depth == 0
    }

    private func splitTopLevel(_ input: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var parentheses = 0
        var brackets = 0
        var braces = 0
        var quote: Character?
        var escaped = false

        for character in input {
            if escaped {
                current.append(character)
                escaped = false
                continue
            }
            if character == "\\" {
                current.append(character)
                escaped = true
                continue
            }
            if let activeQuote = quote {
                current.append(character)
                if character == activeQuote { quote = nil }
                continue
            }
            if character == "\"" || character == "'" {
                quote = character
                current.append(character)
                continue
            }
            switch character {
            case "(": parentheses += 1
            case ")": parentheses -= 1
            case "[": brackets += 1
            case "]": brackets -= 1
            case "{": braces += 1
            case "}": braces -= 1
            case "," where parentheses == 0 && brackets == 0 && braces == 0:
                fields.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
                current = ""
                continue
            default: break
            }
            current.append(character)
        }
        fields.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
        return fields
    }
}

private extension ClashRoutePolicyDecoder {
    struct Document: Decodable {
        let proxyGroups: [ProxyGroup]
        let rules: [String]
        let ruleProviders: [String: RuleProvider]

        enum CodingKeys: String, CodingKey {
            case proxyGroups = "proxy-groups"
            case rules
            case ruleProviders = "rule-providers"
        }

        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            proxyGroups = try values.decodeIfPresent([ProxyGroup].self, forKey: .proxyGroups) ?? []
            rules = try values.decodeIfPresent([String].self, forKey: .rules) ?? []
            ruleProviders = try values.decodeIfPresent(
                [String: RuleProvider].self,
                forKey: .ruleProviders
            ) ?? [:]
        }
    }

    struct ProxyGroup: Decodable {
        let name: String
        let proxies: [String]

        enum CodingKeys: String, CodingKey { case name, proxies }

        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            name = try values.decode(String.self, forKey: .name)
            proxies = try values.decodeIfPresent([String].self, forKey: .proxies) ?? []
        }
    }

    struct RuleProvider: Decodable {
        let type: String
        let behavior: String
        let format: String
        let url: String?
        let payload: [String]?

        enum CodingKeys: String, CodingKey { case type, behavior, format, url, payload }

        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            type = try values.decodeIfPresent(String.self, forKey: .type) ?? "inline"
            behavior = try values.decodeIfPresent(String.self, forKey: .behavior) ?? "classical"
            format = try values.decodeIfPresent(String.self, forKey: .format) ?? "yaml"
            url = try values.decodeIfPresent(String.self, forKey: .url)
            payload = try values.decodeIfPresent([String].self, forKey: .payload)
        }
    }

    struct RuleProviderDocument: Decodable {
        let payload: [String]
    }
}
