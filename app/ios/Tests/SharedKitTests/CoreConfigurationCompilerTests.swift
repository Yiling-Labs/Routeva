import CoreConfigKit
import DataKit
import Foundation
import SharedKit
import XCTest

final class CoreConfigurationCompilerTests: XCTestCase {
    private let compiler = CoreConfigurationCompiler()

    func testSingBoxCatalogCompilesStableNodeOutboundsAndSelector() throws {
        let subscriptionID = UUID()
        let firstID = UUID()
        let secondID = UUID()
        let first = NodeRecord(
            id: firstID,
            subscriptionID: subscriptionID,
            sortIndex: 0,
            displayName: "FIRST",
            protocolKind: .shadowsocks,
            transport: .tcp,
            security: .none,
            requiresUDP: true,
            endpointHost: "first.example.invalid",
            endpointPort: 443,
            credentialReference: "first-secret"
        )
        let second = NodeRecord(
            id: secondID,
            subscriptionID: subscriptionID,
            sortIndex: 1,
            displayName: "SECOND",
            protocolKind: .shadowsocks,
            transport: .tcp,
            security: .none,
            requiresUDP: true,
            endpointHost: "second.example.invalid",
            endpointPort: 8443,
            credentialReference: "second-secret"
        )
        let profiles = [first, second].map { node in
            RuntimeProfile(
                id: node.id,
                protocolKind: node.protocolKind,
                transport: node.transport,
                security: node.security,
                requiresUDP: node.requiresUDP,
                credential: SecretReference(keychainIdentifier: node.credentialReference)
            )
        }
        let manifest = RuntimeManifest(
            corePolicy: .singBox,
            profile: profiles[1],
            profiles: profiles
        )
        let compiled = try compiler.compile(
            manifest: manifest,
            nodes: [first, second],
            credentials: [
                firstID: ProxyCredentialEnvelope(authentication: [
                    "method": "aes-128-gcm", "password": "first-password",
                ]),
                secondID: ProxyCredentialEnvelope(authentication: [
                    "method": "aes-256-gcm", "password": "second-password",
                ]),
            ],
            for: .singBox
        )
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(compiled.json.utf8)) as? [String: Any]
        )
        let outbounds = try XCTUnwrap(object["outbounds"] as? [[String: Any]])
        let nodeTags = profiles.map { SingBoxNodeSelector.outboundTag(for: $0.id) }
        XCTAssertEqual(Array(outbounds.prefix(2).compactMap { $0["tag"] as? String }), nodeTags)
        let selector = try XCTUnwrap(outbounds.first(where: {
            $0["tag"] as? String == SingBoxNodeSelector.groupTag
        }))
        XCTAssertEqual(selector["type"] as? String, "selector")
        XCTAssertEqual(selector["outbounds"] as? [String], nodeTags)
        XCTAssertEqual(selector["default"] as? String, nodeTags[1])
        XCTAssertEqual(selector["interrupt_exist_connections"] as? Bool, true)
    }

    func testCompilesHysteria2ForSingBox() throws {
        let fixture = makeFixture(protocolKind: .hysteria2, transport: .quic, security: .tls)
        let credential = ProxyCredentialEnvelope(
            authentication: ["password": "synthetic-password"],
            options: ["sni": "hy2.example.invalid"]
        )

        let compiled = try compiler.compile(
            manifest: fixture.manifest,
            node: fixture.node,
            credential: credential,
            for: .singBox
        )

        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(compiled.json.utf8)) as? [String: Any]
        )
        let outbounds = try XCTUnwrap(object["outbounds"] as? [[String: Any]])
        XCTAssertEqual(outbounds.first?["type"] as? String, "hysteria2")
    }

    func testSingBoxTunRequestsPlatformDefaultRoutes() throws {
        let fixture = makeFixture(protocolKind: .shadowsocks, transport: .tcp, security: .none)
        let compiled = try compiler.compile(
            manifest: fixture.manifest,
            node: fixture.node,
            credential: ProxyCredentialEnvelope(authentication: [
                "method": "aes-128-gcm",
                "password": "synthetic-password",
            ]),
            for: .singBox
        )

        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(compiled.json.utf8)) as? [String: Any]
        )
        let inbounds = try XCTUnwrap(object["inbounds"] as? [[String: Any]])
        let tunInbound = try XCTUnwrap(inbounds.first)
        XCTAssertEqual(tunInbound["type"] as? String, "tun")
        XCTAssertEqual(tunInbound["auto_route"] as? Bool, true)
        XCTAssertEqual(tunInbound["mtu"] as? Int, 4_064)
        XCTAssertEqual(tunInbound["stack"] as? String, "gvisor")

        let route = try XCTUnwrap(object["route"] as? [String: Any])
        let resolver = try XCTUnwrap(route["default_domain_resolver"] as? [String: Any])
        XCTAssertEqual(resolver["server"] as? String, "dns-bootstrap")
        let routeRules = try XCTUnwrap(route["rules"] as? [[String: Any]])
        XCTAssertEqual(routeRules.first?["port"] as? Int, 53)
        XCTAssertEqual(routeRules.first?["action"] as? String, "hijack-dns")
        let dns = try XCTUnwrap(object["dns"] as? [String: Any])
        let servers = try XCTUnwrap(dns["servers"] as? [[String: Any]])
        XCTAssertEqual(servers.first?["tag"] as? String, "dns-bootstrap")
        XCTAssertEqual(servers.first?["type"] as? String, "local")
        XCTAssertNil(servers.first?["detour"])
        XCTAssertNil(servers.first?["server"])
        XCTAssertEqual(servers.last?["tag"] as? String, "dns-remote")
        XCTAssertEqual(servers.last?["type"] as? String, "local")
        XCTAssertNil(servers.last?["server"])
        XCTAssertNil(servers.last?["detour"])

        let outbounds = try XCTUnwrap(object["outbounds"] as? [[String: Any]])
        let coreProbe = try XCTUnwrap(outbounds.first(where: {
            $0["tag"] as? String == "routeva-probe"
        }))
        XCTAssertEqual(coreProbe["type"] as? String, "urltest")
        XCTAssertEqual(coreProbe["outbounds"] as? [String], ["proxy", "reject"])
        XCTAssertEqual(
            coreProbe["url"] as? String,
            "https://routeva.yilinglabs.com/probe.txt"
        )
        XCTAssertEqual(coreProbe["interval"] as? String, "24h")
        XCTAssertEqual(coreProbe["idle_timeout"] as? String, "24h")
    }

    func testCompilesSupportedShadowsocksPluginsAndRejectsUnknownPlugins() throws {
        let fixture = makeFixture(protocolKind: .shadowsocks, transport: .tcp, security: .none)
        let authentication = [
            "method": "aes-128-gcm",
            "password": "synthetic-password",
        ]
        let obfs = try compiler.compile(
            manifest: fixture.manifest,
            node: fixture.node,
            credential: ProxyCredentialEnvelope(
                authentication: authentication,
                options: [
                    "plugin": "obfs",
                    "plugin-opts.mode": "tls",
                    "plugin-opts.host": "edge.example.invalid",
                ]
            ),
            for: .singBox
        )
        let obfsObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(obfs.json.utf8)) as? [String: Any]
        )
        let obfsOutbounds = try XCTUnwrap(obfsObject["outbounds"] as? [[String: Any]])
        XCTAssertEqual(obfsOutbounds.first?["plugin"] as? String, "obfs-local")
        XCTAssertEqual(
            obfsOutbounds.first?["plugin_opts"] as? String,
            "obfs=tls;obfs-host=edge.example.invalid"
        )

        let v2ray = try compiler.compile(
            manifest: fixture.manifest,
            node: fixture.node,
            credential: ProxyCredentialEnvelope(
                authentication: authentication,
                options: [
                    "plugin": "v2ray-plugin;tls;host=edge.example.invalid;path=/socket",
                ]
            ),
            for: .singBox
        )
        let v2rayObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(v2ray.json.utf8)) as? [String: Any]
        )
        let v2rayOutbounds = try XCTUnwrap(v2rayObject["outbounds"] as? [[String: Any]])
        XCTAssertEqual(v2rayOutbounds.first?["plugin"] as? String, "v2ray-plugin")
        XCTAssertEqual(
            v2rayOutbounds.first?["plugin_opts"] as? String,
            "host=edge.example.invalid;path=/socket;tls"
        )

        XCTAssertThrowsError(try compiler.compile(
            manifest: fixture.manifest,
            node: fixture.node,
            credential: ProxyCredentialEnvelope(
                authentication: authentication,
                options: ["plugin": "unsupported-plugin;mode=tls"]
            ),
            for: .singBox
        )) { error in
            XCTAssertEqual(
                error as? CoreConfigurationError,
                .unsupportedProxyPlugin("unsupported-plugin")
            )
        }
    }

    func testRejectsManifestNodeMismatch() {
        let fixture = makeFixture(protocolKind: .trojan, transport: .tcp, security: .tls)
        let otherNode = NodeRecord(
            id: UUID(),
            subscriptionID: fixture.node.subscriptionID,
            sortIndex: 0,
            displayName: "OTHER",
            protocolKind: .trojan,
            transport: .tcp,
            security: .tls,
            requiresUDP: true,
            endpointHost: "other.example.invalid",
            endpointPort: 443,
            credentialReference: fixture.node.credentialReference
        )
        XCTAssertThrowsError(try compiler.compile(
            manifest: fixture.manifest,
            node: otherNode,
            credential: ProxyCredentialEnvelope(authentication: ["password": "synthetic"]),
            for: .singBox
        )) { error in
            XCTAssertEqual(error as? CoreConfigurationError, .profileNodeMismatch)
        }
    }

    func testCompatibilityDNSUsesPhysicalNetworkResolverForReachability() throws {
        let fixture = makeFixture(protocolKind: .trojan, transport: .tcp, security: .tls)
        let manifest = RuntimeManifest(
            corePolicy: .automatic,
            profile: fixture.manifest.profile,
            dnsPreset: .compatibility
        )
        let credential = ProxyCredentialEnvelope(
            authentication: ["password": "synthetic-password"],
            options: ["sni": "node.example.invalid"]
        )

        let singBox = try compiler.compile(
            manifest: manifest, node: fixture.node, credential: credential, for: .singBox
        )
        XCTAssertTrue(singBox.json.contains("\"type\":\"local\""))
        XCTAssertFalse(singBox.json.contains("9.9.9.10"))
        XCTAssertFalse(singBox.json.contains("\"detour\":\"proxy\""))
    }

    func testPrivacyDNSUsesProxyDetourOutsideDirectMode() throws {
        let fixture = makeFixture(protocolKind: .trojan, transport: .tcp, security: .tls)
        let credential = ProxyCredentialEnvelope(
            authentication: ["password": "synthetic-password"],
            options: ["sni": "node.example.invalid"]
        )
        let globalManifest = RuntimeManifest(
            corePolicy: .automatic,
            profile: fixture.manifest.profile,
            routingMode: .global,
            dnsPreset: .privacy
        )
        let directManifest = RuntimeManifest(
            corePolicy: .automatic,
            profile: fixture.manifest.profile,
            routingMode: .direct,
            dnsPreset: .privacy
        )

        let global = try compiler.compile(
            manifest: globalManifest, node: fixture.node, credential: credential, for: .singBox
        )
        let direct = try compiler.compile(
            manifest: directManifest, node: fixture.node, credential: credential, for: .singBox
        )

        XCTAssertTrue(global.json.contains("\"type\":\"https\""))
        XCTAssertTrue(global.json.contains("\"server\":\"9.9.9.10\""))
        XCTAssertTrue(global.json.contains("\"server_name\":\"dns10.quad9.net\""))
        XCTAssertTrue(global.json.contains("\"detour\":\"proxy\""))
        XCTAssertTrue(direct.json.contains("\"type\":\"https\""))
        XCTAssertTrue(direct.json.contains("\"server\":\"9.9.9.10\""))
        XCTAssertFalse(direct.json.contains("\"detour\":\"proxy\""))
    }

    func testAutomaticDNSUsesSystemTunnelDefaultInEveryRoutingMode() throws {
        let fixture = makeFixture(protocolKind: .trojan, transport: .tcp, security: .tls)
        let credential = ProxyCredentialEnvelope(
            authentication: ["password": "synthetic-password"],
            options: ["sni": "node.example.invalid"]
        )
        let globalManifest = RuntimeManifest(
            corePolicy: .automatic,
            profile: fixture.manifest.profile,
            routingMode: .global,
            dnsPreset: .automatic
        )
        let directManifest = RuntimeManifest(
            corePolicy: .automatic,
            profile: fixture.manifest.profile,
            routingMode: .direct,
            dnsPreset: .automatic
        )

        let global = try compiler.compile(
            manifest: globalManifest, node: fixture.node, credential: credential, for: .singBox
        )
        let direct = try compiler.compile(
            manifest: directManifest, node: fixture.node, credential: credential, for: .singBox
        )

        XCTAssertTrue(global.json.contains("\"type\":\"local\""))
        XCTAssertFalse(global.json.contains("9.9.9.10"))
        XCTAssertFalse(global.json.contains("\"detour\":\"proxy\""))
        XCTAssertTrue(direct.json.contains("\"type\":\"local\""))
        XCTAssertFalse(direct.json.contains("9.9.9.10"))
        XCTAssertFalse(direct.json.contains("\"detour\":\"proxy\""))
    }

    func testBinarySmartCompilesDirectCurrentNodeAndReject() throws {
        let fixture = makeFixture(protocolKind: .trojan, transport: .tcp, security: .tls)
        let manifest = RuntimeManifest(
            corePolicy: .automatic,
            profile: fixture.manifest.profile,
            routingMode: .automatic,
            providerRoutePolicy: ProviderRoutePolicy(
                rules: [
                    .init(match: .domainSuffix("direct.example"), action: .direct),
                    .init(match: .domainSuffix("proxy.example"), action: .proxyCurrentNode),
                    .init(match: .domainKeyword("blocked"), action: .reject),
                ],
                defaultAction: .proxyCurrentNode
            ),
            domainOverrides: [
                .init(domain: "forced.example", action: .direct),
            ]
        )
        let credential = ProxyCredentialEnvelope(
            authentication: ["password": "synthetic-password"],
            options: ["sni": "node.example.invalid"]
        )

        let singBox = try compiler.compile(
            manifest: manifest, node: fixture.node, credential: credential, for: .singBox
        )

        XCTAssertTrue(singBox.json.contains("\"domain_suffix\":[\"proxy.example\"]"))
        XCTAssertTrue(singBox.json.contains("\"outbound\":\"proxy\""))
        XCTAssertTrue(singBox.json.contains("\"outbound\":\"direct\""))
        XCTAssertTrue(singBox.json.contains("\"outbound\":\"reject\""))
        XCTAssertTrue(singBox.json.contains("\"action\":\"route\""))

    }

    func testBinarySmartCompilesTypedRulesWithoutChangingProviderFinal() throws {
        let fixture = makeFixture(protocolKind: .trojan, transport: .tcp, security: .tls)
        let manifest = RuntimeManifest(
            corePolicy: .automatic,
            profile: fixture.manifest.profile,
            routingMode: .automatic,
            providerRoutePolicy: ProviderRoutePolicy(
                rules: [
                    .init(match: .domainSuffix("supported.example"), action: .direct),
                    .init(match: .domainSuffix("continue.example"), action: .continueMatching),
                    .init(match: .domainKeyword("blocked"), action: .reject),
                    .init(
                        match: .ipCIDR("10.0.0.0/8"),
                        action: .direct,
                        requiresDestinationResolution: true
                    ),
                    .init(match: .sourceIPCIDR("172.19.0.0/30"), action: .direct),
                    .init(match: .destinationPort("80/443/1000-2000"), action: .reject),
                    .init(match: .sourcePort("53"), action: .direct),
                    .init(match: .network("udp"), action: .direct),
                    .init(match: .protocolName("http"), action: .proxyCurrentNode),
                    .init(
                        match: .logical(
                            mode: .and,
                            rules: [.domainSuffix("logical.example"), .network("tcp")]
                        ),
                        action: .proxyCurrentNode
                    ),
                    .init(match: .ruleSet("provider-rules"), action: .reject),
                ],
                defaultAction: .direct,
                ruleSets: [
                    ProviderRuleSet(
                        tag: "provider-rules",
                        behavior: .domain,
                        source: .inline([.domainSuffix("ruleset.example")])
                    ),
                ]
            )
        )
        let credential = ProxyCredentialEnvelope(
            authentication: ["password": "synthetic-password"],
            options: ["sni": "node.example.invalid"]
        )

        let singBox = try compiler.compile(
            manifest: manifest, node: fixture.node, credential: credential, for: .singBox
        )
        XCTAssertTrue(singBox.json.contains("\"domain_suffix\":[\"supported.example\"]"))
        XCTAssertFalse(singBox.json.contains("continue.example"))
        XCTAssertTrue(singBox.json.contains("\"domain_keyword\":[\"blocked\"]"))
        XCTAssertTrue(singBox.json.contains("\"action\":\"resolve\""))
        XCTAssertTrue(singBox.json.contains("\"ip_cidr\""))
        XCTAssertTrue(singBox.json.contains("10.0.0.0"))
        XCTAssertTrue(singBox.json.contains("\"source_ip_cidr\""))
        XCTAssertTrue(singBox.json.contains("172.19.0.0"))
        XCTAssertTrue(singBox.json.contains("\"port\":[80,443]"))
        XCTAssertTrue(singBox.json.contains("\"port_range\":[\"1000:2000\"]"))
        XCTAssertTrue(singBox.json.contains("\"source_port\":[53]"))
        XCTAssertTrue(singBox.json.contains("\"action\":\"sniff\""))
        XCTAssertTrue(singBox.json.contains("\"protocol\":[\"http\"]"))
        XCTAssertTrue(singBox.json.contains("\"type\":\"logical\""))
        XCTAssertTrue(singBox.json.contains("ruleset.example"))
        XCTAssertTrue(singBox.json.contains("\"final\":\"direct\""))
    }

    func testBinarySmartRejectsContinueAsFinalInsteadOfChoosingAnEgress() throws {
        let fixture = makeFixture(protocolKind: .trojan, transport: .tcp, security: .tls)
        let manifest = RuntimeManifest(
            corePolicy: .singBox,
            profile: fixture.manifest.profile,
            routingMode: .automatic,
            providerRoutePolicy: ProviderRoutePolicy(
                rules: [],
                defaultAction: .continueMatching
            )
        )
        let credential = ProxyCredentialEnvelope(
            authentication: ["password": "synthetic-password"]
        )

        XCTAssertThrowsError(try compiler.compile(
            manifest: manifest,
            node: fixture.node,
            credential: credential,
            for: .singBox
        )) { error in
            XCTAssertEqual(
                error as? CoreConfigurationError,
                .unsupportedRouteRule("continue_as_final")
            )
        }
    }

    func testBinarySmartRejectsInvalidRuleInsteadOfSilentlyChangingPolicy() throws {
        let fixture = makeFixture(protocolKind: .trojan, transport: .tcp, security: .tls)
        let manifest = RuntimeManifest(
            corePolicy: .singBox,
            profile: fixture.manifest.profile,
            routingMode: .automatic,
            providerRoutePolicy: ProviderRoutePolicy(
                rules: [.init(match: .destinationPort("not-a-port"), action: .direct)],
                defaultAction: .direct
            )
        )
        let credential = ProxyCredentialEnvelope(authentication: ["password": "synthetic-password"])
        XCTAssertThrowsError(try compiler.compile(
            manifest: manifest,
            node: fixture.node,
            credential: credential,
            for: .singBox
        )) { error in
            XCTAssertEqual(
                error as? CoreConfigurationError,
                .unsupportedRouteRule("invalid_port:not-a-port")
            )
        }
    }

    func testBinarySmartBatchesLargeAdjacentDomainRunsWithoutChangingOrder() throws {
        let fixture = makeFixture(protocolKind: .trojan, transport: .tcp, security: .tls)
        let rules = (0..<1_025).map { index in
            ProviderRouteRule(
                match: .domainSuffix("domain-\(index).example"),
                action: .direct
            )
        }
        let manifest = RuntimeManifest(
            corePolicy: .automatic,
            profile: fixture.manifest.profile,
            routingMode: .automatic,
            providerRoutePolicy: ProviderRoutePolicy(
                rules: rules,
                defaultAction: .proxyCurrentNode
            )
        )
        let credential = ProxyCredentialEnvelope(
            authentication: ["password": "synthetic-password"],
            options: ["sni": "node.example.invalid"]
        )

        let singBox = try compiler.compile(
            manifest: manifest, node: fixture.node, credential: credential, for: .singBox
        )
        let singBoxObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(singBox.json.utf8)) as? [String: Any]
        )
        let singBoxRoute = try XCTUnwrap(singBoxObject["route"] as? [String: Any])
        let singBoxRules = try XCTUnwrap(singBoxRoute["rules"] as? [[String: Any]])
        XCTAssertEqual(singBoxRules.count, 4, "DNS hijack plus three bounded domain batches")
        XCTAssertEqual(singBoxRules[1]["domain_suffix"] as? [String],
                       rules.prefix(512).compactMap { rule in
                           if case let .domainSuffix(value) = rule.match { return value }
                           return nil
                       })

    }

    func testDirectModeKeepsProxyOverrideAndUsesDirectFinal() throws {
        let fixture = makeFixture(protocolKind: .trojan, transport: .tcp, security: .tls)
        let manifest = RuntimeManifest(
            corePolicy: .automatic,
            profile: fixture.manifest.profile,
            routingMode: .direct,
            providerRoutePolicy: ProviderRoutePolicy(
                rules: [.init(match: .domain("provider.example"), action: .reject)],
                defaultAction: .proxyCurrentNode
            ),
            domainOverrides: [.init(domain: "forced.example", action: .proxyCurrentNode)]
        )
        let credential = ProxyCredentialEnvelope(authentication: ["password": "synthetic-password"])
        let singBox = try compiler.compile(
            manifest: manifest, node: fixture.node, credential: credential, for: .singBox
        )

        XCTAssertTrue(singBox.json.contains("\"domain\":[\"forced.example\"]"))
        XCTAssertTrue(singBox.json.contains("\"final\":\"direct\""))
        XCTAssertFalse(singBox.json.contains("\"detour\":\"direct\""))
        XCTAssertFalse(singBox.json.contains("provider.example"))
    }

    private func makeFixture(
        protocolKind: ProxyProtocol,
        transport: TransportKind,
        security: SecurityKind
    ) -> (manifest: RuntimeManifest, node: NodeRecord) {
        let nodeID = UUID()
        let credentialReference = "synthetic-credential-\(nodeID.uuidString)"
        let node = NodeRecord(
            id: nodeID,
            subscriptionID: UUID(),
            sortIndex: 0,
            displayName: "TEST",
            protocolKind: protocolKind,
            transport: transport,
            security: security,
            requiresUDP: true,
            endpointHost: "node.example.invalid",
            endpointPort: 443,
            credentialReference: credentialReference
        )
        let manifest = RuntimeManifest(
            corePolicy: .automatic,
            profile: RuntimeProfile(
                id: nodeID,
                protocolKind: protocolKind,
                transport: transport,
                security: security,
                requiresUDP: true,
                credential: SecretReference(keychainIdentifier: credentialReference)
            )
        )
        return (manifest, node)
    }
}

final class CoreConfigurationRepositoryTests: XCTestCase {
    func testRepositoryReconstructsConfigFromManifestDatabaseAndSecretStore() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CoreConfigurationRepository-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let database = try RoutevaDatabase(databaseURL: directory.appendingPathComponent("test.sqlite"))
        let secrets = CompilerMemorySecretStore()

        let subscriptionID = UUID()
        let nodeID = UUID()
        let credentialReference = "credential-\(UUID().uuidString)"
        let node = NodeRecord(
            id: nodeID,
            subscriptionID: subscriptionID,
            sortIndex: 0,
            displayName: "TEST-TROJAN",
            protocolKind: .trojan,
            transport: .tcp,
            security: .tls,
            requiresUDP: true,
            endpointHost: "repository.example.invalid",
            endpointPort: 443,
            credentialReference: credentialReference
        )
        try await database.replaceSubscriptionAtomically(
            SubscriptionCandidate(
                subscription: SubscriptionRecord(
                    id: subscriptionID,
                    displayName: "Synthetic",
                    sourceKind: "synthetic",
                    sourceSecretReference: "source",
                    isActive: false
                ),
                nodes: [node]
            ),
            makeActive: true
        )
        let credential = ProxyCredentialEnvelope(
            authentication: ["password": "repository-secret"],
            options: ["sni": "repository.example.invalid"]
        )
        try await secrets.set(try JSONEncoder().encode(credential), for: credentialReference)

        let manifest = RuntimeManifest(
            corePolicy: .automatic,
            profile: RuntimeProfile(
                id: nodeID,
                protocolKind: .trojan,
                transport: .tcp,
                security: .tls,
                requiresUDP: true,
                credential: SecretReference(keychainIdentifier: credentialReference)
            )
        )
        try await database.saveRuntimeManifest(RuntimeManifestRecord(
            id: manifest.manifestID,
            schemaVersion: manifest.schemaVersion,
            manifestData: try JSONEncoder().encode(manifest),
            isCurrent: true
        ))

        let repository = CoreConfigurationRepository(database: database, secrets: secrets)
        let compiled = try await repository.load(manifestID: manifest.manifestID, for: .singBox)
        let currentCompiled = try await repository.loadCurrent(for: .singBox)

        XCTAssertTrue(compiled.json.contains("repository-secret"))
        XCTAssertEqual(currentCompiled.manifest, manifest)
        XCTAssertEqual(currentCompiled.json, compiled.json)
        let databaseBytes = try Data(contentsOf: database.databaseURL)
        XCTAssertNil(String(data: databaseBytes, encoding: .utf8)?.range(of: "repository-secret"))
    }
}

private actor CompilerMemorySecretStore: SecretStoring {
    private var values: [String: Data] = [:]

    func set(_ data: Data, for reference: String) throws { values[reference] = data }
    func data(for reference: String) throws -> Data {
        guard let value = values[reference] else { throw KeychainStoreError.notFound }
        return value
    }
    func remove(reference: String) throws { values.removeValue(forKey: reference) }
}
