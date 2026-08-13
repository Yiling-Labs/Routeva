import DataKit
import Foundation
import SharedKit

public struct CompiledCoreConfiguration: @unchecked Sendable {
    public let manifest: RuntimeManifest
    public let json: String

    public init(manifest: RuntimeManifest, json: String) {
        self.manifest = manifest
        self.json = json
    }
}

public enum CoreConfigurationError: Error, Equatable, Sendable {
    case manifestNotFound
    case manifestIdentifierMismatch
    case unsupportedManifestSchema(Int)
    case nodeNotFound
    case profileNodeMismatch
    case duplicateProfileIdentifier
    case selectedProfileMissing
    case credentialInvalid
    case coreUnsupported(CoreIdentifier)
    case unsupportedProxyPlugin(String)
    case unsupportedRouteRule(String)
    case missingCredentialField
    case invalidJSON
}

public struct CoreConfigurationCompiler: Sendable {
    /// Serialization batch size only. Unlike the removed 4096 logical cap,
    /// this never drops a provider rule or changes first-match ordering.
    private static let maximumValuesPerRouteRule = 512

    private enum DomainBatchKind: Equatable {
        case exact
        case suffix
        case keyword
        case regex
    }

    private struct SingBoxCatalogEntry {
        let profile: RuntimeProfile
        let node: NodeRecord
        let credential: ProxyCredentialEnvelope
    }

    public init() {}

    public func compile(
        manifest: RuntimeManifest,
        node: NodeRecord,
        credential: ProxyCredentialEnvelope,
        for core: CoreIdentifier
    ) throws -> CompiledCoreConfiguration {
        guard manifest.schemaVersion <= RuntimeManifest.currentSchemaVersion else {
            throw CoreConfigurationError.unsupportedManifestSchema(manifest.schemaVersion)
        }
        try validate(
            profile: manifest.profile,
            node: node,
            credential: credential,
            core: core
        )

        let object = try singBoxConfiguration(
            manifest: manifest,
            catalog: [SingBoxCatalogEntry(
                profile: manifest.profile,
                node: node,
                credential: credential
            )]
        )
        return try encodedConfiguration(manifest: manifest, object: object)
    }

    /// Compiles the complete selector catalog used by the running sing-box
    /// service.
    public func compile(
        manifest: RuntimeManifest,
        nodes: [NodeRecord],
        credentials: [UUID: ProxyCredentialEnvelope],
        for core: CoreIdentifier
    ) throws -> CompiledCoreConfiguration {
        guard manifest.schemaVersion <= RuntimeManifest.currentSchemaVersion else {
            throw CoreConfigurationError.unsupportedManifestSchema(manifest.schemaVersion)
        }
        guard core == .singBox else { throw CoreConfigurationError.coreUnsupported(core) }
        guard manifest.profiles.contains(where: { $0.id == manifest.profile.id }) else {
            throw CoreConfigurationError.selectedProfileMissing
        }
        guard Set(manifest.profiles.map(\.id)).count == manifest.profiles.count else {
            throw CoreConfigurationError.duplicateProfileIdentifier
        }

        let nodesByID = Dictionary(nodes.map { ($0.id, $0) }, uniquingKeysWith: { lhs, _ in lhs })
        let catalog = try manifest.profiles.map { profile -> SingBoxCatalogEntry in
            guard let node = nodesByID[profile.id] else {
                throw CoreConfigurationError.nodeNotFound
            }
            guard let credential = credentials[profile.id] else {
                throw CoreConfigurationError.credentialInvalid
            }
            try validate(profile: profile, node: node, credential: credential, core: core)
            return SingBoxCatalogEntry(profile: profile, node: node, credential: credential)
        }
        let object = try singBoxConfiguration(manifest: manifest, catalog: catalog)
        return try encodedConfiguration(manifest: manifest, object: object)
    }

    private func validate(
        profile: RuntimeProfile,
        node: NodeRecord,
        credential: ProxyCredentialEnvelope,
        core: CoreIdentifier
    ) throws {
        guard profile.id == node.id,
              profile.protocolKind == node.protocolKind,
              profile.transport == node.transport,
              profile.security == node.security,
              profile.requiresUDP == node.requiresUDP,
              profile.credential.keychainIdentifier == node.credentialReference
        else { throw CoreConfigurationError.profileNodeMismatch }
        guard core.declaredCapabilities.supports(profile) else {
            throw CoreConfigurationError.coreUnsupported(core)
        }
        guard credential.schemaVersion <= ProxyCredentialEnvelope.currentSchemaVersion else {
            throw CoreConfigurationError.credentialInvalid
        }
    }

    private func encodedConfiguration(
        manifest: RuntimeManifest,
        object: [String: Any]
    ) throws -> CompiledCoreConfiguration {
        guard JSONSerialization.isValidJSONObject(object),
              let json = String(
                data: try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
                encoding: .utf8
              )
        else { throw CoreConfigurationError.invalidJSON }
        return CompiledCoreConfiguration(manifest: manifest, json: json)
    }

    private func singBoxConfiguration(
        manifest: RuntimeManifest,
        catalog: [SingBoxCatalogEntry]
    ) throws -> [String: Any] {
        guard !catalog.isEmpty else { throw CoreConfigurationError.nodeNotFound }
        let selectedTag = SingBoxNodeSelector.outboundTag(for: manifest.profile.id)
        let nodeTags = catalog.map { SingBoxNodeSelector.outboundTag(for: $0.profile.id) }
        let nodeOutbounds = try catalog.map { entry in
            try singBoxOutbound(
                node: entry.node,
                credential: entry.credential,
                tag: SingBoxNodeSelector.outboundTag(for: entry.profile.id)
            )
        }
        let effective = effectiveRoutePolicy(manifest)
        let dnsHijackRule: [String: Any] = [
            "port": 53,
            "action": "hijack-dns",
        ]
        var routePreamble = [dnsHijackRule]
        if effective.rules.contains(where: { containsProtocolMatch($0.match) }) {
            // `protocol` matches sniffed metadata. A non-final sniff action
            // enriches the connection and then continues through the original
            // ordered provider rules; omit it entirely for subscriptions that
            // do not use protocol conditions.
            routePreamble.append([
                "action": "sniff",
                "timeout": "300ms",
            ])
        }
        let routeRules = routePreamble + (try singBoxRules(effective.rules))
        let routeRuleSets = try singBoxRuleSets(
            declared: effective.ruleSets,
            rules: effective.rules
        )
        var route: [String: Any] = [
            "auto_detect_interface": true,
            "default_domain_resolver": [
                "server": "dns-bootstrap",
                "strategy": "prefer_ipv4",
            ],
            "rules": routeRules,
            "final": try outboundTag(effective.defaultAction),
        ]
        if !routeRuleSets.isEmpty { route["rule_set"] = routeRuleSets }
        return [
            // Error events stay inside the provider and are reduced to a small
            // stable diagnostic vocabulary. Raw core messages are never
            // persisted, printed, or sent to the host App.
            "log": ["level": "error"],
            "experimental": [
                "clash_api": [:],
                "cache_file": ["enabled": true],
            ],
            "inbounds": [[
                "type": "tun",
                "tag": "tun-in",
                "interface_name": "utun",
                "address": ["172.19.0.1/30", "fdfe:dcba:9876::1/126"],
                "mtu": 4_064,
                // The platform interface translates sing-box's requested
                // routes into NEPacketTunnelNetworkSettings. Without this,
                // iOS enables the VPN but sends no traffic to PacketFlow.
                "auto_route": true,
                // PacketFlow bridge descriptors are packet transports, not
                // kernel utun interfaces. gVisor consumes them directly and
                // does not require a real Darwin interface behind the fd.
                "stack": "gvisor",
            ]],
            "outbounds": nodeOutbounds + [
                [
                    "type": "selector",
                    "tag": SingBoxNodeSelector.groupTag,
                    "outbounds": nodeTags,
                    "default": selectedTag,
                    "interrupt_exist_connections": true,
                ],
                ["type": "direct", "tag": "direct"],
                ["type": "block", "tag": "reject"],
                [
                    // This group is never referenced by routing. It gives the
                    // Packet Tunnel provider a native Libbox URL-test target
                    // whose `proxy` member exercises the real outbound
                    // without relying on traffic generated by the container
                    // App being diverted into its own VPN.
                    "type": "urltest",
                    "tag": "routeva-probe",
                    "outbounds": ["proxy", "reject"],
                    "url": "https://routeva.yilinglabs.com/probe.txt",
                    "interval": "24h",
                    "idle_timeout": "24h",
                ],
            ],
            "route": route,
            "dns": [
                "servers": [
                    [
                        // Bootstrap must follow the active physical network's
                        // resolver. A fixed public DNS can be unreachable
                        // before the proxy endpoint itself has been resolved.
                        "type": "local", "tag": "dns-bootstrap",
                    ],
                    singBoxDNS(
                        manifest.dnsPreset,
                        routingMode: manifest.routingMode
                    ),
                ],
                "final": "dns-remote",
                "strategy": "prefer_ipv4",
            ],
        ]
    }

    private func effectiveRoutePolicy(
        _ manifest: RuntimeManifest
    ) -> (
        rules: [ProviderRouteRule],
        defaultAction: RouteAction,
        ruleSets: [ProviderRuleSet]
    ) {
        let overrideRules = manifest.domainOverrides.map {
            ProviderRouteRule(match: .domain($0.domain), action: $0.action)
        }
        switch manifest.routingMode {
        case .automatic:
            return (
                overrideRules + (manifest.providerRoutePolicy?.rules ?? []),
                manifest.providerRoutePolicy?.defaultAction ?? .proxyCurrentNode,
                manifest.providerRoutePolicy?.ruleSets ?? []
            )
        case .global:
            return (overrideRules, .proxyCurrentNode, [])
        case .direct:
            return (overrideRules, .direct, [])
        }
    }

    private func isSafeDomainRouteValue(_ value: String, isKeyword: Bool) -> Bool {
        guard !value.isEmpty,
              value.utf8.count <= 253,
              !value.unicodeScalars.contains(where: {
                  CharacterSet.whitespacesAndNewlines.contains($0)
                      || CharacterSet.controlCharacters.contains($0)
              })
        else { return false }

        if isKeyword { return true }
        guard !value.contains("://"),
              !value.contains("/"),
              !value.contains(":"),
              !value.contains("*"),
              !value.hasPrefix("."),
              !value.hasSuffix(".")
        else { return false }
        let labels = value.split(separator: ".", omittingEmptySubsequences: false)
        guard !labels.isEmpty else { return false }
        return labels.allSatisfy { label in
            guard !label.isEmpty,
                  label.utf8.count <= 63,
                  label.first != "-",
                  label.last != "-"
            else { return false }
            return label.unicodeScalars.allSatisfy {
                CharacterSet.alphanumerics.contains($0) || $0 == "-" || $0 == "_"
            }
        }
    }

    private func outboundTag(_ action: RouteAction) throws -> String {
        switch action {
        case .direct: "direct"
        case .proxyCurrentNode: "proxy"
        case .reject: "reject"
        case .continueMatching:
            throw CoreConfigurationError.unsupportedRouteRule("continue_as_final")
        }
    }

    private func singBoxRules(_ rules: [ProviderRouteRule]) throws -> [[String: Any]] {
        var objects: [[String: Any]] = []
        objects.reserveCapacity(rules.count * 2)
        var index = 0
        while index < rules.count {
            let rule = rules[index]
            if rule.action == .continueMatching {
                index += 1
                continue
            }
            if rule.requiresDestinationResolution {
                objects.append([
                    "action": "resolve",
                    "server": "dns-remote",
                    "strategy": "prefer_ipv4",
                ])
            }
            if let descriptor = domainBatchDescriptor(rule.match) {
                var values = [descriptor.value]
                var cursor = index + 1
                while cursor < rules.count,
                      values.count < Self.maximumValuesPerRouteRule,
                      rules[cursor].action == rule.action,
                      rules[cursor].requiresDestinationResolution == rule.requiresDestinationResolution,
                      let candidate = domainBatchDescriptor(rules[cursor].match),
                      candidate.kind == descriptor.kind {
                    values.append(candidate.value)
                    cursor += 1
                }
                objects.append([
                    singBoxDomainKey(descriptor.kind): values,
                    "action": "route",
                    "outbound": try outboundTag(rule.action),
                ])
                index = cursor
                continue
            }
            var object = try singBoxMatchObject(rule.match, headless: false)
            object["action"] = "route"
            object["outbound"] = try outboundTag(rule.action)
            objects.append(object)
            index += 1
        }
        return objects
    }

    private func containsProtocolMatch(_ match: RouteRuleMatch) -> Bool {
        switch match {
        case .protocolName:
            true
        case let .logical(_, rules):
            rules.contains(where: containsProtocolMatch)
        case let .not(rule):
            containsProtocolMatch(rule)
        default:
            false
        }
    }

    private func domainBatchDescriptor(
        _ match: RouteRuleMatch
    ) -> (kind: DomainBatchKind, value: String)? {
        switch match {
        case let .domain(value): (.exact, value)
        case let .domainSuffix(value): (.suffix, value)
        case let .domainKeyword(value): (.keyword, value)
        case let .domainRegex(value): (.regex, value)
        default: nil
        }
    }

    private func singBoxDomainKey(_ kind: DomainBatchKind) -> String {
        switch kind {
        case .exact: "domain"
        case .suffix: "domain_suffix"
        case .keyword: "domain_keyword"
        case .regex: "domain_regex"
        }
    }

    private func singBoxMatchObject(
        _ match: RouteRuleMatch,
        headless: Bool
    ) throws -> [String: Any] {
        switch match {
        case let .domain(value): return ["domain": [value]]
        case let .domainSuffix(value): return ["domain_suffix": [value]]
        case let .domainKeyword(value): return ["domain_keyword": [value]]
        case let .domainRegex(value): return ["domain_regex": [value]]
        case let .ipCIDR(value): return ["ip_cidr": [value]]
        case let .sourceIPCIDR(value): return ["source_ip_cidr": [value]]
        case let .destinationPort(value): return try singBoxPortObject(value, source: false)
        case let .sourcePort(value): return try singBoxPortObject(value, source: true)
        case .inboundPort:
            throw CoreConfigurationError.unsupportedRouteRule("sing-box.inbound_port")
        case let .network(value): return ["network": normalizedNetwork(value).split(separator: ",").map(String.init)]
        case let .protocolName(value): return ["protocol": [value.lowercased()]]
        case let .geoIP(value): return ["rule_set": [geoRuleSetTag(kind: "geoip", value: value)]]
        case let .sourceGeoIP(value):
            return [
                "rule_set": [geoRuleSetTag(kind: "geoip", value: value)],
                "rule_set_ip_cidr_match_source": true,
            ]
        case let .geoSite(value): return ["rule_set": [geoRuleSetTag(kind: "geosite", value: value)]]
        case let .ruleSet(value): return ["rule_set": [value]]
        case let .sourceRuleSet(value):
            return [
                "rule_set": [value],
                "rule_set_ip_cidr_match_source": true,
            ]
        case let .logical(mode, rules):
            return [
                "type": "logical",
                "mode": mode.rawValue,
                "rules": try rules.map { try singBoxMatchObject($0, headless: headless) },
            ]
        case let .not(rule):
            var object = try singBoxMatchObject(rule, headless: headless)
            object["invert"] = !(object["invert"] as? Bool ?? false)
            return object
        }
    }

    private func singBoxPortObject(_ value: String, source: Bool) throws -> [String: Any] {
        let components = value
            .split(whereSeparator: { $0 == "/" || $0 == "," })
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        var ports: [Int] = []
        var ranges: [String] = []
        for component in components {
            if component.contains("-") {
                let bounds = component.split(separator: "-", maxSplits: 1).compactMap { Int($0) }
                guard bounds.count == 2,
                      (1...65_535).contains(bounds[0]),
                      (1...65_535).contains(bounds[1]),
                      bounds[0] <= bounds[1]
                else { throw CoreConfigurationError.unsupportedRouteRule("invalid_port:\(value)") }
                ranges.append("\(bounds[0]):\(bounds[1])")
            } else {
                guard let port = Int(component), (1...65_535).contains(port) else {
                    throw CoreConfigurationError.unsupportedRouteRule("invalid_port:\(value)")
                }
                ports.append(port)
            }
        }
        guard !ports.isEmpty || !ranges.isEmpty else {
            throw CoreConfigurationError.unsupportedRouteRule("invalid_port:\(value)")
        }
        var object: [String: Any] = [:]
        if !ports.isEmpty { object[source ? "source_port" : "port"] = ports }
        if !ranges.isEmpty { object[source ? "source_port_range" : "port_range"] = ranges }
        return object
    }

    private func normalizedNetwork(_ value: String) -> String {
        value.lowercased()
            .replacingOccurrences(of: "/", with: ",")
            .replacingOccurrences(of: " ", with: "")
    }

    private func singBoxRuleSets(
        declared: [ProviderRuleSet],
        rules: [ProviderRouteRule]
    ) throws -> [[String: Any]] {
        var objects: [[String: Any]] = []
        var tags = Set<String>()
        for ruleSet in declared {
            guard tags.insert(ruleSet.tag).inserted else {
                throw CoreConfigurationError.unsupportedRouteRule("duplicate_rule_set:\(ruleSet.tag)")
            }
            switch ruleSet.source {
            case let .inline(matches):
                objects.append([
                    "type": "inline",
                    "tag": ruleSet.tag,
                    "rules": try matches.map { try singBoxMatchObject($0, headless: true) },
                ])
            case .remoteHTTPS:
                throw CoreConfigurationError.unsupportedRouteRule("unresolved_rule_set:\(ruleSet.tag)")
            }
        }

        for (kind, value) in geoRuleSetReferences(in: rules) {
            let tag = geoRuleSetTag(kind: kind, value: value)
            guard tags.insert(tag).inserted else { continue }
            objects.append([
                "type": "remote",
                "tag": tag,
                "format": "binary",
                "url": "https://raw.githubusercontent.com/SagerNet/sing-\(kind)/rule-set/\(kind)-\(value.lowercased()).srs",
                "download_detour": "proxy",
                "update_interval": "7d",
            ])
        }
        return objects
    }

    private func geoRuleSetReferences(
        in rules: [ProviderRouteRule]
    ) -> [(kind: String, value: String)] {
        rules.flatMap { geoRuleSetReferences(in: $0.match) }
    }

    private func geoRuleSetReferences(
        in match: RouteRuleMatch
    ) -> [(kind: String, value: String)] {
        switch match {
        case let .geoIP(value), let .sourceGeoIP(value): [("geoip", value)]
        case let .geoSite(value): [("geosite", value)]
        case let .logical(_, rules): rules.flatMap { geoRuleSetReferences(in: $0) }
        case let .not(rule): geoRuleSetReferences(in: rule)
        default: []
        }
    }

    private func geoRuleSetTag(kind: String, value: String) -> String {
        "routeva-\(kind)-\(value.lowercased())"
    }

    private func singBoxDNS(
        _ preset: RuntimeManifest.DNSPreset,
        routingMode: RuntimeManifest.RoutingMode
    ) -> [String: Any] {
        var server: [String: Any]
        if routingMode == .direct, preset != .privacy {
            // Direct mode is an explicit request to use the physical network.
            // Keep its Automatic / Compatibility DNS semantics local instead
            // of silently introducing a remote resolver.
            server = [
                "type": "local", "tag": "dns-remote",
            ]
        } else {
            // A proxied session must not resolve user destinations through the
            // physical network: doing so leaks queries and can return poisoned
            // or unreachable answers before the proxy is used. The IP literal
            // removes recursive bootstrap, while TLS SNI retains certificate
            // verification. sing-box 1.12+ DNS dialers are direct by default,
            // so every non-Direct mode must set the proxy detour explicitly.
            server = [
                "type": "https", "tag": "dns-remote", "server": "9.9.9.10",
                "server_port": 443, "path": "/dns-query",
                // Quad9's no-threat-blocking service keeps this setting a DNS
                // transport privacy choice; it does not silently add content
                // filtering to Routeva's product behavior.
                "tls": ["enabled": true, "server_name": "dns10.quad9.net"],
            ]
            if routingMode != .direct { server["detour"] = "proxy" }
        }
        return server
    }

    private func singBoxOutbound(
        node: NodeRecord,
        credential: ProxyCredentialEnvelope,
        tag: String
    ) throws -> [String: Any] {
        let authentication = credential.authentication
        let options = normalized(credential.options)
        var outbound: [String: Any] = [
            "type": singBoxProtocol(node.protocolKind),
            "tag": tag,
            "server": node.endpointHost,
            "server_port": node.endpointPort,
        ]
        switch node.protocolKind {
        case .shadowsocks:
            outbound["method"] = try required(authentication["method"])
            outbound["password"] = try required(authentication["password"])
            try applySingBoxShadowsocksPlugin(options: options, outbound: &outbound)
        case .vmess:
            outbound["uuid"] = try required(authentication["uuid"])
            outbound["security"] = options["scy"] ?? "auto"
            outbound["alter_id"] = Int(options["aid"] ?? "0") ?? 0
        case .vless:
            outbound["uuid"] = try required(authentication["uuid"])
            if let flow = nonEmpty(options["flow"]) { outbound["flow"] = flow }
        case .trojan, .hysteria2:
            outbound["password"] = try required(authentication["password"])
        }

        if let tls = singBoxTLS(node: node, options: options) { outbound["tls"] = tls }
        if let transport = singBoxTransport(node: node, options: options) { outbound["transport"] = transport }
        return outbound
    }

    private func applySingBoxShadowsocksPlugin(
        options: [String: String],
        outbound: inout [String: Any]
    ) throws {
        guard let rawPlugin = nonEmpty(options["plugin"]) else { return }
        let pluginParts = rawPlugin.split(
            separator: ";",
            omittingEmptySubsequences: true
        ).map(String.init)
        guard let declaredPlugin = pluginParts.first?.lowercased() else { return }

        var arguments = parsePluginArguments(Array(pluginParts.dropFirst()))
        if let inline = nonEmpty(options["plugin-opts"]) {
            arguments.merge(parsePluginArguments([inline])) { _, rhs in rhs }
        }
        for (key, value) in options where key.hasPrefix("plugin-opts.") {
            arguments[String(key.dropFirst("plugin-opts.".count)).lowercased()] = value
        }

        let plugin: String
        let serializedOptions: [String]
        switch declaredPlugin {
        case "obfs", "simple-obfs", "obfs-local":
            plugin = "obfs-local"
            var values: [String] = []
            if let mode = firstNonEmpty(arguments, keys: ["obfs", "mode"]) {
                values.append("obfs=\(mode)")
            }
            if let host = firstNonEmpty(arguments, keys: ["obfs-host", "host"]) {
                values.append("obfs-host=\(host)")
            }
            serializedOptions = values
        case "v2ray-plugin":
            plugin = "v2ray-plugin"
            var values: [String] = []
            for key in ["mode", "host", "path", "mux"] {
                if let value = nonEmpty(arguments[key]) { values.append("\(key)=\(value)") }
            }
            if isEnabled(arguments["tls"]) { values.append("tls") }
            serializedOptions = values
        default:
            throw CoreConfigurationError.unsupportedProxyPlugin(declaredPlugin)
        }

        outbound["plugin"] = plugin
        if !serializedOptions.isEmpty {
            outbound["plugin_opts"] = serializedOptions.joined(separator: ";")
        }
    }

    private func parsePluginArguments(_ rawValues: [String]) -> [String: String] {
        var result: [String: String] = [:]
        for rawValue in rawValues {
            let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "{}"))
            for part in trimmed.split(whereSeparator: { $0 == ";" || $0 == "," }) {
                let item = part.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !item.isEmpty else { continue }
                let separator = item.firstIndex(where: { $0 == "=" || $0 == ":" })
                if let separator {
                    let key = item[..<separator].trimmingCharacters(in: .whitespacesAndNewlines)
                        .lowercased()
                    let value = item[item.index(after: separator)...]
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    result[key] = value
                } else {
                    result[item.lowercased()] = "true"
                }
            }
        }
        return result
    }

    private func isEnabled(_ value: String?) -> Bool {
        guard let value else { return false }
        return ["true", "yes", "1", "on", "tls"].contains(value.lowercased())
    }

    private func singBoxProtocol(_ value: ProxyProtocol) -> String {
        switch value {
        case .shadowsocks: "shadowsocks"
        case .vmess: "vmess"
        case .vless: "vless"
        case .trojan: "trojan"
        case .hysteria2: "hysteria2"
        }
    }

    private func singBoxTLS(node: NodeRecord, options: [String: String]) -> [String: Any]? {
        guard node.security != .none else { return nil }
        var tls: [String: Any] = ["enabled": true]
        if let serverName = firstNonEmpty(options, keys: ["sni", "servername", "server-name"]) {
            tls["server_name"] = serverName
        }
        if let fingerprint = nonEmpty(options["fp"] ?? options["client-fingerprint"]) {
            tls["utls"] = ["enabled": true, "fingerprint": fingerprint]
        }
        if node.security == .reality {
            var reality: [String: Any] = ["enabled": true]
            if let publicKey = firstNonEmpty(options, keys: ["pbk", "reality-opts.public-key"]) {
                reality["public_key"] = publicKey
            }
            if let shortID = firstNonEmpty(options, keys: ["sid", "reality-opts.short-id"]) {
                reality["short_id"] = shortID
            }
            tls["reality"] = reality
        }
        return tls
    }

    private func singBoxTransport(node: NodeRecord, options: [String: String]) -> [String: Any]? {
        switch node.transport {
        case .tcp, .quic:
            return nil
        case .webSocket:
            var value: [String: Any] = [
                "type": "ws",
                "path": options["path"] ?? options["ws-opts.path"] ?? "/",
            ]
            if let host = firstNonEmpty(options, keys: ["host", "ws-opts.headers.host"]) {
                value["headers"] = ["Host": host]
            }
            return value
        case .grpc:
            return [
                "type": "grpc",
                "service_name": firstNonEmpty(options, keys: ["servicename", "grpc-opts.grpc-service-name"]) ?? "",
            ]
        case .httpUpgrade:
            return [
                "type": "httpupgrade",
                "path": options["path"] ?? "/",
                "host": options["host"] ?? "",
            ]
        case .splitHTTP:
            return nil
        }
    }

    private func normalized(_ values: [String: String]) -> [String: String] {
        Dictionary(values.map { ($0.key.lowercased(), $0.value) }, uniquingKeysWith: { _, rhs in rhs })
    }

    private func required(_ value: String?) throws -> String {
        guard let value = nonEmpty(value) else { throw CoreConfigurationError.missingCredentialField }
        return value
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func firstNonEmpty(_ values: [String: String], keys: [String]) -> String? {
        for key in keys {
            if let value = nonEmpty(values[key]) { return value }
        }
        return nil
    }
}

public actor CoreConfigurationRepository {
    private let database: RoutevaDatabase
    private let secrets: any SecretStoring
    private let compiler: CoreConfigurationCompiler
    private let decoder = JSONDecoder()

    public init(
        database: RoutevaDatabase,
        secrets: any SecretStoring,
        compiler: CoreConfigurationCompiler = CoreConfigurationCompiler()
    ) {
        self.database = database
        self.secrets = secrets
        self.compiler = compiler
    }

    public func load(manifestID: UUID, for core: CoreIdentifier) async throws -> CompiledCoreConfiguration {
        guard let record = try await database.runtimeManifest(id: manifestID) else {
            throw CoreConfigurationError.manifestNotFound
        }
        guard record.id == manifestID else { throw CoreConfigurationError.manifestIdentifierMismatch }
        return try await compile(record: record, expectedManifestID: manifestID, for: core)
    }

    public func loadCurrent(for core: CoreIdentifier) async throws -> CompiledCoreConfiguration {
        guard let record = try await database.currentRuntimeManifest() else {
            throw CoreConfigurationError.manifestNotFound
        }
        return try await compile(record: record, expectedManifestID: record.id, for: core)
    }

    private func compile(
        record: RuntimeManifestRecord,
        expectedManifestID: UUID,
        for core: CoreIdentifier
    ) async throws -> CompiledCoreConfiguration {
        let manifest = try decoder.decode(RuntimeManifest.self, from: record.manifestData)
        guard manifest.manifestID == expectedManifestID else {
            throw CoreConfigurationError.manifestIdentifierMismatch
        }
        var nodes: [NodeRecord] = []
        var credentials: [UUID: ProxyCredentialEnvelope] = [:]
        nodes.reserveCapacity(manifest.profiles.count)
        for profile in manifest.profiles {
            guard let node = try await database.node(id: profile.id) else {
                throw CoreConfigurationError.nodeNotFound
            }
            let credentialData = try await secrets.data(for: node.credentialReference)
            guard let credential = try? decoder.decode(
                ProxyCredentialEnvelope.self,
                from: credentialData
            ) else { throw CoreConfigurationError.credentialInvalid }
            nodes.append(node)
            credentials[profile.id] = credential
        }
        return try compiler.compile(
            manifest: manifest,
            nodes: nodes,
            credentials: credentials,
            for: core
        )
    }
}
