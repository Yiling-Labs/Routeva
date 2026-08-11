import Foundation

public struct ParsedSubscription: Equatable, Sendable {
    public let suggestedName: String
    public let nodes: [ParsedProxyNode]
    public let skippedNodeCount: Int
    public let routePolicy: ProviderRoutePolicy?

    public init(
        suggestedName: String,
        nodes: [ParsedProxyNode],
        skippedNodeCount: Int = 0,
        routePolicy: ProviderRoutePolicy? = nil
    ) {
        self.suggestedName = suggestedName
        self.nodes = nodes
        self.skippedNodeCount = skippedNodeCount
        self.routePolicy = routePolicy
    }
}

public struct ParsedProxyNode: Equatable, Sendable {
    public let displayName: String
    public let protocolKind: ProxyProtocol
    public let transport: TransportKind
    public let security: SecurityKind
    public let requiresUDP: Bool
    public let endpointHost: String
    public let endpointPort: Int
    public let credential: ProxyCredentialEnvelope

    public init(
        displayName: String,
        protocolKind: ProxyProtocol,
        transport: TransportKind,
        security: SecurityKind,
        requiresUDP: Bool,
        endpointHost: String,
        endpointPort: Int,
        credential: ProxyCredentialEnvelope
    ) {
        self.displayName = displayName
        self.protocolKind = protocolKind
        self.transport = transport
        self.security = security
        self.requiresUDP = requiresUDP
        self.endpointHost = endpointHost
        self.endpointPort = endpointPort
        self.credential = credential
    }
}

public struct ProxyCredentialEnvelope: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let authentication: [String: String]
    public let options: [String: String]

    public init(
        schemaVersion: Int = ProxyCredentialEnvelope.currentSchemaVersion,
        authentication: [String: String],
        options: [String: String] = [:]
    ) {
        self.schemaVersion = schemaVersion
        self.authentication = authentication
        self.options = options
    }
}

public enum SubscriptionParserError: Error, Equatable, Sendable {
    case emptyInput
    case payloadTooLarge
    case unsupportedFormat
    case invalidBase64
    case invalidJSON
    case malformedURI
    case invalidPort
    case missingRequiredField
    case unsafeYAMLFeature
    case noSupportedNodes
    case surgeProfileContainsNoProxyPolicies
    case invalidRouteRule(String)
    case unsupportedRouteRule(String)
    case insecureRuleProviderURL
    case unresolvedRuleProvider(String)
}

public struct SubscriptionParser: Sendable {
    public static let maximumPayloadBytes = 2 * 1_024 * 1_024

    public init() {}

    public func parseRuleProviderPayload(
        _ data: Data,
        behavior: ProviderRuleSetBehavior,
        format: ProviderRuleSetFormat
    ) throws -> [RouteRuleMatch] {
        try ClashRoutePolicyDecoder().decodeRuleProviderPayload(
            data,
            behavior: behavior,
            format: format
        )
    }

    public func parse(_ data: Data, suggestedName: String? = nil) throws -> ParsedSubscription {
        guard data.count <= Self.maximumPayloadBytes else { throw SubscriptionParserError.payloadTooLarge }
        guard let text = String(data: data, encoding: .utf8) else { throw SubscriptionParserError.unsupportedFormat }
        return try parse(text, suggestedName: suggestedName)
    }

    public func parse(_ input: String, suggestedName: String? = nil) throws -> ParsedSubscription {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw SubscriptionParserError.emptyInput }
        guard text.utf8.count <= Self.maximumPayloadBytes else { throw SubscriptionParserError.payloadTooLarge }

        if SurgeProfileExtractor.isProfile(text) {
            return try parseSurgeProfile(text, suggestedName: suggestedName)
        }

        if text.contains("proxies:") {
            return try parseClashYAML(text, suggestedName: suggestedName)
        }

        if text.contains("\n") && text.contains("://") {
            return try parseURIList(text, suggestedName: suggestedName)
        }

        if supportedSchemes.contains(where: { text.lowercased().hasPrefix("\($0)://") }) {
            let node = try parseURI(text, fallbackIndex: 0)
            return ParsedSubscription(
                suggestedName: normalizedSubscriptionName(suggestedName),
                nodes: [node]
            )
        }

        guard let decoded = decodeBase64(text), let decodedText = String(data: decoded, encoding: .utf8) else {
            throw SubscriptionParserError.unsupportedFormat
        }
        guard decodedText.contains("://") else { throw SubscriptionParserError.invalidBase64 }
        return try parseURIList(decodedText, suggestedName: suggestedName)
    }

    private let supportedSchemes = ["ss", "vmess", "vless", "trojan", "hysteria2", "hy2"]

    private func parseURIList(_ input: String, suggestedName: String?) throws -> ParsedSubscription {
        let lines = input
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var nodes: [ParsedProxyNode] = []
        var skipped = 0
        for line in lines {
            guard supportedSchemes.contains(where: { line.lowercased().hasPrefix("\($0)://") }) else {
                skipped += 1
                continue
            }
            nodes.append(try parseURI(line, fallbackIndex: nodes.count))
        }
        guard !nodes.isEmpty else { throw SubscriptionParserError.noSupportedNodes }
        return ParsedSubscription(
            suggestedName: normalizedSubscriptionName(suggestedName),
            nodes: nodes,
            skippedNodeCount: skipped
        )
    }

    private func parseURI(_ input: String, fallbackIndex: Int) throws -> ParsedProxyNode {
        guard let delimiter = input.firstIndex(of: ":") else { throw SubscriptionParserError.malformedURI }
        let scheme = input[..<delimiter].lowercased()
        switch scheme {
        case "ss": return try parseShadowsocks(input, fallbackIndex: fallbackIndex)
        case "vmess": return try parseVMess(input, fallbackIndex: fallbackIndex)
        case "vless": return try parseStandardURL(input, protocolKind: .vless, fallbackIndex: fallbackIndex)
        case "trojan": return try parseStandardURL(input, protocolKind: .trojan, fallbackIndex: fallbackIndex)
        case "hysteria2", "hy2": return try parseStandardURL(input, protocolKind: .hysteria2, fallbackIndex: fallbackIndex)
        default: throw SubscriptionParserError.unsupportedFormat
        }
    }

    private func parseStandardURL(
        _ input: String,
        protocolKind: ProxyProtocol,
        fallbackIndex: Int
    ) throws -> ParsedProxyNode {
        guard let components = URLComponents(string: input),
              let host = components.host,
              !host.isEmpty,
              let port = components.port,
              (1...65_535).contains(port)
        else { throw SubscriptionParserError.malformedURI }

        let authenticationValue = components.user ?? components.password
        guard let authenticationValue, !authenticationValue.isEmpty else {
            throw SubscriptionParserError.missingRequiredField
        }
        let query = queryDictionary(components.queryItems ?? [])
        let transport: TransportKind
        let security: SecurityKind
        let requiresUDP: Bool
        switch protocolKind {
        case .hysteria2:
            transport = .quic
            security = .tls
            requiresUDP = true
        default:
            transport = transportKind(query["type"] ?? query["network"])
            security = securityKind(query)
            requiresUDP = boolean(query["udp"]) ?? true
        }

        var options = query
        options.removeValue(forKey: "remarks")
        return ParsedProxyNode(
            displayName: displayName(components.fragment, fallbackIndex: fallbackIndex),
            protocolKind: protocolKind,
            transport: transport,
            security: security,
            requiresUDP: requiresUDP,
            endpointHost: host,
            endpointPort: port,
            credential: ProxyCredentialEnvelope(
                authentication: [protocolKind == .vless ? "uuid" : "password": authenticationValue],
                options: options
            )
        )
    }

    private func parseVMess(_ input: String, fallbackIndex: Int) throws -> ParsedProxyNode {
        let encoded = String(input.dropFirst("vmess://".count))
        guard let data = decodeBase64(encoded) else { throw SubscriptionParserError.invalidBase64 }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SubscriptionParserError.invalidJSON
        }
        guard let host = string(object["add"]), !host.isEmpty,
              let port = integer(object["port"]), (1...65_535).contains(port),
              let identifier = string(object["id"]), !identifier.isEmpty
        else { throw SubscriptionParserError.missingRequiredField }

        var options: [String: String] = [:]
        for key in ["aid", "scy", "type", "host", "path", "sni", "fp", "alpn"] {
            if let value = string(object[key]), !value.isEmpty { options[key] = value }
        }
        return ParsedProxyNode(
            displayName: displayName(string(object["ps"]), fallbackIndex: fallbackIndex),
            protocolKind: .vmess,
            transport: transportKind(string(object["net"])),
            security: securityKind(["security": string(object["tls"]) ?? ""]),
            requiresUDP: true,
            endpointHost: host,
            endpointPort: port,
            credential: ProxyCredentialEnvelope(authentication: ["uuid": identifier], options: options)
        )
    }

    private func parseShadowsocks(_ input: String, fallbackIndex: Int) throws -> ParsedProxyNode {
        guard var components = URLComponents(string: input) else { throw SubscriptionParserError.malformedURI }
        let name = displayName(components.fragment, fallbackIndex: fallbackIndex)
        components.fragment = nil

        var host = components.host
        var port = components.port
        var methodAndPassword: String?

        if let user = components.user {
            methodAndPassword = String(data: decodeBase64(user) ?? Data(), encoding: .utf8) ?? user
        } else {
            let body = input
                .dropFirst("ss://".count)
                .split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)[0]
                .split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)[0]
            if let decoded = decodeBase64(String(body)),
               let legacy = String(data: decoded, encoding: .utf8),
               let at = legacy.lastIndex(of: "@") {
                methodAndPassword = String(legacy[..<at])
                let endpoint = String(legacy[legacy.index(after: at)...])
                if let endpointComponents = URLComponents(string: "ss://\(endpoint)") {
                    host = endpointComponents.host
                    port = endpointComponents.port
                }
            }
        }

        guard let host, !host.isEmpty, let port, (1...65_535).contains(port),
              let methodAndPassword,
              let separator = methodAndPassword.firstIndex(of: ":")
        else { throw SubscriptionParserError.malformedURI }
        let method = String(methodAndPassword[..<separator])
        let password = String(methodAndPassword[methodAndPassword.index(after: separator)...])
        guard !method.isEmpty, !password.isEmpty else { throw SubscriptionParserError.missingRequiredField }

        return ParsedProxyNode(
            displayName: name,
            protocolKind: .shadowsocks,
            transport: .tcp,
            security: .none,
            requiresUDP: true,
            endpointHost: host,
            endpointPort: port,
            credential: ProxyCredentialEnvelope(
                authentication: ["method": method, "password": password],
                options: queryDictionary(components.queryItems ?? [])
            )
        )
    }

    private func parseClashYAML(_ input: String, suggestedName: String?) throws -> ParsedSubscription {
        let extractor = ClashYAMLExtractor()
        let mappings = try extractor.proxyMappings(from: input)
        var nodes: [ParsedProxyNode] = []
        var skipped = 0
        for mapping in mappings {
            guard let type = mapping["type"]?.lowercased(), let protocolKind = yamlProtocol(type) else {
                skipped += 1
                continue
            }
            guard let host = mapping["server"], !host.isEmpty,
                  let port = mapping["port"].flatMap(Int.init), (1...65_535).contains(port)
            else { throw SubscriptionParserError.missingRequiredField }

            var authentication: [String: String] = [:]
            switch protocolKind {
            case .shadowsocks:
                authentication["method"] = mapping["cipher"]
                authentication["password"] = mapping["password"]
            case .vmess, .vless:
                authentication["uuid"] = mapping["uuid"]
            case .trojan, .hysteria2:
                authentication["password"] = mapping["password"]
            }
            guard authentication.values.allSatisfy({ !$0.isEmpty }),
                  (protocolKind != .shadowsocks || authentication.count == 2),
                  (protocolKind == .shadowsocks || authentication.count == 1)
            else { throw SubscriptionParserError.missingRequiredField }

            var options = mapping
            for key in ["name", "type", "server", "port", "cipher", "password", "uuid"] {
                options.removeValue(forKey: key)
            }
            let security: SecurityKind = {
                if mapping.keys.contains(where: { $0.hasPrefix("reality-opts") }) { return .reality }
                if boolean(mapping["tls"]) == true || protocolKind == .hysteria2 { return .tls }
                return .none
            }()
            nodes.append(ParsedProxyNode(
                displayName: displayName(mapping["name"], fallbackIndex: nodes.count),
                protocolKind: protocolKind,
                transport: protocolKind == .hysteria2 ? .quic : transportKind(mapping["network"]),
                security: security,
                requiresUDP: boolean(mapping["udp"]) ?? true,
                endpointHost: host,
                endpointPort: port,
                credential: ProxyCredentialEnvelope(authentication: authentication, options: options)
            ))
        }
        guard !nodes.isEmpty else { throw SubscriptionParserError.noSupportedNodes }
        return ParsedSubscription(
            suggestedName: normalizedSubscriptionName(suggestedName),
            nodes: nodes,
            skippedNodeCount: skipped,
            routePolicy: try extractor.routePolicy(from: input)
        )
    }

    private func parseSurgeProfile(_ input: String, suggestedName: String?) throws -> ParsedSubscription {
        let extractor = SurgeProfileExtractor()
        let mappings = extractor.proxyMappings(from: input)
        guard !mappings.isEmpty else {
            throw SubscriptionParserError.surgeProfileContainsNoProxyPolicies
        }

        var nodes: [ParsedProxyNode] = []
        var skipped = 0
        for mapping in mappings {
            guard let type = mapping["type"]?.lowercased(), let protocolKind = yamlProtocol(type) else {
                skipped += 1
                continue
            }
            guard let host = mapping["server"], !host.isEmpty,
                  let port = mapping["port"].flatMap(Int.init), (1...65_535).contains(port)
            else { throw SubscriptionParserError.missingRequiredField }

            var authentication: [String: String] = [:]
            switch protocolKind {
            case .shadowsocks:
                authentication["method"] = mapping["encrypt-method"] ?? mapping["cipher"]
                authentication["password"] = mapping["password"]
            case .vmess, .vless:
                authentication["uuid"] = mapping["username"] ?? mapping["uuid"]
            case .trojan, .hysteria2:
                authentication["password"] = mapping["password"]
            }
            guard authentication.values.allSatisfy({ !$0.isEmpty }),
                  (protocolKind != .shadowsocks || authentication.count == 2),
                  (protocolKind == .shadowsocks || authentication.count == 1)
            else { throw SubscriptionParserError.missingRequiredField }

            var options = mapping
            for key in ["name", "type", "server", "port", "encrypt-method", "cipher", "password", "username", "uuid"] {
                options.removeValue(forKey: key)
            }
            if let path = mapping["ws-path"], !path.isEmpty { options["path"] = path }
            if let headers = mapping["ws-headers"], let host = surgeWebSocketHost(headers) {
                options["host"] = host
            }

            let transport: TransportKind = protocolKind == .hysteria2
                ? .quic
                : (boolean(mapping["ws"]) == true ? .webSocket : transportKind(mapping["network"]))
            let security: SecurityKind = {
                if mapping["security"]?.lowercased() == "reality" { return .reality }
                if protocolKind == .trojan || protocolKind == .hysteria2 || boolean(mapping["tls"]) == true {
                    return .tls
                }
                return .none
            }()
            nodes.append(ParsedProxyNode(
                displayName: displayName(mapping["name"], fallbackIndex: nodes.count),
                protocolKind: protocolKind,
                transport: transport,
                security: security,
                requiresUDP: boolean(mapping["udp-relay"]) ?? (protocolKind != .shadowsocks),
                endpointHost: host,
                endpointPort: port,
                credential: ProxyCredentialEnvelope(authentication: authentication, options: options)
            ))
        }
        guard !nodes.isEmpty else { throw SubscriptionParserError.noSupportedNodes }
        return ParsedSubscription(
            suggestedName: normalizedSubscriptionName(suggestedName),
            nodes: nodes,
            skippedNodeCount: skipped,
            routePolicy: try extractor.routePolicy(from: input)
        )
    }

    private func surgeWebSocketHost(_ headers: String) -> String? {
        headers.split(separator: "|", omittingEmptySubsequences: false).compactMap { rawHeader -> String? in
            let header = String(rawHeader).trimmingCharacters(in: .whitespacesAndNewlines)
            guard let separator = header.firstIndex(of: ":"),
                  header[..<separator].trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "host"
            else { return nil }
            let value = String(header[header.index(after: separator)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        }.first
    }

    private func normalizedSubscriptionName(_ candidate: String?) -> String {
        let trimmed = candidate?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "Imported subscription" : String(trimmed.prefix(80))
    }

    private func displayName(_ candidate: String?, fallbackIndex: Int) -> String {
        let decoded = candidate?.removingPercentEncoding ?? candidate ?? ""
        let trimmed = decoded.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? String(format: "NODE-%02d", fallbackIndex + 1) : String(trimmed.prefix(120))
    }

    private func yamlProtocol(_ value: String) -> ProxyProtocol? {
        switch value {
        case "ss", "shadowsocks": .shadowsocks
        case "vmess": .vmess
        case "vless": .vless
        case "trojan": .trojan
        case "hysteria2", "hy2": .hysteria2
        default: nil
        }
    }

    private func transportKind(_ value: String?) -> TransportKind {
        switch value?.lowercased() {
        case "ws", "websocket": .webSocket
        case "grpc": .grpc
        case "httpupgrade", "http-upgrade": .httpUpgrade
        case "splithttp", "xhttp": .splitHTTP
        case "quic": .quic
        default: .tcp
        }
    }

    private func securityKind(_ values: [String: String]) -> SecurityKind {
        let security = (values["security"] ?? values["tls"] ?? "").lowercased()
        if security == "reality" { return .reality }
        if ["tls", "true", "1"].contains(security) { return .tls }
        return .none
    }

    private func queryDictionary(_ items: [URLQueryItem]) -> [String: String] {
        Dictionary(items.map { ($0.name.lowercased(), $0.value ?? "") }, uniquingKeysWith: { _, rhs in rhs })
    }

    private func boolean(_ value: String?) -> Bool? {
        switch value?.lowercased() {
        case "true", "yes", "1", "on": true
        case "false", "no", "0", "off": false
        default: nil
        }
    }

    private func string(_ value: Any?) -> String? {
        switch value {
        case let string as String: string
        case let number as NSNumber: number.stringValue
        default: nil
        }
    }

    private func integer(_ value: Any?) -> Int? {
        if let number = value as? NSNumber { return number.intValue }
        if let string = value as? String { return Int(string) }
        return nil
    }

    private func decodeBase64(_ input: String) -> Data? {
        var normalized = input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = normalized.count % 4
        if remainder != 0 { normalized.append(String(repeating: "=", count: 4 - remainder)) }
        return Data(base64Encoded: normalized, options: [.ignoreUnknownCharacters])
    }
}

private struct ClashYAMLExtractor {
    func proxyMappings(from input: String) throws -> [[String: String]] {
        let lines = input.components(separatedBy: .newlines)
        guard let headerIndex = lines.firstIndex(where: {
            scalarLine($0).trimmingCharacters(in: .whitespaces) == "proxies:"
        }) else { throw SubscriptionParserError.unsupportedFormat }
        let headerIndent = indentation(lines[headerIndex])

        var results: [[String: String]] = []
        var current: [String: String]?
        var parents: [(indent: Int, key: String)] = []

        for rawLine in lines[(headerIndex + 1)...] {
            let safeLine = scalarLine(rawLine)
            let trimmed = safeLine.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            let indent = indentation(safeLine)
            if indent <= headerIndent { break }
            if trimmed.contains("<<:") { throw SubscriptionParserError.unsafeYAMLFeature }

            if trimmed.hasPrefix("- ") || trimmed == "-" {
                if let current { results.append(current) }
                current = [:]
                parents = []
                let remainder = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
                if remainder.hasPrefix("{") {
                    guard remainder.hasSuffix("}") else { throw SubscriptionParserError.unsupportedFormat }
                    for pair in splitTopLevel(String(remainder.dropFirst().dropLast()), separator: ",") {
                        try assign(pair, prefix: nil, to: &current!)
                    }
                } else if !remainder.isEmpty {
                    try assign(remainder, prefix: nil, to: &current!)
                }
                continue
            }

            guard current != nil else { continue }
            while let last = parents.last, last.indent >= indent { parents.removeLast() }
            guard let separator = firstUnquotedColon(in: trimmed) else { continue }
            let key = String(trimmed[..<separator]).trimmingCharacters(in: .whitespaces)
            let value = String(trimmed[trimmed.index(after: separator)...]).trimmingCharacters(in: .whitespaces)
            let prefix = parents.map(\.key).joined(separator: ".")
            let flattened = prefix.isEmpty ? key : "\(prefix).\(key)"
            if value.isEmpty {
                parents.append((indent, key))
            } else {
                let parsed = try yamlScalar(value)
                current?[flattened] = parsed
                if current?[key] == nil { current?[key] = parsed }
            }
        }
        if let current { results.append(current) }
        return results
    }

    func routePolicy(from input: String) throws -> ProviderRoutePolicy? {
        try ClashRoutePolicyDecoder().decode(input)
    }

    private func proxyGroups(from input: String) throws -> [ProviderProxyGroup] {
        let lines = try sectionLines(named: "proxy-groups", from: input)
        guard !lines.isEmpty else { return [] }

        var groups: [ProviderProxyGroup] = []
        var currentName: String?
        var currentMembers: [String] = []
        var groupIndent: Int?
        var membersKeyIndent: Int?

        func finishCurrent() {
            guard let currentName, !currentName.isEmpty else { return }
            groups.append(ProviderProxyGroup(name: currentName, members: currentMembers))
        }

        for rawLine in lines {
            let safeLine = scalarLine(rawLine)
            let trimmed = safeLine.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            if trimmed.contains("<<:") { throw SubscriptionParserError.unsafeYAMLFeature }
            let indent = indentation(safeLine)

            if trimmed.hasPrefix("- "), groupIndent == nil || indent == groupIndent {
                finishCurrent()
                currentName = nil
                currentMembers = []
                groupIndent = indent
                membersKeyIndent = nil
                let remainder = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
                if remainder.hasPrefix("{") {
                    guard remainder.hasSuffix("}") else { throw SubscriptionParserError.unsupportedFormat }
                    let mapping = try inlineMapping(String(remainder.dropFirst().dropLast()))
                    currentName = mapping["name"]
                    if let proxies = mapping["proxies"] {
                        currentMembers = try yamlList(proxies)
                    }
                } else if let separator = firstUnquotedColon(in: remainder) {
                    let key = String(remainder[..<separator]).trimmingCharacters(in: .whitespaces)
                    let value = String(remainder[remainder.index(after: separator)...])
                    if key == "name" { currentName = try yamlScalar(value) }
                }
                continue
            }

            guard currentName != nil || groupIndent != nil else { continue }
            if let membersKeyIndent, indent > membersKeyIndent, trimmed.hasPrefix("- ") {
                currentMembers.append(try yamlScalar(
                    String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
                ))
                continue
            }

            guard let separator = firstUnquotedColon(in: trimmed) else { continue }
            let key = String(trimmed[..<separator]).trimmingCharacters(in: .whitespaces)
            let rawValue = String(trimmed[trimmed.index(after: separator)...])
                .trimmingCharacters(in: .whitespaces)
            switch key {
            case "name":
                currentName = try yamlScalar(rawValue)
            case "proxies":
                membersKeyIndent = indent
                if !rawValue.isEmpty { currentMembers = try yamlList(rawValue) }
            default:
                break
            }
        }
        finishCurrent()
        return groups
    }

    private func routeMatch(kind: String, value: String) -> RouteRuleMatch? {
        switch kind {
        case "DOMAIN": return .domain(value.lowercased())
        case "DOMAIN-SUFFIX": return .domainSuffix(value.lowercased())
        case "DOMAIN-KEYWORD": return .domainKeyword(value.lowercased())
        case "IP-CIDR", "IP-CIDR6", "SRC-IP-CIDR": return .ipCIDR(value)
        case "DST-PORT": return .destinationPort(value)
        case "NETWORK": return .network(value.lowercased())
        case "GEOIP": return .geoIP(value.uppercased())
        case "GEOSITE": return .geoSite(value.lowercased())
        case "RULE-SET": return .ruleSet(value)
        default: return nil
        }
    }

    private func listValues(in section: String, from input: String) throws -> [String] {
        try sectionLines(named: section, from: input).compactMap { rawLine in
            let trimmed = scalarLine(rawLine).trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("- ") else { return nil }
            return try yamlScalar(String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces))
        }
    }

    private func sectionLines(named section: String, from input: String) throws -> [String] {
        let lines = input.components(separatedBy: .newlines)
        guard let headerIndex = lines.firstIndex(where: {
            scalarLine($0).trimmingCharacters(in: .whitespaces) == "\(section):"
        }) else { return [] }
        let headerIndent = indentation(lines[headerIndex])
        var result: [String] = []
        for rawLine in lines[(headerIndex + 1)...] {
            let safeLine = scalarLine(rawLine)
            let trimmed = safeLine.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            if trimmed.contains("<<:") { throw SubscriptionParserError.unsafeYAMLFeature }
            if indentation(safeLine) <= headerIndent { break }
            result.append(safeLine)
        }
        return result
    }

    private func inlineMapping(_ input: String) throws -> [String: String] {
        var result: [String: String] = [:]
        for pair in splitTopLevel(input, separator: ",") {
            guard let separator = firstUnquotedColon(in: pair) else { continue }
            let key = String(pair[..<separator]).trimmingCharacters(in: .whitespaces)
            let value = String(pair[pair.index(after: separator)...]).trimmingCharacters(in: .whitespaces)
            result[key] = value.hasPrefix("[") ? value : try yamlScalar(value)
        }
        return result
    }

    private func yamlList(_ input: String) throws -> [String] {
        let value = input.trimmingCharacters(in: .whitespaces)
        guard value.hasPrefix("["), value.hasSuffix("]") else {
            throw SubscriptionParserError.unsupportedFormat
        }
        let body = String(value.dropFirst().dropLast())
        guard !body.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        return try splitTopLevel(body, separator: ",").map {
            try yamlScalar($0.trimmingCharacters(in: .whitespaces))
        }
    }

    private func assign(_ pair: String, prefix: String?, to mapping: inout [String: String]) throws {
        guard let separator = firstUnquotedColon(in: pair) else { return }
        let key = String(pair[..<separator]).trimmingCharacters(in: .whitespaces)
        let rawValue = String(pair[pair.index(after: separator)...]).trimmingCharacters(in: .whitespaces)
        mapping[prefix.map { "\($0).\(key)" } ?? key] = try yamlScalar(rawValue)
    }

    private func yamlScalar(_ input: String) throws -> String {
        let value = input.trimmingCharacters(in: .whitespaces)
        if value.hasPrefix("&") || value.hasPrefix("*") || value.hasPrefix("!") {
            throw SubscriptionParserError.unsafeYAMLFeature
        }
        guard value.count >= 2 else { return value }
        if value.first == "\"", value.last == "\"" {
            let data = Data(value.utf8)
            return (try? JSONDecoder().decode(String.self, from: data)) ?? String(value.dropFirst().dropLast())
        }
        if value.first == "'", value.last == "'" {
            return String(value.dropFirst().dropLast()).replacingOccurrences(of: "''", with: "'")
        }
        return value
    }

    private func scalarLine(_ input: String) -> String {
        var quote: Character?
        var escaped = false
        for index in input.indices {
            let character = input[index]
            if escaped { escaped = false; continue }
            if character == "\\", quote == "\"" { escaped = true; continue }
            if character == "\"" || character == "'" {
                if quote == character { quote = nil } else if quote == nil { quote = character }
            } else if character == "#", quote == nil {
                return String(input[..<index])
            }
        }
        return input
    }

    private func firstUnquotedColon(in input: String) -> String.Index? {
        var quote: Character?
        var escaped = false
        for index in input.indices {
            let character = input[index]
            if escaped { escaped = false; continue }
            if character == "\\", quote == "\"" { escaped = true; continue }
            if character == "\"" || character == "'" {
                if quote == character { quote = nil } else if quote == nil { quote = character }
            } else if character == ":", quote == nil {
                return index
            }
        }
        return nil
    }

    private func splitTopLevel(_ input: String, separator: Character) -> [String] {
        var result: [String] = []
        var start = input.startIndex
        var quote: Character?
        var depth = 0
        for index in input.indices {
            let character = input[index]
            if character == "\"" || character == "'" {
                if quote == character { quote = nil } else if quote == nil { quote = character }
            } else if quote == nil {
                if "[{(".contains(character) { depth += 1 }
                if "]})".contains(character) { depth -= 1 }
                if character == separator, depth == 0 {
                    result.append(String(input[start..<index]))
                    start = input.index(after: index)
                }
            }
        }
        result.append(String(input[start...]))
        return result
    }

    private func indentation(_ input: String) -> Int {
        input.prefix(while: { $0 == " " }).count
    }
}

/// Reads the declarative portions of a Surge profile.  It deliberately never
/// follows `#!include`, `policy-path`, `update-url`, rewrite, or script values:
/// importing a local profile must not execute code or initiate a second,
/// unrequested subscription download.
private struct SurgeProfileExtractor {
    static func isProfile(_ input: String) -> Bool {
        let sections = Set(input.components(separatedBy: .newlines).compactMap { line -> String? in
            let trimmed = stripComment(line).trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("["), trimmed.hasSuffix("]") else { return nil }
            return String(trimmed.dropFirst().dropLast()).lowercased()
        })
        return !sections.isDisjoint(with: ["general", "proxy", "proxy group", "rule"])
    }

    func proxyMappings(from input: String) -> [[String: String]] {
        sectionLines(named: "Proxy", from: input).compactMap { line in
            guard let separator = firstUnquotedEquals(in: line) else { return nil }
            let name = scalar(String(line[..<separator]))
            let declaration = String(line[line.index(after: separator)...])
            let values = splitCommaSeparated(declaration)
            guard let rawType = values.first else { return nil }

            var mapping = ["name": name, "type": scalar(rawType)]
            guard values.count >= 3 else { return mapping }
            mapping["server"] = scalar(values[1])
            mapping["port"] = scalar(values[2])
            for value in values.dropFirst(3) {
                guard let parameterSeparator = firstUnquotedEquals(in: value) else { continue }
                let key = scalar(String(value[..<parameterSeparator])).lowercased()
                let parameter = scalar(String(value[value.index(after: parameterSeparator)...]))
                guard !key.isEmpty else { continue }
                mapping[key] = parameter
            }
            return mapping
        }
    }

    func routePolicy(from input: String) throws -> ProviderRoutePolicy? {
        let groups = proxyGroups(from: input)
        let normalizer = BinarySmartPolicyNormalizer()
        var rules: [ProviderRouteRule] = []
        var defaultAction: RouteAction = .proxyCurrentNode
        var foundRule = false

        for line in sectionLines(named: "Rule", from: input) {
            let fields = splitCommaSeparated(line)
                .map(scalar)
            guard let rawKind = fields.first, !rawKind.isEmpty else {
                throw SubscriptionParserError.invalidRouteRule(line)
            }
            let kind = rawKind.uppercased()

            if kind == "FINAL" || kind == "MATCH" {
                guard fields.count >= 2, !fields[1].isEmpty else {
                    throw SubscriptionParserError.invalidRouteRule(line)
                }
                let action = normalizer.action(for: fields[1], groups: groups)
                guard action != .continueMatching else {
                    throw SubscriptionParserError.invalidRouteRule(line)
                }
                defaultAction = action
                foundRule = true
                break
            }

            guard fields.count >= 3, !fields[1].isEmpty, !fields[2].isEmpty else {
                throw SubscriptionParserError.invalidRouteRule(line)
            }
            let parsed = try routeMatch(
                kind: kind,
                value: fields[1],
                parameters: Array(fields.dropFirst(3))
            )
            rules.append(ProviderRouteRule(
                match: parsed.match,
                action: normalizer.action(for: fields[2], groups: groups),
                requiresDestinationResolution: parsed.requiresDestinationResolution
            ))
            foundRule = true
        }
        return foundRule ? ProviderRoutePolicy(rules: rules, defaultAction: defaultAction) : nil
    }

    private func proxyGroups(from input: String) -> [ProviderProxyGroup] {
        sectionLines(named: "Proxy Group", from: input).compactMap { line in
            guard let separator = firstUnquotedEquals(in: line) else { return nil }
            let name = scalar(String(line[..<separator]))
            let values = splitCommaSeparated(String(line[line.index(after: separator)...]))
            guard !name.isEmpty, !values.isEmpty else { return nil }
            let members = values.dropFirst().map(scalar).filter { !$0.isEmpty && !containsUnquotedEquals($0) }
            return ProviderProxyGroup(name: name, members: members)
        }
    }

    private func routeMatch(
        kind: String,
        value: String,
        parameters: [String]
    ) throws -> (match: RouteRuleMatch, requiresDestinationResolution: Bool) {
        let normalizedParameters = Set(parameters.map {
            scalar($0).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        })
        let noResolve = normalizedParameters.contains("no-resolve")
        let matchSource = normalizedParameters.contains("src")

        switch kind {
        case "DOMAIN": return (.domain(value.lowercased()), false)
        case "DOMAIN-SUFFIX": return (.domainSuffix(value.lowercased()), false)
        case "DOMAIN-KEYWORD": return (.domainKeyword(value.lowercased()), false)
        case "DOMAIN-REGEX": return (.domainRegex(value), false)
        case "DOMAIN-WILDCARD": return (.domainRegex(wildcardRegex(value)), false)
        case "IP-CIDR", "IP-CIDR6":
            return (
                matchSource ? .sourceIPCIDR(value) : .ipCIDR(value),
                !matchSource && !noResolve
            )
        case "SRC-IP-CIDR": return (.sourceIPCIDR(value), false)
        case "DST-PORT", "DEST-PORT": return (.destinationPort(value), false)
        case "SRC-PORT": return (.sourcePort(value), false)
        case "IN-PORT":
            // Surge means the listening port of a local proxy inbound. Routeva
            // has one TUN inbound with no equivalent provider-visible port.
            throw SubscriptionParserError.unsupportedRouteRule(kind)
        case "NETWORK": return (.network(value.lowercased()), false)
        case "PROTOCOL": return (.protocolName(value.lowercased()), false)
        case "GEOIP":
            return (
                matchSource ? .sourceGeoIP(value.uppercased()) : .geoIP(value.uppercased()),
                !matchSource && !noResolve
            )
        case "SRC-GEOIP": return (.sourceGeoIP(value.uppercased()), false)
        case "GEOSITE": return (.geoSite(value.lowercased()), false)
        case "AND", "OR", "NOT":
            let children = try logicalChildren(value)
            let requiresResolution = children.contains(where: \.requiresDestinationResolution)
            let matches = children.map(\.match)
            if kind == "NOT" {
                guard matches.count == 1, let first = matches.first else {
                    throw SubscriptionParserError.invalidRouteRule("NOT,\(value)")
                }
                return (.not(first), requiresResolution)
            }
            guard matches.count >= 2 else {
                throw SubscriptionParserError.invalidRouteRule("\(kind),\(value)")
            }
            return (
                .logical(mode: kind == "AND" ? .and : .or, rules: matches),
                requiresResolution
            )
        case "RULE-SET", "DOMAIN-SET":
            throw SubscriptionParserError.unresolvedRuleProvider(value)
        case "URL-REGEX", "USER-AGENT", "PROCESS-NAME", "PROCESS-PATH", "SSID",
             "CELLULAR-RADIO", "DEVICE-NAME", "SUBNET", "SCRIPT", "RULE-SET-LOGICAL":
            throw SubscriptionParserError.unsupportedRouteRule(kind)
        default:
            throw SubscriptionParserError.unsupportedRouteRule(kind)
        }
    }

    private func logicalChildren(
        _ input: String
    ) throws -> [(match: RouteRuleMatch, requiresDestinationResolution: Bool)] {
        let body = strippingEnclosingParentheses(input)
        return try splitCommaSeparated(body).map { rawChild in
            let child = strippingEnclosingParentheses(rawChild)
            let fields = splitCommaSeparated(child).map(scalar)
            guard fields.count >= 2, !fields[0].isEmpty, !fields[1].isEmpty else {
                throw SubscriptionParserError.invalidRouteRule(rawChild)
            }
            return try routeMatch(
                kind: fields[0].uppercased(),
                value: fields[1],
                parameters: Array(fields.dropFirst(2))
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

    private func sectionLines(named section: String, from input: String) -> [String] {
        let lines = input.components(separatedBy: .newlines)
        guard let start = lines.firstIndex(where: { sectionName($0)?.caseInsensitiveCompare(section) == .orderedSame })
        else { return [] }
        var result: [String] = []
        for line in lines[(start + 1)...] {
            if sectionName(line) != nil { break }
            let safeLine = stripComment(line).trimmingCharacters(in: .whitespacesAndNewlines)
            if !safeLine.isEmpty { result.append(safeLine) }
        }
        return result
    }

    private func sectionName(_ line: String) -> String? {
        let trimmed = stripComment(line).trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("["), trimmed.hasSuffix("]") else { return nil }
        return String(trimmed.dropFirst().dropLast())
    }

    private func containsUnquotedEquals(_ input: String) -> Bool {
        firstUnquotedEquals(in: input) != nil
    }

    private func firstUnquotedEquals(in input: String) -> String.Index? {
        var quote: Character?
        var escaped = false
        for index in input.indices {
            let character = input[index]
            if escaped { escaped = false; continue }
            if character == "\\", quote == "\"" { escaped = true; continue }
            if character == "\"" || character == "'" {
                if quote == character { quote = nil } else if quote == nil { quote = character }
            } else if character == "=", quote == nil {
                return index
            }
        }
        return nil
    }

    private func splitCommaSeparated(_ input: String) -> [String] {
        var values: [String] = []
        var start = input.startIndex
        var quote: Character?
        var escaped = false
        var parentheses = 0
        var brackets = 0
        var braces = 0
        for index in input.indices {
            let character = input[index]
            if escaped { escaped = false; continue }
            if character == "\\", quote == "\"" { escaped = true; continue }
            if character == "\"" || character == "'" {
                if quote == character { quote = nil } else if quote == nil { quote = character }
            } else if quote == nil {
                if character == "(" { parentheses += 1 }
                if character == ")" { parentheses -= 1 }
                if character == "[" { brackets += 1 }
                if character == "]" { brackets -= 1 }
                if character == "{" { braces += 1 }
                if character == "}" { braces -= 1 }
            }
            if character == ",", quote == nil,
               parentheses == 0, brackets == 0, braces == 0 {
                values.append(String(input[start..<index]))
                start = input.index(after: index)
            }
        }
        values.append(String(input[start...]))
        return values
    }

    private func scalar(_ input: String) -> String {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.count >= 2,
              (value.first == "\"" && value.last == "\"") || (value.first == "'" && value.last == "'")
        else { return value }
        return String(value.dropFirst().dropLast())
    }

    private static func stripComment(_ input: String) -> String {
        var quote: Character?
        var escaped = false
        for index in input.indices {
            let character = input[index]
            if escaped { escaped = false; continue }
            if character == "\\", quote == "\"" { escaped = true; continue }
            if character == "\"" || character == "'" {
                if quote == character { quote = nil } else if quote == nil { quote = character }
            } else if character == "#", quote == nil {
                return String(input[..<index])
            }
        }
        return input
    }

    private func stripComment(_ input: String) -> String {
        Self.stripComment(input)
    }
}
