import DataKit
import Foundation
import Network
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
    case unsupportedProxyOption(String)
    case unsupportedRouteRule(String)
    case missingCredentialField
    case invalidJSON
}

public struct CoreConfigurationCompiler: Sendable {
    /// Serialization batch size only. Unlike the removed 4096 logical cap,
    /// this never drops a provider rule or changes first-match ordering.
    private static let maximumValuesPerRouteRule = 512
    private static let compatibilityDNSAddress = "223.5.5.5"
    private static let privacyDNSAddress = "9.9.9.10"

    private enum DomainBatchKind: Equatable {
        case exact
        case suffix
        case keyword
        case regex
    }

    private struct ECHDNSRequirement: Hashable {
        let queryDomain: String
        let resolver: ECHDNSResolver
    }

    private enum ECHDNSResolver: Hashable {
        case fallback
        case https(host: String, port: Int, path: String)
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

        let catalog = [SingBoxCatalogEntry(
            profile: manifest.profile,
            node: node,
            credential: credential,
        )]
        let runtimeManifest = try manifestAddingRequiredDirectRoutes(
            manifest,
            catalog: catalog
        )
        let object = try singBoxConfiguration(
            manifest: runtimeManifest,
            catalog: catalog
        )
        return try encodedConfiguration(manifest: runtimeManifest, object: object)
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
        let runtimeManifest = try manifestAddingRequiredDirectRoutes(
            manifest,
            catalog: catalog
        )
        let object = try singBoxConfiguration(manifest: runtimeManifest, catalog: catalog)
        return try encodedConfiguration(manifest: runtimeManifest, object: object)
    }

    /// NetworkExtension applies its default route before sing-box opens proxy
    /// and direct DNS sockets. The Apple platform bridge does not provide a
    /// per-socket protect callback, so every numeric physical-path target must
    /// also be a host-sized excluded route. Derive this from the same parsed
    /// credentials and DNS policy that generate the core JSON; keeping a
    /// second hand-maintained list in the host App would drift as subscription
    /// formats evolve.
    private func manifestAddingRequiredDirectRoutes(
        _ manifest: RuntimeManifest,
        catalog: [SingBoxCatalogEntry]
    ) throws -> RuntimeManifest {
        var requiredAddresses: [String] = []

        switch manifest.dnsPreset {
        case .automatic:
            break
        case .privacy where manifest.routingMode == .direct:
            requiredAddresses.append(Self.privacyDNSAddress)
        case .privacy:
            break
        case .compatibility:
            requiredAddresses.append(Self.compatibilityDNSAddress)
        }

        for entry in catalog where ipLiteral(entry.node.endpointHost) != nil {
            requiredAddresses.append(entry.node.endpointHost)
        }

        for entry in catalog {
            guard let requirement = try echDNSRequirement(
                node: entry.node,
                options: normalized(entry.credential.options)
            ) else { continue }
            switch requirement.resolver {
            case .fallback:
                requiredAddresses.append(Self.compatibilityDNSAddress)
            case .https:
                requiredAddresses.append(try echDNSAddress(
                    resolver: requirement.resolver,
                    bootstrapAddresses: manifest.dnsBootstrapAddressMap
                ))
            }
        }

        // Domain-based proxy endpoints are resolved by the host App before
        // NetworkExtension takes over the default route. Keep those exact
        // addresses ahead of the bounded route list: the generated outbound
        // uses the same map as a non-networking `hosts` DNS transport, so its
        // bootstrap cannot depend on user DNS or recursively enter the TUN.
        for entry in catalog where ipLiteral(entry.node.endpointHost) == nil {
            requiredAddresses.append(contentsOf: bootstrapAddresses(
                for: entry.node.endpointHost,
                in: manifest.dnsBootstrapAddressMap
            ))
        }

        let directRouteAddresses = DirectRouteAddressValidator.validated(
            requiredAddresses + manifest.directRouteAddresses
        )
        guard directRouteAddresses != manifest.directRouteAddresses else {
            return manifest
        }
        return RuntimeManifest(
            schemaVersion: manifest.schemaVersion,
            manifestID: manifest.manifestID,
            createdAt: manifest.createdAt,
            corePolicy: manifest.corePolicy,
            profile: manifest.profile,
            profiles: manifest.profiles,
            routingMode: manifest.routingMode,
            dnsPreset: manifest.dnsPreset,
            directRouteAddresses: directRouteAddresses,
            dnsBootstrapAddressMap: manifest.dnsBootstrapAddressMap,
            providerRoutePolicy: manifest.providerRoutePolicy,
            domainOverrides: manifest.domainOverrides
        )
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
            let endpointAddresses = bootstrapAddresses(
                for: entry.node.endpointHost,
                in: manifest.dnsBootstrapAddressMap
            )
            return try singBoxOutbound(
                node: entry.node,
                credential: entry.credential,
                tag: SingBoxNodeSelector.outboundTag(for: entry.profile.id),
                endpointResolver: ipLiteral(entry.node.endpointHost) != nil
                    ? nil
                    : (endpointAddresses.isEmpty
                        ? Self.dnsSystemTag
                        : Self.dnsEndpointTag)
            )
        }
        let echDNSRequirements = try catalog.compactMap { entry in
            try echDNSRequirement(
                node: entry.node,
                options: normalized(entry.credential.options)
            )
        }
        let proxyEndpointDomains = catalog.compactMap { entry in
            ipLiteral(entry.node.endpointHost) == nil ? entry.node.endpointHost.lowercased() : nil
        }
        let effective = effectiveRoutePolicy(manifest)
        let dnsHijackRule: [String: Any] = [
            "port": 53,
            "action": "hijack-dns",
        ]
        var routePreamble = [dnsHijackRule]
        if effective.rules.contains(where: { containsProtocolMatch($0.match) })
            || effective.rules.contains(where: { containsDomainMatch($0.match) }) {
            // Sniff recovers the original hostname after a real-IP DNS
            // answer so DOMAIN / protocol rules still match. Skip it when
            // the policy has neither kind of condition.
            routePreamble.append([
                "action": "sniff",
                "timeout": "300ms",
            ])
        }
        let dns = try singBoxDNSObject(
            preset: manifest.dnsPreset,
            routingMode: manifest.routingMode,
            effective: effective,
            proxyEndpointDomains: Array(Set(proxyEndpointDomains)).sorted(),
            echRequirements: echDNSRequirements,
            bootstrapAddresses: manifest.dnsBootstrapAddressMap
        )
        let dnsFinal = (dns["final"] as? String) ?? Self.dnsRealTag
        let routeRules = routePreamble + (try singBoxRules(
            effective.rules,
            realDNS: dnsFinal
        ))
        let routeRuleSets = try singBoxRuleSets(
            declared: effective.ruleSets,
            rules: effective.rules
        )
        var route: [String: Any] = [
            "auto_detect_interface": true,
            "default_domain_resolver": [
                "server": dnsFinal,
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
                [
                    "type": "direct",
                    "tag": "direct",
                    // DIRECT needs a real destination address. Keep it on the
                    // real DNS plane, never on the proxy, so CDN and local
                    // destinations follow the selected DNS preset.
                    "domain_resolver": [
                        "server": Self.dnsRealTag,
                        "strategy": "prefer_ipv4",
                    ],
                ],
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
            "dns": dns,
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

    private func singBoxRules(
        _ rules: [ProviderRouteRule],
        realDNS: String
    ) throws -> [[String: Any]] {
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
                    "server": realDNS,
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

    private func containsDomainMatch(_ match: RouteRuleMatch) -> Bool {
        switch match {
        case .domain, .domainSuffix, .domainKeyword, .domainRegex:
            true
        case let .logical(_, rules):
            rules.contains(where: containsDomainMatch)
        case let .not(rule):
            containsDomainMatch(rule)
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

    private static let dnsBootstrapTag = "dns-bootstrap"
    private static let dnsEndpointTag = "dns-endpoint"
    private static let dnsProxyTag = "dns-proxy"
    private static let dnsRealTag = "dns-real"
    private static let dnsSystemTag = "dns-system"

    private func singBoxDNSObject(
        preset: RuntimeManifest.DNSPreset,
        routingMode: RuntimeManifest.RoutingMode,
        effective: (
            rules: [ProviderRouteRule],
            defaultAction: RouteAction,
            ruleSets: [ProviderRuleSet]
        ),
        proxyEndpointDomains: [String],
        echRequirements: [ECHDNSRequirement],
        bootstrapAddresses: [String: [String]]
    ) throws -> [String: Any] {
        // Keep proxy endpoint bootstrap, query-based ECH bootstrap, and user
        // DNS as independent planes. Endpoint bootstrap must work before the
        // proxy exists; ECH requires HTTPS records over its provider DoH.
        // Automatic splits user DNS: names that will take DIRECT stay on the
        // system resolver so domestic CDNs keep local answers; names that will
        // take the current node (or the unmatched default) go through the
        // node, matching Clash redir-host + remote resolve. Privacy and
        // Compatibility remain explicit single-plane choices.
        var servers: [[String: Any]] = []
        var final = Self.dnsRealTag
        var splitRules: [[String: Any]] = []
        switch preset {
        case .privacy:
            servers.append(privacyHTTPSServer(
                tag: Self.dnsRealTag,
                detour: routingMode != .direct
            ))
        case .compatibility:
            servers.append([
                "type": "udp", "tag": Self.dnsRealTag,
                "server": Self.compatibilityDNSAddress, "server_port": 53,
            ])
        case .automatic:
            servers.append([
                "type": "local", "tag": Self.dnsRealTag,
            ])
            let split = automaticDNSSplit(effective, routingMode: routingMode)
            if split.needsProxyServer {
                servers.append(privacyHTTPSServer(
                    tag: Self.dnsProxyTag,
                    detour: true
                ))
                splitRules = split.rules
                final = split.final
            }
        }
        var dns: [String: Any] = [
            "servers": servers,
            "final": final,
            "strategy": "prefer_ipv4",
            "reverse_mapping": true,
        ]
        var rules: [[String: Any]] = []
        var resolverByDomain: [String: ECHDNSResolver] = [:]
        var domainsByResolver: [ECHDNSResolver: Set<String>] = [:]
        for requirement in echRequirements {
            if let existing = resolverByDomain[requirement.queryDomain],
               existing != requirement.resolver {
                throw CoreConfigurationError.unsupportedProxyOption("ech.resolver_conflict")
            }
            resolverByDomain[requirement.queryDomain] = requirement.resolver
            domainsByResolver[requirement.resolver, default: []].insert(requirement.queryDomain)
        }
        let orderedResolvers = domainsByResolver.keys.sorted {
            echResolverSortKey($0) < echResolverSortKey($1)
        }
        for (index, resolver) in orderedResolvers.enumerated() {
            let tag = orderedResolvers.count == 1 || resolver == .fallback
                ? Self.dnsBootstrapTag
                : "\(Self.dnsBootstrapTag)-\(index + 1)"
            servers.insert(try echDNSServer(
                resolver: resolver,
                tag: tag,
                bootstrapAddresses: bootstrapAddresses
            ), at: index)
            rules.append([
                "domain": Array(domainsByResolver[resolver] ?? []).sorted(),
                "query_type": ["HTTPS"],
                "action": "route",
                "server": tag,
            ])
        }
        let predefinedEndpoints: [String: [String]] = Dictionary(
            uniqueKeysWithValues: proxyEndpointDomains.compactMap { domain in
                let addresses = self.bootstrapAddresses(
                    for: domain,
                    in: bootstrapAddresses
                )
                return addresses.isEmpty ? nil : (domain, addresses)
            }
        )
        if !predefinedEndpoints.isEmpty {
            servers.insert([
                "type": "hosts",
                "tag": Self.dnsEndpointTag,
                "predefined": predefinedEndpoints,
            ], at: 0)
            rules.append([
                "domain": predefinedEndpoints.keys.sorted(),
                "action": "route",
                "server": Self.dnsEndpointTag,
            ])
        }
        let unresolvedEndpoints = proxyEndpointDomains.filter {
            predefinedEndpoints[$0] == nil
        }
        if !unresolvedEndpoints.isEmpty {
            servers.append([
                "type": "local", "tag": Self.dnsSystemTag,
            ])
            rules.append([
                "domain": unresolvedEndpoints,
                "action": "route",
                "server": Self.dnsSystemTag,
            ])
        }
        rules.append(contentsOf: splitRules)
        dns["servers"] = servers
        if !rules.isEmpty { dns["rules"] = rules }
        return dns
    }

    private func privacyHTTPSServer(tag: String, detour: Bool) -> [String: Any] {
        var server: [String: Any] = [
            "type": "https", "tag": tag,
            "server": Self.privacyDNSAddress,
            "server_port": 443, "path": "/dns-query",
            "tls": ["enabled": true, "server_name": "dns10.quad9.net"],
        ]
        if detour { server["detour"] = SingBoxNodeSelector.groupTag }
        return server
    }

    /// Automatic user DNS: any name that may leave through the current node
    /// resolves through that node. Only explicit DIRECT / REJECT domain
    /// exceptions stay on the system resolver.
    ///
    /// Smart provider lists often include thousands of proxy DOMAIN rules and
    /// catch-alls such as `DOMAIN-KEYWORD,.`. Mirroring those into DNS can
    /// invalidate the resolver and silently fall back to local answers — the
    /// Global-works / Smart-fails pattern. Unlisted names therefore use
    /// `dns-proxy` as `final`; we only emit the opposite-plane exceptions.
    private func automaticDNSSplit(
        _ effective: (
            rules: [ProviderRouteRule],
            defaultAction: RouteAction,
            ruleSets: [ProviderRuleSet]
        ),
        routingMode: RuntimeManifest.RoutingMode
    ) -> (rules: [[String: Any]], needsProxyServer: Bool, final: String) {
        let final = routingMode == .direct ? Self.dnsRealTag : Self.dnsProxyTag
        var needsProxyServer = final == Self.dnsProxyTag
        var rules: [[String: Any]] = []
        var index = 0
        while index < effective.rules.count {
            let rule = effective.rules[index]
            if rule.action == .continueMatching {
                index += 1
                continue
            }
            let server = dnsServerTag(for: rule.action)
            if server == final {
                index = skipMatchingDomainBatch(in: effective.rules, from: index)
                continue
            }
            if let descriptor = domainBatchDescriptor(rule.match) {
                var values: [String] = []
                var cursor = index
                while cursor < effective.rules.count,
                      values.count < Self.maximumValuesPerRouteRule,
                      effective.rules[cursor].action == rule.action,
                      let candidate = domainBatchDescriptor(effective.rules[cursor].match),
                      candidate.kind == descriptor.kind {
                    if isSafeDNSDomainValue(candidate.value, kind: candidate.kind) {
                        values.append(candidate.value)
                    }
                    cursor += 1
                }
                if !values.isEmpty {
                    if server == Self.dnsProxyTag { needsProxyServer = true }
                    rules.append([
                        singBoxDomainKey(descriptor.kind): values,
                        "action": "route",
                        "server": server,
                    ])
                }
                index = cursor
                continue
            }
            if let match = dnsMatchObject(rule.match, ruleSets: effective.ruleSets) {
                if server == Self.dnsProxyTag { needsProxyServer = true }
                var object = match
                object["action"] = "route"
                object["server"] = server
                rules.append(object)
            }
            index += 1
        }
        return (rules, needsProxyServer, final)
    }

    private func skipMatchingDomainBatch(
        in rules: [ProviderRouteRule],
        from index: Int
    ) -> Int {
        let rule = rules[index]
        guard let descriptor = domainBatchDescriptor(rule.match) else {
            return index + 1
        }
        var cursor = index + 1
        while cursor < rules.count,
              rules[cursor].action == rule.action,
              let candidate = domainBatchDescriptor(rules[cursor].match),
              candidate.kind == descriptor.kind {
            cursor += 1
        }
        return cursor
    }

    private func isSafeDNSDomainValue(_ value: String, kind: DomainBatchKind) -> Bool {
        switch kind {
        case .keyword:
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.utf8.count >= 2 else { return false }
            return isSafeDomainRouteValue(trimmed, isKeyword: true)
        case .regex:
            return !value.isEmpty && value.utf8.count <= 253
        case .exact, .suffix:
            return isSafeDomainRouteValue(value, isKeyword: false)
        }
    }

    private func dnsServerTag(for action: RouteAction) -> String {
        switch action {
        case .proxyCurrentNode: Self.dnsProxyTag
        case .direct, .reject, .continueMatching: Self.dnsRealTag
        }
    }

    private func dnsMatchObject(
        _ match: RouteRuleMatch,
        ruleSets: [ProviderRuleSet]
    ) -> [String: Any]? {
        switch match {
        case let .domain(value):
            return ["domain": [value]]
        case let .domainSuffix(value):
            return ["domain_suffix": [value]]
        case let .domainKeyword(value):
            return ["domain_keyword": [value]]
        case let .domainRegex(value):
            return ["domain_regex": [value]]
        case let .geoSite(value):
            return ["rule_set": [geoRuleSetTag(kind: "geosite", value: value)]]
        case let .ruleSet(tag):
            guard ruleSets.contains(where: { $0.tag == tag && $0.behavior == .domain }) else {
                return nil
            }
            return ["rule_set": [tag]]
        case let .logical(mode, rules):
            let children = rules.compactMap { dnsMatchObject($0, ruleSets: ruleSets) }
            guard children.count == rules.count, !children.isEmpty else { return nil }
            return [
                "type": "logical",
                "mode": mode.rawValue,
                "rules": children,
            ]
        default:
            return nil
        }
    }

    private func echDNSServer(
        resolver: ECHDNSResolver,
        tag: String,
        bootstrapAddresses: [String: [String]]
    ) throws -> [String: Any] {
        switch resolver {
        case .fallback:
            return [
                "type": "https", "tag": tag,
                "server": Self.compatibilityDNSAddress, "server_port": 443,
                "path": "/dns-query",
                "tls": ["enabled": true, "server_name": "dns.alidns.com"],
            ]
        case let .https(host, port, path):
            return [
                "type": "https", "tag": tag,
                "server": try echDNSAddress(
                    resolver: resolver,
                    bootstrapAddresses: bootstrapAddresses
                ),
                "server_port": port,
                "path": path,
                "tls": ["enabled": true, "server_name": host],
            ]
        }
    }

    private func echDNSAddress(
        resolver: ECHDNSResolver,
        bootstrapAddresses: [String: [String]]
    ) throws -> String {
        switch resolver {
        case .fallback:
            return Self.compatibilityDNSAddress
        case let .https(host, _, _):
            if ipLiteral(host) != nil { return host }
            if let address = DirectRouteAddressValidator.validated(
                bootstrapAddresses[host] ?? []
            ).first {
                return address
            }
            if host == "dns.alidns.com" {
                // Known IP-literal fallback for older manifests created before
                // Routeva persisted preflight DNS bootstrap address mappings.
                return Self.compatibilityDNSAddress
            }
            throw CoreConfigurationError.unsupportedProxyOption("ech.resolver_unresolved")
        }
    }

    private func echResolverSortKey(_ resolver: ECHDNSResolver) -> String {
        switch resolver {
        case .fallback: "0"
        case let .https(host, port, path): "1|\(host)|\(port)|\(path)"
        }
    }

    private func singBoxOutbound(
        node: NodeRecord,
        credential: ProxyCredentialEnvelope,
        tag: String,
        endpointResolver: String? = nil
    ) throws -> [String: Any] {
        let authentication = credential.authentication
        let options = normalized(credential.options)
        var outbound: [String: Any] = [
            "type": singBoxProtocol(node.protocolKind),
            "tag": tag,
            "server": node.endpointHost,
            "server_port": node.endpointPort,
        ]
        if let endpointResolver {
            outbound["domain_resolver"] = [
                "server": endpointResolver,
                "strategy": "prefer_ipv4",
            ]
        }
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
            outbound["packet_encoding"] = firstNonEmpty(
                options,
                keys: ["packetencoding", "packet-encoding", "packet_encoding"]
            )
                ?? "xudp"
        case .trojan:
            outbound["password"] = try required(authentication["password"])
        case .hysteria2:
            outbound["password"] = try required(authentication["password"])
            try applySingBoxHysteria2Options(options: options, outbound: &outbound)
        }

        if let tls = try singBoxTLS(node: node, options: options) {
            outbound["tls"] = tls
        }
        if let transport = try singBoxTransport(node: node, options: options) {
            outbound["transport"] = transport
        }
        return outbound
    }

    private func bootstrapAddresses(
        for host: String,
        in addressMap: [String: [String]]
    ) -> [String] {
        let normalizedHost = host.lowercased()
        let values = addressMap[host]
            ?? addressMap[normalizedHost]
            ?? addressMap.first(where: { $0.key.lowercased() == normalizedHost })?.value
            ?? []
        return DirectRouteAddressValidator.validated(values)
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

    private func applySingBoxHysteria2Options(
        options: [String: String],
        outbound: inout [String: Any]
    ) throws {
        if let ports = firstNonEmpty(
            options,
            keys: ["ports", "mport", "server-ports", "server_ports"]
        ) {
            let values = stringList(ports)
            if !values.isEmpty { outbound["server_ports"] = values }
        }
        if let interval = firstNonEmpty(
            options,
            keys: ["hop-interval", "hop_interval", "hopinterval"]
        ) {
            outbound["hop_interval"] = interval.allSatisfy(\.isNumber) ? "\(interval)s" : interval
        }
        if let up = firstInteger(
            options,
            keys: ["up", "upmbps", "up-mbps", "up_mbps", "up-speed", "up_speed"]
        ), up > 0 {
            outbound["up_mbps"] = up
        }
        if let down = firstInteger(
            options,
            keys: ["down", "downmbps", "down-mbps", "down_mbps", "down-speed", "down_speed"]
        ), down > 0 {
            outbound["down_mbps"] = down
        }

        let obfsPassword = firstNonEmpty(
            options,
            keys: ["obfs-password", "obfs_password", "obfs.password"]
        )
        let obfsType = firstNonEmpty(options, keys: ["obfs", "obfs.type"])
        guard obfsPassword != nil || obfsType != nil else { return }
        let type = obfsType?.lowercased() ?? "salamander"
        guard type == "salamander", let obfsPassword else {
            throw CoreConfigurationError.unsupportedProxyOption("hysteria2.obfs")
        }
        outbound["obfs"] = ["type": type, "password": obfsPassword]
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

    private func singBoxTLS(
        node: NodeRecord,
        options: [String: String]
    ) throws -> [String: Any]? {
        guard node.security != .none else { return nil }
        var tls: [String: Any] = ["enabled": true]
        if let serverName = firstNonEmpty(options, keys: ["sni", "servername", "server-name"]) {
            tls["server_name"] = serverName
        }
        if firstBoolean(
            options,
            keys: ["skip-cert-verify", "skip_certificate_verification", "allowinsecure", "insecure"]
        ) == true {
            tls["insecure"] = true
        }
        let alpn = firstNonEmpty(options, keys: ["alpn", "tls.alpn"])
            .map(stringList) ?? []
        if !alpn.isEmpty { tls["alpn"] = alpn }
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
        if let ech = try singBoxECH(options: options) {
            tls["ech"] = ech
        }
        return tls
    }

    /// Maps both Mihomo's ECH fields and the URI form used by some VLESS
    /// providers. Mihomo's static `config` is base64, while sing-box requires
    /// an `ECH CONFIGS` PEM block; query-only ECH must remain query-only.
    private func singBoxECH(options: [String: String]) throws -> [String: Any]? {
        let rawURI = nonEmpty(options["ech"])
        let explicitEnabled = firstBoolean(options, keys: ["ech-opts.enable", "ech.enabled"])
        let rawConfig = firstNonEmpty(options, keys: ["ech-opts.config", "ech.config"])
        let queryServerName = echQueryServerName(options: options)
        let hasECHDeclaration = rawURI != nil || rawConfig != nil || queryServerName != nil
        guard explicitEnabled != false, explicitEnabled == true || hasECHDeclaration else { return nil }

        var ech: [String: Any] = ["enabled": true]
        if let rawConfig {
            ech["config"] = [try echPEM(from: rawConfig)]
        } else if let rawURI, rawURI.contains("BEGIN") {
            ech["config"] = [try echPEM(from: rawURI)]
        }
        if let queryServerName { ech["query_server_name"] = queryServerName }
        return ech
    }

    private func echQueryServerName(node: NodeRecord, options: [String: String]) -> String? {
        if let value = echQueryServerName(options: options) { return value }
        guard firstBoolean(options, keys: ["ech-opts.enable", "ech.enabled"]) == true else {
            return nil
        }
        return firstNonEmpty(options, keys: ["sni", "servername", "server-name"])
            ?? (ipLiteral(node.endpointHost) == nil ? node.endpointHost : nil)
    }

    private func echDNSRequirement(
        node: NodeRecord,
        options: [String: String]
    ) throws -> ECHDNSRequirement? {
        guard let queryDomain = echQueryServerName(node: node, options: options) else {
            return nil
        }
        guard let raw = nonEmpty(options["ech"]),
              !raw.contains("BEGIN"),
              let resolverURL = echResolverURL(from: raw)
        else {
            return ECHDNSRequirement(queryDomain: queryDomain, resolver: .fallback)
        }
        guard resolverURL.scheme?.lowercased() == "https",
              let host = resolverURL.host?.lowercased(),
              !host.isEmpty,
              resolverURL.user == nil,
              resolverURL.password == nil,
              resolverURL.query == nil,
              resolverURL.fragment == nil
        else {
            throw CoreConfigurationError.unsupportedProxyOption("ech.resolver")
        }
        let port = resolverURL.port ?? 443
        guard (1...65_535).contains(port) else {
            throw CoreConfigurationError.unsupportedProxyOption("ech.resolver")
        }
        let path = resolverURL.path.isEmpty ? "/dns-query" : resolverURL.path
        return ECHDNSRequirement(
            queryDomain: queryDomain,
            resolver: .https(host: host, port: port, path: path)
        )
    }

    private func echResolverURL(from raw: String) -> URLComponents? {
        let patterns = ["+https://", " https://", "+http://", " http://"]
        guard let range = patterns.compactMap({ pattern in
            raw.range(of: pattern, options: [.caseInsensitive])
        }).min(by: { $0.lowerBound < $1.lowerBound }) else { return nil }
        let schemeStart = raw.index(range.lowerBound, offsetBy: 1)
        return URLComponents(string: String(raw[schemeStart...]))
    }

    private func echQueryServerName(options: [String: String]) -> String? {
        if let value = firstNonEmpty(
            options,
            keys: ["ech-opts.query-server-name", "ech.query-server-name", "ech.query_server_name"]
        ) {
            return value.lowercased()
        }
        guard let raw = nonEmpty(options["ech"]), !raw.contains("BEGIN") else { return nil }
        let separators = ["+https://", " https://", "+http://", " http://"]
        let boundary = separators.compactMap {
            raw.range(of: $0, options: [.caseInsensitive])?.lowerBound
        }.min()
        let name = boundary.map { String(raw[..<$0]) } ?? raw
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed.lowercased()
    }

    private func echPEM(from raw: String) throws -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains("-----BEGIN ECH CONFIGS-----"),
           trimmed.contains("-----END ECH CONFIGS-----") {
            return trimmed
        }
        if trimmed.contains("-----BEGIN") {
            throw CoreConfigurationError.unsupportedProxyOption("ech.config")
        }
        guard let data = strictBase64Data(trimmed), !data.isEmpty else {
            throw CoreConfigurationError.unsupportedProxyOption("ech.config")
        }
        let body = data.base64EncodedString(options: [.lineLength64Characters, .endLineWithLineFeed])
            .trimmingCharacters(in: .newlines)
        return "-----BEGIN ECH CONFIGS-----\n\(body)\n-----END ECH CONFIGS-----"
    }

    private func strictBase64Data(_ raw: String) -> Data? {
        var value = raw
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        guard value.unicodeScalars.allSatisfy({
            CharacterSet.alphanumerics.contains($0)
                || "+/=".unicodeScalars.contains($0)
                || CharacterSet.whitespacesAndNewlines.contains($0)
        }) else { return nil }
        let remainder = value.filter { !$0.isWhitespace }.count % 4
        if remainder != 0 { value.append(String(repeating: "=", count: 4 - remainder)) }
        return Data(base64Encoded: value)
    }

    private func ipLiteral(_ value: String) -> IPAddress? {
        IPv4Address(value) ?? IPv6Address(value)
    }

    private func singBoxTransport(
        node: NodeRecord,
        options: [String: String]
    ) throws -> [String: Any]? {
        switch node.transport {
        case .tcp:
            return nil
        case .quic:
            // Hysteria2 uses QUIC as its protocol transport and therefore has
            // no nested V2Ray transport. VMess/VLESS `type=quic` does.
            return node.protocolKind == .hysteria2 ? nil : ["type": "quic"]
        case .http:
            var value: [String: Any] = [
                "type": "http",
                "path": firstNonEmpty(
                    options,
                    keys: ["path", "h2-opts.path", "http-opts.path"]
                ) ?? "/",
            ]
            let hosts = firstNonEmpty(
                options,
                keys: ["host", "h2-opts.host", "http-opts.host"]
            ).map(stringList) ?? []
            if !hosts.isEmpty { value["host"] = hosts }
            if let method = firstNonEmpty(options, keys: ["method", "http-opts.method"]) {
                value["method"] = method
            }
            return value
        case .webSocket:
            var value: [String: Any] = [
                "type": "ws",
                "path": options["path"] ?? options["ws-opts.path"] ?? "/",
            ]
            if let host = firstNonEmpty(options, keys: ["host", "ws-opts.headers.host"]) {
                value["headers"] = ["Host": host]
            }
            if let earlyData = firstInteger(
                options,
                keys: ["ed", "max-early-data", "ws-opts.max-early-data"]
            ), earlyData >= 0 {
                value["max_early_data"] = earlyData
            }
            if let header = firstNonEmpty(
                options,
                keys: ["eh", "early-data-header-name", "ws-opts.early-data-header-name"]
            ) {
                value["early_data_header_name"] = header
            }
            return value
        case .grpc:
            return [
                "type": "grpc",
                "service_name": firstNonEmpty(options, keys: ["servicename", "grpc-opts.grpc-service-name"]) ?? "",
            ]
        case .httpUpgrade:
            var value: [String: Any] = [
                "type": "httpupgrade",
                "path": firstNonEmpty(
                    options,
                    keys: ["path", "http-upgrade-opts.path", "httpupgrade-opts.path"]
                ) ?? "/",
            ]
            if let host = firstNonEmpty(
                options,
                keys: [
                    "host", "http-upgrade-opts.host", "httpupgrade-opts.host",
                    "http-upgrade-opts.headers.host", "httpupgrade-opts.headers.host",
                ]
            ) {
                value["host"] = host
            }
            return value
        case .splitHTTP:
            // The pinned sing-box 1.13 runtime intentionally does not expose
            // XHTTP/splitHTTP. Silently compiling it as raw TCP produces a
            // selectable node that can never speak the provider's transport.
            throw CoreConfigurationError.unsupportedProxyOption("transport.xhttp")
        }
    }

    private func normalized(_ values: [String: String]) -> [String: String] {
        Dictionary(values.map { ($0.key.lowercased(), $0.value) }, uniquingKeysWith: { _, rhs in rhs })
    }

    private func firstBoolean(_ values: [String: String], keys: [String]) -> Bool? {
        for key in keys {
            switch values[key]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "true", "yes", "1", "on": return true
            case "false", "no", "0", "off": return false
            default: continue
            }
        }
        return nil
    }

    private func firstInteger(_ values: [String: String], keys: [String]) -> Int? {
        for key in keys {
            guard let value = nonEmpty(values[key]) else { continue }
            if let integer = Int(value) { return integer }
            if let number = Double(value) { return Int(number.rounded()) }
        }
        return nil
    }

    private func stringList(_ raw: String) -> [String] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let body: Substring
        if trimmed.hasPrefix("["), trimmed.hasSuffix("]") {
            body = trimmed.dropFirst().dropLast()
        } else {
            body = Substring(trimmed)
        }
        return body.split(separator: ",", omittingEmptySubsequences: true).compactMap { item in
            let value = item.trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            return value.isEmpty ? nil : value
        }
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
