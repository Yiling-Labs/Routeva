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
            profiles: profiles,
            dnsBootstrapAddressMap: [
                "first.example.invalid": ["203.0.113.11"],
                "second.example.invalid": ["203.0.113.12"],
            ]
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
        for outbound in outbounds.prefix(2) {
            XCTAssertEqual(
                (outbound["domain_resolver"] as? [String: Any])?["server"] as? String,
                "dns-endpoint"
            )
        }
        let dns = try XCTUnwrap(object["dns"] as? [String: Any])
        let servers = try XCTUnwrap(dns["servers"] as? [[String: Any]])
        let endpointResolver = try XCTUnwrap(servers.first(where: {
            $0["tag"] as? String == "dns-endpoint"
        }))
        let predefined = try XCTUnwrap(
            endpointResolver["predefined"] as? [String: [String]]
        )
        XCTAssertEqual(predefined["first.example.invalid"], ["203.0.113.11"])
        XCTAssertEqual(predefined["second.example.invalid"], ["203.0.113.12"])
        XCTAssertTrue(compiled.manifest.directRouteAddresses.contains("203.0.113.11"))
        XCTAssertTrue(compiled.manifest.directRouteAddresses.contains("203.0.113.12"))
    }

    func testPreservesQueryBasedECHAndConvertsMihomoBase64Config() throws {
        let fixture = makeFixture(protocolKind: .vless, transport: .webSocket, security: .tls)

        let fromURI = try compiler.compile(
            manifest: fixture.manifest,
            node: fixture.node,
            credential: ProxyCredentialEnvelope(
                authentication: ["uuid": "11111111-2222-3333-4444-555555555555"],
                options: [
                    "sni": "edge.example.invalid",
                    "fp": "chrome",
                    "host": "edge.example.invalid",
                    "path": "/",
                    "ech": "cloudflare-ech.com+https://dns.alidns.com/dns-query",
                ]
            ),
            for: .singBox
        )
        XCTAssertTrue(fromURI.json.contains("\"ech\":"))
        XCTAssertTrue(fromURI.json.contains("\"query_server_name\":\"cloudflare-ech.com\""))
        XCTAssertTrue(fromURI.json.contains("\"query_type\":[\"HTTPS\"]"))
        XCTAssertTrue(fromURI.manifest.directRouteAddresses.contains("223.5.5.5"))

        let clashFixture = makeFixture(protocolKind: .vless, transport: .webSocket, security: .tls)
        let fromClash = try compiler.compile(
            manifest: clashFixture.manifest,
            node: clashFixture.node,
            credential: ProxyCredentialEnvelope(
                authentication: ["uuid": "11111111-2222-3333-4444-555555555555"],
                options: [
                    "sni": "edge.example.invalid",
                    "ech-opts.enable": "true",
                    "ech-opts.query-server-name": "cloudflare-ech.com",
                ]
            ),
            for: .singBox
        )
        XCTAssertTrue(fromClash.json.contains("\"ech\":"))
        XCTAssertTrue(fromClash.json.contains("\"query_server_name\":\"cloudflare-ech.com\""))
        XCTAssertTrue(fromClash.manifest.directRouteAddresses.contains("223.5.5.5"))

        let base64 = Data([0, 4, 1, 2, 3, 4]).base64EncodedString()
        let fromBase64 = try compiler.compile(
            manifest: fixture.manifest,
            node: fixture.node,
            credential: ProxyCredentialEnvelope(
                authentication: ["uuid": "11111111-2222-3333-4444-555555555555"],
                options: [
                    "sni": "edge.example.invalid",
                    "ech-opts.enable": "true",
                    "ech-opts.config": base64,
                ]
            ),
            for: .singBox
        )
        XCTAssertTrue(fromBase64.json.contains("\"ech\":{"))
        XCTAssertTrue(fromBase64.json.contains("BEGIN ECH CONFIGS"))

        XCTAssertThrowsError(try compiler.compile(
            manifest: fixture.manifest,
            node: fixture.node,
            credential: ProxyCredentialEnvelope(
                authentication: ["uuid": "11111111-2222-3333-4444-555555555555"],
                options: ["ech-opts.enable": "true", "ech-opts.config": "not/base64!"]
            ),
            for: .singBox
        )) { error in
            XCTAssertEqual(error as? CoreConfigurationError, .unsupportedProxyOption("ech.config"))
        }
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

    func testCompilesCommonTLSWebSocketHTTPAndHysteria2Options() throws {
        let webSocket = makeFixture(protocolKind: .vless, transport: .webSocket, security: .tls)
        let compiledWebSocket = try compiler.compile(
            manifest: webSocket.manifest,
            node: webSocket.node,
            credential: ProxyCredentialEnvelope(
                authentication: ["uuid": "11111111-2222-3333-4444-555555555555"],
                options: [
                    "sni": "edge.example.invalid",
                    "skip-cert-verify": "true",
                    "alpn": "[h2, http/1.1]",
                    "ws-opts.max-early-data": "2048",
                    "ws-opts.early-data-header-name": "Sec-WebSocket-Protocol",
                ]
            ),
            for: .singBox
        )
        let wsObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(compiledWebSocket.json.utf8)) as? [String: Any]
        )
        let wsOutbound = try XCTUnwrap((wsObject["outbounds"] as? [[String: Any]])?.first)
        let tls = try XCTUnwrap(wsOutbound["tls"] as? [String: Any])
        XCTAssertEqual(tls["insecure"] as? Bool, true)
        XCTAssertEqual(tls["alpn"] as? [String], ["h2", "http/1.1"])
        let transport = try XCTUnwrap(wsOutbound["transport"] as? [String: Any])
        XCTAssertEqual(transport["max_early_data"] as? Int, 2_048)
        XCTAssertEqual(transport["early_data_header_name"] as? String, "Sec-WebSocket-Protocol")

        let http = makeFixture(protocolKind: .vless, transport: .http, security: .tls)
        let compiledHTTP = try compiler.compile(
            manifest: http.manifest,
            node: http.node,
            credential: ProxyCredentialEnvelope(
                authentication: ["uuid": "11111111-2222-3333-4444-555555555555"],
                options: ["host": "edge.example.invalid", "path": "/h2"]
            ),
            for: .singBox
        )
        XCTAssertTrue(compiledHTTP.json.contains("\"transport\":{\"host\":[\"edge.example.invalid\"],\"path\":\"\\/h2\",\"type\":\"http\"}"))

        let hysteria2 = makeFixture(protocolKind: .hysteria2, transport: .quic, security: .tls)
        let compiledHysteria2 = try compiler.compile(
            manifest: hysteria2.manifest,
            node: hysteria2.node,
            credential: ProxyCredentialEnvelope(
                authentication: ["password": "synthetic-password"],
                options: [
                    "obfs": "salamander", "obfs-password": "obfs-secret",
                    "up": "50", "down": "100", "ports": "20000-30000",
                    "hop-interval": "30",
                ]
            ),
            for: .singBox
        )
        XCTAssertTrue(compiledHysteria2.json.contains("\"obfs\":{\"password\":\"obfs-secret\",\"type\":\"salamander\"}"))
        XCTAssertTrue(compiledHysteria2.json.contains("\"server_ports\":[\"20000-30000\"]"))
        XCTAssertTrue(compiledHysteria2.json.contains("\"hop_interval\":\"30s\""))
        XCTAssertTrue(compiledHysteria2.json.contains("\"up_mbps\":50"))
        XCTAssertTrue(compiledHysteria2.json.contains("\"down_mbps\":100"))
    }

    func testCompilesV2RayQUICAndFailsClosedForUnsupportedXHTTP() throws {
        let quic = makeFixture(protocolKind: .vmess, transport: .quic, security: .tls)
        let compiledQUIC = try compiler.compile(
            manifest: quic.manifest,
            node: quic.node,
            credential: ProxyCredentialEnvelope(
                authentication: ["uuid": "11111111-2222-3333-4444-555555555555"]
            ),
            for: .singBox
        )
        XCTAssertTrue(compiledQUIC.json.contains("\"transport\":{\"type\":\"quic\"}"))

        let xhttp = makeFixture(protocolKind: .vless, transport: .splitHTTP, security: .tls)
        XCTAssertThrowsError(try compiler.compile(
            manifest: xhttp.manifest,
            node: xhttp.node,
            credential: ProxyCredentialEnvelope(
                authentication: ["uuid": "11111111-2222-3333-4444-555555555555"]
            ),
            for: .singBox
        )) { error in
            XCTAssertEqual(
                error as? CoreConfigurationError,
                .coreUnsupported(.singBox)
            )
        }
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
        XCTAssertEqual(resolver["server"] as? String, "dns-proxy")
        let routeRules = try XCTUnwrap(route["rules"] as? [[String: Any]])
        XCTAssertEqual(routeRules.first?["port"] as? Int, 53)
        XCTAssertEqual(routeRules.first?["action"] as? String, "hijack-dns")
        let dns = try XCTUnwrap(object["dns"] as? [String: Any])
        let servers = try XCTUnwrap(dns["servers"] as? [[String: Any]])
        XCTAssertNil(servers.first(where: { $0["tag"] as? String == "dns-bootstrap" }))
        let real = try XCTUnwrap(servers.first(where: { $0["tag"] as? String == "dns-real" }))
        XCTAssertEqual(real["type"] as? String, "local")
        XCTAssertNil(real["server"])
        XCTAssertNil(real["detour"])
        let proxyDNS = try XCTUnwrap(servers.first(where: { $0["tag"] as? String == "dns-proxy" }))
        XCTAssertEqual(proxyDNS["type"] as? String, "https")
        XCTAssertEqual(proxyDNS["server"] as? String, "9.9.9.10")
        XCTAssertEqual(proxyDNS["detour"] as? String, "proxy")
        XCTAssertNil(servers.first(where: { $0["type"] as? String == "fakeip" }))
        XCTAssertEqual(dns["final"] as? String, "dns-proxy")
        XCTAssertEqual(dns["reverse_mapping"] as? Bool, true)

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

    func testCompatibilityDNSUsesDirectUDPResolverWithoutFakeIP() throws {
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
        XCTAssertTrue(singBox.json.contains("\"tag\":\"dns-real\""))
        XCTAssertTrue(singBox.json.contains("\"type\":\"udp\""))
        XCTAssertTrue(singBox.json.contains("\"server\":\"223.5.5.5\""))
        XCTAssertFalse(singBox.json.contains("\"type\":\"fakeip\""))
        XCTAssertFalse(singBox.json.contains("9.9.9.10"))
        XCTAssertFalse(singBox.json.contains("\"detour\":\"proxy\""))
        XCTAssertTrue(singBox.manifest.directRouteAddresses.contains("223.5.5.5"))
    }

    func testPrivacyDNSUsesProxyInProxyModesAndDirectResolverInDirectMode() throws {
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
        XCTAssertFalse(global.json.contains("\"type\":\"fakeip\""))
        XCTAssertTrue(global.json.contains("\"detour\":\"proxy\""))
        XCTAssertFalse(global.manifest.directRouteAddresses.contains("9.9.9.10"))
        XCTAssertTrue(direct.json.contains("\"type\":\"https\""))
        XCTAssertTrue(direct.json.contains("\"server\":\"9.9.9.10\""))
        XCTAssertFalse(direct.json.contains("\"type\":\"fakeip\""))
        XCTAssertFalse(direct.json.contains("\"detour\":\"proxy\""))
        XCTAssertTrue(direct.manifest.directRouteAddresses.contains("9.9.9.10"))
    }

    func testAutomaticDNSSplitsProxyNamesThroughTheNode() throws {
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

        let globalDNS = try XCTUnwrap(
            (JSONSerialization.jsonObject(with: Data(global.json.utf8)) as? [String: Any])?["dns"]
                as? [String: Any]
        )
        let globalServers = try XCTUnwrap(globalDNS["servers"] as? [[String: Any]])
        XCTAssertEqual(globalDNS["final"] as? String, "dns-proxy")
        XCTAssertEqual(
            globalServers.first(where: { $0["tag"] as? String == "dns-real" })?["type"] as? String,
            "local"
        )
        let proxyDNS = try XCTUnwrap(globalServers.first(where: { $0["tag"] as? String == "dns-proxy" }))
        XCTAssertEqual(proxyDNS["type"] as? String, "https")
        XCTAssertEqual(proxyDNS["server"] as? String, "9.9.9.10")
        XCTAssertEqual(proxyDNS["detour"] as? String, "proxy")
        XCTAssertFalse(global.json.contains("223.5.5.5"))
        XCTAssertFalse(global.json.contains("\"type\":\"fakeip\""))
        XCTAssertFalse(global.manifest.directRouteAddresses.contains("9.9.9.10"))

        XCTAssertTrue(direct.json.contains("\"type\":\"local\""))
        XCTAssertFalse(direct.json.contains("\"tag\":\"dns-proxy\""))
        XCTAssertFalse(direct.json.contains("223.5.5.5"))
        XCTAssertFalse(direct.json.contains("\"type\":\"fakeip\""))
        XCTAssertFalse(direct.json.contains("9.9.9.10"))
        XCTAssertFalse(direct.json.contains("\"detour\":\"proxy\""))
    }

    func testRuntimeManifestPrioritizesCompilerRequiredRoutesAtTheAddressLimit() throws {
        let base = makeFixture(protocolKind: .vless, transport: .webSocket, security: .tls)
        let fixture = (
            manifest: base.manifest,
            node: NodeRecord(
                id: base.node.id,
                subscriptionID: base.node.subscriptionID,
                sortIndex: base.node.sortIndex,
                displayName: base.node.displayName,
                protocolKind: base.node.protocolKind,
                transport: base.node.transport,
                security: base.node.security,
                requiresUDP: base.node.requiresUDP,
                endpointHost: "203.0.113.10",
                endpointPort: base.node.endpointPort,
                credentialReference: base.node.credentialReference
            )
        )
        let manifest = RuntimeManifest(
            corePolicy: .automatic,
            profile: fixture.manifest.profile,
            directRouteAddresses: (0..<DirectRouteAddressValidator.maximumAddressCount).map {
                "2001:db8::\(String($0, radix: 16))"
            }
        )

        let compiled = try compiler.compile(
            manifest: manifest,
            node: fixture.node,
            credential: ProxyCredentialEnvelope(
                authentication: ["uuid": "11111111-2222-3333-4444-555555555555"],
                options: [
                    "sni": "edge.example.invalid",
                    "ech-opts.enable": "true",
                    "ech-opts.query-server-name": "cloudflare-ech.com",
                ]
            ),
            for: .singBox
        )

        XCTAssertEqual(
            compiled.manifest.directRouteAddresses.count,
            DirectRouteAddressValidator.maximumAddressCount
        )
        XCTAssertTrue(compiled.manifest.directRouteAddresses.contains("223.5.5.5"))
        XCTAssertTrue(compiled.manifest.directRouteAddresses.contains(fixture.node.endpointHost))
    }

    func testCompilesVLESSWebSocketTLSFromURIOptions() throws {
        let parsed = try SubscriptionParser().parse(
            """
            vless://11111111-2222-3333-4444-555555555555@203.0.113.10:443?\
            security=tls&type=ws&ech=cloudflare-ech.com+https://dns.alidns.com/dns-query\
            &host=edge.example.invalid&fp=chrome&sni=edge.example.invalid&path=/
            """
        )
        let node = parsed.nodes[0]
        let record = NodeRecord(
            id: UUID(),
            subscriptionID: UUID(),
            sortIndex: 0,
            displayName: node.displayName,
            protocolKind: node.protocolKind,
            transport: node.transport,
            security: node.security,
            requiresUDP: node.requiresUDP,
            endpointHost: node.endpointHost,
            endpointPort: node.endpointPort,
            credentialReference: "vless-ws"
        )
        let manifest = RuntimeManifest(
            corePolicy: .automatic,
            profile: RuntimeProfile(
                id: record.id,
                protocolKind: record.protocolKind,
                transport: record.transport,
                security: record.security,
                requiresUDP: record.requiresUDP,
                credential: SecretReference(keychainIdentifier: record.credentialReference)
            )
        )
        let compiled = try compiler.compile(
            manifest: manifest,
            node: record,
            credential: node.credential,
            for: .singBox
        )
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(compiled.json.utf8)) as? [String: Any]
        )
        let outbound = try XCTUnwrap(
            (object["outbounds"] as? [[String: Any]])?.first
        )
        XCTAssertEqual(outbound["type"] as? String, "vless")
        XCTAssertEqual(outbound["server"] as? String, "203.0.113.10")
        XCTAssertEqual(outbound["packet_encoding"] as? String, "xudp")
        let tls = try XCTUnwrap(outbound["tls"] as? [String: Any])
        XCTAssertEqual(tls["server_name"] as? String, "edge.example.invalid")
        XCTAssertEqual((tls["utls"] as? [String: Any])?["fingerprint"] as? String, "chrome")
        let ech = try XCTUnwrap(tls["ech"] as? [String: Any])
        XCTAssertEqual(ech["enabled"] as? Bool, true)
        XCTAssertEqual(ech["query_server_name"] as? String, "cloudflare-ech.com")
        let transport = try XCTUnwrap(outbound["transport"] as? [String: Any])
        XCTAssertEqual(transport["type"] as? String, "ws")
        XCTAssertEqual(transport["path"] as? String, "/")
        XCTAssertEqual((transport["headers"] as? [String: Any])?["Host"] as? String, "edge.example.invalid")
    }

    func testCompatibilityPreservesECHAndRoutesItsHTTPSLookupToBootstrap() throws {
        let fixture = makeFixture(protocolKind: .vless, transport: .webSocket, security: .tls)
        let manifest = RuntimeManifest(
            corePolicy: .automatic,
            profile: fixture.manifest.profile,
            dnsPreset: .compatibility
        )
        let compiled = try compiler.compile(
            manifest: manifest,
            node: fixture.node,
            credential: ProxyCredentialEnvelope(
                authentication: ["uuid": "11111111-2222-3333-4444-555555555555"],
                options: [
                    "sni": "edge.example.invalid",
                    "ech": "cloudflare-ech.com+https://dns.alidns.com/dns-query",
                ]
            ),
            for: .singBox
        )
        XCTAssertTrue(compiled.json.contains("\"ech\":"))
        XCTAssertTrue(compiled.json.contains("cloudflare-ech.com"))
        XCTAssertTrue(compiled.json.contains("\"server\":\"dns-bootstrap\""))
        XCTAssertTrue(compiled.json.contains("\"server\":\"223.5.5.5\""))
        XCTAssertTrue(compiled.json.contains("\"server_name\":\"dns.alidns.com\""))
        XCTAssertTrue(compiled.json.contains("\"query_type\":[\"HTTPS\"]"))
        XCTAssertFalse(compiled.json.contains("\"type\":\"fakeip\""))
        XCTAssertTrue(compiled.manifest.directRouteAddresses.contains("223.5.5.5"))
    }

    func testECHUsesProviderDeclaredDoHWithPreflightAddress() throws {
        let fixture = makeFixture(protocolKind: .vless, transport: .webSocket, security: .tls)
        let manifest = RuntimeManifest(
            corePolicy: .automatic,
            profile: fixture.manifest.profile,
            dnsBootstrapAddressMap: ["resolver.example": ["203.0.113.53"]]
        )
        let compiled = try compiler.compile(
            manifest: manifest,
            node: fixture.node,
            credential: ProxyCredentialEnvelope(
                authentication: ["uuid": "11111111-2222-3333-4444-555555555555"],
                options: [
                    "sni": "edge.example.invalid",
                    "ech": "cloudflare-ech.com+https://resolver.example:8443/custom-dns",
                ]
            ),
            for: .singBox
        )
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(compiled.json.utf8)) as? [String: Any]
        )
        let dns = try XCTUnwrap(object["dns"] as? [String: Any])
        let servers = try XCTUnwrap(dns["servers"] as? [[String: Any]])
        let bootstrap = try XCTUnwrap(servers.first(where: {
            $0["tag"] as? String == "dns-bootstrap"
        }))
        XCTAssertEqual(bootstrap["server"] as? String, "203.0.113.53")
        XCTAssertEqual(bootstrap["server_port"] as? Int, 8443)
        XCTAssertEqual(bootstrap["path"] as? String, "/custom-dns")
        XCTAssertEqual(
            (bootstrap["tls"] as? [String: Any])?["server_name"] as? String,
            "resolver.example"
        )
        XCTAssertFalse(servers.contains { $0["server"] as? String == "223.5.5.5" })
        XCTAssertTrue(compiled.manifest.directRouteAddresses.contains("203.0.113.53"))
    }

    func testECHFailsClosedForUnresolvedOrInsecureDeclaredResolver() throws {
        let fixture = makeFixture(protocolKind: .vless, transport: .webSocket, security: .tls)
        for raw in [
            "cloudflare-ech.com+https://unresolved.example/dns-query",
            "cloudflare-ech.com+http://203.0.113.53/dns-query",
        ] {
            XCTAssertThrowsError(try compiler.compile(
                manifest: fixture.manifest,
                node: fixture.node,
                credential: ProxyCredentialEnvelope(
                    authentication: ["uuid": "11111111-2222-3333-4444-555555555555"],
                    options: ["sni": "edge.example.invalid", "ech": raw]
                ),
                for: .singBox
            )) { error in
                guard case let CoreConfigurationError.unsupportedProxyOption(option) = error else {
                    return XCTFail("Unexpected error: \(error)")
                }
                XCTAssertTrue(["ech.resolver", "ech.resolver_unresolved"].contains(option))
            }
        }
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

        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(singBox.json.utf8)) as? [String: Any]
        )
        let dns = try XCTUnwrap(object["dns"] as? [String: Any])
        XCTAssertEqual(dns["final"] as? String, "dns-proxy")
        let dnsRules = try XCTUnwrap(dns["rules"] as? [[String: Any]])
        XCTAssertEqual(
            dnsRules.first(where: {
                ($0["domain"] as? [String]) == ["forced.example"]
            })?["server"] as? String,
            "dns-real"
        )
        XCTAssertEqual(
            dnsRules.first(where: {
                ($0["domain_suffix"] as? [String]) == ["direct.example"]
            })?["server"] as? String,
            "dns-real"
        )
        XCTAssertNil(dnsRules.first(where: {
            ($0["domain_suffix"] as? [String]) == ["proxy.example"]
        }))
        XCTAssertEqual(
            dnsRules.first(where: {
                ($0["domain_keyword"] as? [String]) == ["blocked"]
            })?["server"] as? String,
            "dns-real"
        )
    }

    func testAutomaticSmartResolvesUnlistedNamesThroughTheNode() throws {
        let fixture = makeFixture(protocolKind: .trojan, transport: .tcp, security: .tls)
        let manifest = RuntimeManifest(
            corePolicy: .automatic,
            profile: fixture.manifest.profile,
            routingMode: .automatic,
            dnsPreset: .automatic,
            providerRoutePolicy: ProviderRoutePolicy(
                rules: [
                    .init(match: .domainSuffix("baidu.com"), action: .direct),
                    .init(match: .domainKeyword("google"), action: .proxyCurrentNode),
                    .init(match: .domainKeyword("."), action: .proxyCurrentNode),
                    .init(
                        match: .geoIP("CN"),
                        action: .direct,
                        requiresDestinationResolution: true
                    ),
                ],
                defaultAction: .proxyCurrentNode
            )
        )
        let compiled = try compiler.compile(
            manifest: manifest,
            node: fixture.node,
            credential: ProxyCredentialEnvelope(
                authentication: ["password": "synthetic-password"],
                options: ["sni": "node.example.invalid"]
            ),
            for: .singBox
        )
        let dns = try XCTUnwrap(
            (JSONSerialization.jsonObject(with: Data(compiled.json.utf8)) as? [String: Any])?["dns"]
                as? [String: Any]
        )
        XCTAssertEqual(dns["final"] as? String, "dns-proxy")
        let servers = try XCTUnwrap(dns["servers"] as? [[String: Any]])
        XCTAssertEqual(
            servers.first(where: { $0["tag"] as? String == "dns-proxy" })?["detour"] as? String,
            "proxy"
        )
        let dnsRules = try XCTUnwrap(dns["rules"] as? [[String: Any]])
        XCTAssertEqual(
            dnsRules.first(where: {
                ($0["domain_suffix"] as? [String]) == ["baidu.com"]
            })?["server"] as? String,
            "dns-real"
        )
        XCTAssertNil(dnsRules.first(where: {
            ($0["domain_keyword"] as? [String])?.contains("google") == true
        }))
        XCTAssertNil(dnsRules.first(where: {
            ($0["domain_keyword"] as? [String]) == ["."]
        }))
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

        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(singBox.json.utf8)) as? [String: Any]
        )
        let dns = try XCTUnwrap(object["dns"] as? [String: Any])
        XCTAssertEqual(dns["final"] as? String, "dns-proxy")
        XCTAssertEqual(
            (dns["servers"] as? [[String: Any]])?.first(where: {
                $0["tag"] as? String == "dns-proxy"
            })?["detour"] as? String,
            "proxy"
        )
        let dnsRules = dns["rules"] as? [[String: Any]] ?? []
        XCTAssertEqual(
            dnsRules.first(where: {
                ($0["domain_suffix"] as? [String]) == ["supported.example"]
            })?["server"] as? String,
            "dns-real"
        )
        XCTAssertNil(dnsRules.first(where: {
            ($0["domain_suffix"] as? [String]) == ["logical.example"]
        }))
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
        XCTAssertEqual(singBoxRules.count, 5, "DNS hijack, sniff, plus three bounded domain batches")
        XCTAssertEqual(singBoxRules[0]["action"] as? String, "hijack-dns")
        XCTAssertEqual(singBoxRules[1]["action"] as? String, "sniff")
        XCTAssertEqual(singBoxRules[2]["domain_suffix"] as? [String],
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

        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(singBox.json.utf8)) as? [String: Any]
        )
        let dns = try XCTUnwrap(object["dns"] as? [String: Any])
        XCTAssertEqual(dns["final"] as? String, "dns-real")
        let dnsRules = try XCTUnwrap(dns["rules"] as? [[String: Any]])
        XCTAssertEqual(
            dnsRules.first(where: {
                ($0["domain"] as? [String]) == ["forced.example"]
            })?["server"] as? String,
            "dns-proxy"
        )
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
