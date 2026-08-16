@testable import DataKit
import Foundation
import SharedKit
import XCTest

final class SubscriptionParserTests: XCTestCase {
    private let parser = SubscriptionParser()

    func testParsesVLESSURIWithoutExposingCredentialInNodeMetadata() throws {
        let parsed = try parser.parse(
            "vless://11111111-2222-3333-4444-555555555555@example.invalid:443?security=reality&type=grpc&sni=edge.example.invalid#TEST-US"
        )

        XCTAssertEqual(parsed.nodes.count, 1)
        XCTAssertEqual(parsed.nodes[0].displayName, "TEST-US")
        XCTAssertEqual(parsed.nodes[0].protocolKind, .vless)
        XCTAssertEqual(parsed.nodes[0].transport, .grpc)
        XCTAssertEqual(parsed.nodes[0].security, .reality)
        XCTAssertEqual(parsed.nodes[0].endpointHost, "example.invalid")
        XCTAssertEqual(parsed.nodes[0].credential.authentication["uuid"], "11111111-2222-3333-4444-555555555555")
    }

    func testParsesVMessJSONAndBase64SubscriptionList() throws {
        let vmessObject: [String: Any] = [
            "v": "2",
            "ps": "TEST-VMESS",
            "add": "vmess.example.invalid",
            "port": "443",
            "id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
            "net": "ws",
            "tls": "tls",
            "path": "/synthetic",
        ]
        let vmessData = try JSONSerialization.data(withJSONObject: vmessObject, options: [.sortedKeys])
        let vmessURI = "vmess://\(vmessData.base64EncodedString())"
        let trojanURI = "trojan://synthetic-password@trojan.example.invalid:443?security=tls#TEST-TROJAN"
        let subscription = Data("\(vmessURI)\n\(trojanURI)".utf8).base64EncodedString()

        let parsed = try parser.parse(subscription, suggestedName: "Synthetic Provider")

        XCTAssertEqual(parsed.suggestedName, "Synthetic Provider")
        XCTAssertEqual(parsed.nodes.map(\.protocolKind), [.vmess, .trojan])
        XCTAssertEqual(parsed.nodes[0].transport, .webSocket)
        XCTAssertEqual(parsed.nodes[1].security, .tls)
    }

    func testParsesSIP008JSONAndSkipsMalformedServers() throws {
        let payload: [String: Any] = [
            "version": 1,
            "servers": [
                [
                    "id": "11111111-2222-3333-4444-555555555555",
                    "remarks": "SIP008-SS",
                    "server": "ss.example.invalid",
                    "server_port": 8_388,
                    "method": "chacha20-ietf-poly1305",
                    "password": "synthetic-password",
                    "plugin": "obfs-local",
                    "plugin_opts": "obfs=tls;obfs-host=https://edge.example.invalid",
                ],
                [
                    "id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
                    "remarks": "BROKEN",
                    "server": "broken.example.invalid",
                ],
            ],
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])

        let parsed = try parser.parse(data, suggestedName: "SIP008 Provider")

        XCTAssertEqual(parsed.suggestedName, "SIP008 Provider")
        XCTAssertEqual(parsed.nodes.count, 1)
        XCTAssertEqual(parsed.skippedNodeCount, 1)
        XCTAssertEqual(parsed.nodes[0].protocolKind, .shadowsocks)
        XCTAssertEqual(parsed.nodes[0].endpointHost, "ss.example.invalid")
        XCTAssertEqual(parsed.nodes[0].credential.authentication["method"], "chacha20-ietf-poly1305")
        XCTAssertEqual(parsed.nodes[0].credential.options["plugin"], "obfs-local")
        XCTAssertEqual(
            parsed.nodes[0].credential.options["plugin-opts"],
            "obfs=tls;obfs-host=https://edge.example.invalid"
        )
    }

    func testParsesFirstBatchProxyURIs() throws {
        let payload = [
            "anytls://synthetic-anytls@anytls.example.invalid:443?min-idle-session=2#ANYTLS",
            "socks5://synthetic-user:synthetic-pass@socks.example.invalid:1080?udp=false#SOCKS",
            "http://http-user:http-pass@http.example.invalid:8080#HTTP",
            "https://https-user:https-pass@https.example.invalid:8443?sni=edge.example.invalid#HTTPS",
            "tuic://11111111-2222-3333-4444-555555555555:tuic-pass@tuic.example.invalid:443?congestion-controller=bbr#TUIC",
        ].joined(separator: "\n")

        let parsed = try parser.parse(payload)

        XCTAssertEqual(parsed.nodes.map(\.protocolKind), [.anyTLS, .socks5, .http, .http, .tuic])
        XCTAssertEqual(parsed.nodes.map(\.security), [.tls, .none, .none, .tls, .tls])
        XCTAssertEqual(parsed.nodes.map(\.requiresUDP), [true, false, false, false, true])
        XCTAssertEqual(parsed.nodes[0].credential.authentication["password"], "synthetic-anytls")
        XCTAssertEqual(parsed.nodes[1].credential.authentication["username"], "synthetic-user")
        XCTAssertEqual(parsed.nodes[2].endpointPort, 8_080)
        XCTAssertEqual(parsed.nodes[3].credential.options["sni"], "edge.example.invalid")
        XCTAssertEqual(
            parsed.nodes[4].credential.authentication["uuid"],
            "11111111-2222-3333-4444-555555555555"
        )
    }

    func testParsesFirstBatchClashMappings() throws {
        let parsed = try parser.parse(
            """
            proxies:
              - { name: ANYTLS, type: anytls, server: anytls.example.invalid, port: 443, password: anytls-pass, sni: edge.example.invalid, idle-session-timeout: 45s }
              - { name: SOCKS, type: socks5, server: socks.example.invalid, port: 1080, username: socks-user, password: socks-pass, udp: false }
              - { name: HTTPS, type: http, server: http.example.invalid, port: 8443, username: http-user, password: http-pass, tls: true, sni: edge.example.invalid }
              - { name: TUIC, type: tuic, server: tuic.example.invalid, port: 443, uuid: 11111111-2222-3333-4444-555555555555, password: tuic-pass, congestion-controller: bbr, udp-relay-mode: native }
            """
        )

        XCTAssertEqual(parsed.nodes.map(\.protocolKind), [.anyTLS, .socks5, .http, .tuic])
        XCTAssertEqual(parsed.nodes.map(\.transport), [.tcp, .tcp, .tcp, .quic])
        XCTAssertEqual(parsed.nodes.map(\.security), [.tls, .none, .tls, .tls])
        XCTAssertEqual(parsed.nodes[0].credential.options["idle-session-timeout"], "45s")
        XCTAssertEqual(parsed.nodes[1].requiresUDP, false)
        XCTAssertEqual(parsed.nodes[2].credential.authentication["username"], "http-user")
        XCTAssertEqual(parsed.nodes[3].credential.options["udp-relay-mode"], "native")
    }

    func testSkipsProviderTrafficAndExpiryBannerNodes() throws {
        func vmessURI(ps: String, add: String) throws -> String {
            let object: [String: Any] = [
                "v": "2",
                "ps": ps,
                "add": add,
                "port": "10086",
                "id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
                "net": "tcp",
                "tls": "",
            ]
            let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
            return "vmess://\(data.base64EncodedString())"
        }

        let traffic = try vmessURI(ps: "剩余流量：19.06% 57.71GB", add: "www.g00gle.com")
        let expiry = try vmessURI(ps: "过期时间：2026-09-17 10:01:32", add: "www.g00gle.com")
        let real = try vmessURI(ps: "日本A05 | 下载专用", add: "jp05.example.invalid")
        let subscription = Data("\(traffic)\n\(expiry)\n\(real)".utf8).base64EncodedString()

        let parsed = try parser.parse(subscription)

        XCTAssertEqual(parsed.nodes.map(\.displayName), ["日本A05 | 下载专用"])
        XCTAssertEqual(parsed.nodes[0].endpointHost, "jp05.example.invalid")
        XCTAssertEqual(parsed.skippedNodeCount, 2)
    }

    func testParsesClashBlockAndInlineMappingsAndSkipsUnsupportedType() throws {
        let yaml = """
        mixed-port: 7890
        proxies:
          - name: TEST-SS
            type: ss
            server: ss.example.invalid
            port: 8388
            cipher: aes-128-gcm
            password: "synthetic:password"
            plugin: obfs
            plugin-opts:
              mode: tls
              host: edge.example.invalid
            udp: true
          - { name: TEST-HY2, type: hysteria2, server: hy2.example.invalid, port: 443, password: synthetic-hy2 }
          - name: UNSUPPORTED
            type: wireguard
            server: wireguard.example.invalid
            port: 51820
        proxy-groups: []
        """

        let parsed = try parser.parse(yaml)

        XCTAssertEqual(parsed.nodes.map(\.protocolKind), [.shadowsocks, .hysteria2])
        XCTAssertEqual(parsed.nodes[0].credential.authentication["password"], "synthetic:password")
        XCTAssertEqual(parsed.nodes[0].credential.options["plugin"], "obfs")
        XCTAssertEqual(parsed.nodes[0].credential.options["plugin-opts.mode"], "tls")
        XCTAssertEqual(
            parsed.nodes[0].credential.options["plugin-opts.host"],
            "edge.example.invalid"
        )
        XCTAssertEqual(parsed.nodes[1].transport, .quic)
        XCTAssertEqual(parsed.skippedNodeCount, 1)
    }

    func testPreservesNestedECHTLSWebSocketAndHysteria2Options() throws {
        let yaml = """
        proxies:
          - name: TEST-ECH
            type: vless
            server: 203.0.113.10
            port: 443
            uuid: 11111111-2222-3333-4444-555555555555
            network: ws
            tls: true
            sni: edge.example.invalid
            skip-cert-verify: false
            alpn:
              - h2
              - http/1.1
            ech-opts:
              enable: true
              query-server-name: cloudflare-ech.com
            ws-opts:
              path: /socket
              max-early-data: 2048
              early-data-header-name: Sec-WebSocket-Protocol
              headers:
                Host: edge.example.invalid
          - name: TEST-HY2
            type: hysteria2
            server: hy2.example.invalid
            port: 443
            password: synthetic
            obfs: salamander
            obfs-password: obfs-secret
            up: 50
            down: 100
            ports: 20000-30000
            hop-interval: 30
        """

        let parsed = try parser.parse(yaml)
        XCTAssertEqual(parsed.nodes.count, 2)
        let ech = parsed.nodes[0].credential.options
        XCTAssertEqual(ech["ech-opts.enable"], "true")
        XCTAssertEqual(ech["ech-opts.query-server-name"], "cloudflare-ech.com")
        XCTAssertEqual(ech["alpn"], "h2,http/1.1")
        XCTAssertEqual(ech["ws-opts.max-early-data"], "2048")
        XCTAssertEqual(ech["ws-opts.headers.Host"], "edge.example.invalid")

        let hysteria2 = parsed.nodes[1].credential.options
        XCTAssertEqual(hysteria2["obfs"], "salamander")
        XCTAssertEqual(hysteria2["obfs-password"], "obfs-secret")
        XCTAssertEqual(hysteria2["ports"], "20000-30000")
        XCTAssertEqual(hysteria2["hop-interval"], "30")
    }

    func testFlattensInlineNestedClashOptions() throws {
        let parsed = try parser.parse(
            """
            proxies:
              - { name: INLINE-ECH, type: vless, server: 203.0.113.10, port: 443, uuid: 11111111-2222-3333-4444-555555555555, network: ws, tls: true, ech-opts: { enable: true, query-server-name: cloudflare-ech.com }, ws-opts: { path: /socket, headers: { Host: edge.example.invalid } } }
            """
        )

        let options = try XCTUnwrap(parsed.nodes.first?.credential.options)
        XCTAssertEqual(options["ech-opts.enable"], "true")
        XCTAssertEqual(options["ech-opts.query-server-name"], "cloudflare-ech.com")
        XCTAssertEqual(options["ws-opts.path"], "/socket")
        XCTAssertEqual(options["ws-opts.headers.Host"], "edge.example.invalid")
    }

    func testMapsH2TransportInsteadOfSilentlyDowngradingToTCP() throws {
        let parsed = try parser.parse(
            "vless://11111111-2222-3333-4444-555555555555@node.example.invalid:443"
                + "?security=tls&type=h2&host=edge.example.invalid&path=/h2#H2"
        )

        XCTAssertEqual(parsed.nodes.first?.transport, .http)
    }

    func testNormalizesClashGroupsIntoBinarySmartActions() throws {
        let yaml = """
        proxies:
          - { name: HK-01, type: trojan, server: hk.example.invalid, port: 443, password: synthetic }
          - { name: US-01, type: trojan, server: us.example.invalid, port: 443, password: synthetic }
        proxy-groups:
          - name: Domestic
            type: select
            proxies:
              - DIRECT
              - HK-01
          - name: Streaming
            type: select
            proxies: [US-01]
          - name: Nested Domestic
            type: select
            proxies: [Domestic, Streaming]
        rules:
          - DOMAIN-SUFFIX,example.cn,Nested Domestic
          - DOMAIN-SUFFIX,netflix.com,Streaming
          - DOMAIN-KEYWORD,advertising,REJECT
          - DOMAIN-SUFFIX,compatible.example,COMPATIBLE
          - DOMAIN-SUFFIX,continue.example,PASS
          - MATCH,Streaming
        """

        let policy = try XCTUnwrap(parser.parse(yaml).routePolicy)

        XCTAssertEqual(policy.rules, [
            ProviderRouteRule(match: .domainSuffix("example.cn"), action: .direct),
            ProviderRouteRule(match: .domainSuffix("netflix.com"), action: .proxyCurrentNode),
            ProviderRouteRule(match: .domainKeyword("advertising"), action: .reject),
            ProviderRouteRule(match: .domainSuffix("compatible.example"), action: .direct),
            ProviderRouteRule(match: .domainSuffix("continue.example"), action: .continueMatching),
        ])
        XCTAssertEqual(policy.defaultAction, .proxyCurrentNode)
    }

    func testProviderRoutePolicyRejectsFutureSchemaInsteadOfFallingBack() throws {
        let futurePolicy = ProviderRoutePolicy(
            schemaVersion: ProviderRoutePolicy.currentSchemaVersion + 1,
            rules: [],
            defaultAction: .direct
        )
        let data = try JSONEncoder().encode(futurePolicy)

        XCTAssertThrowsError(
            try JSONDecoder().decode(ProviderRoutePolicy.self, from: data)
        )
    }

    func testProviderRoutePolicyStillDecodesVersionTwoData() throws {
        let versionTwo = ProviderRoutePolicy(
            schemaVersion: 2,
            rules: [.init(match: .domainSuffix("legacy.example"), action: .direct)],
            defaultAction: .proxyCurrentNode
        )

        XCTAssertEqual(
            try JSONDecoder().decode(
                ProviderRoutePolicy.self,
                from: JSONEncoder().encode(versionTwo)
            ),
            versionTwo
        )
    }

    func testClashSmartPreservesTypedOrderedRulesLogicalConditionsAndInlineRuleSets() throws {
        let yaml = """
        proxies:
          - { name: HK-01, type: trojan, server: hk.example.invalid, port: 443, password: synthetic }
        proxy-groups:
          - name: Domestic
            type: select
            proxies: [DIRECT, HK-01]
          - name: Proxy
            type: select
            proxies: [HK-01]
        rule-providers:
          local-domains:
            type: inline
            behavior: domain
            payload:
              - +.corp.example
              - exact.example
          local-cidrs:
            type: inline
            behavior: ipcidr
            payload: [10.0.0.0/8, 2001:db8::/32]
        rules:
          - DOMAIN-WILDCARD,*.wild.example,Proxy
          - DOMAIN-REGEX,^api[0-9]+\\.example$,Proxy
          - IP-CIDR,10.0.0.0/8,Domestic,no-resolve
          - IP-CIDR,203.0.113.0/24,Proxy
          - SRC-IP-CIDR,172.19.0.0/30,Domestic
          - DST-PORT,80/443/1000-2000,Proxy
          - SRC-PORT,53,Domestic
          - NETWORK,udp,Proxy
          - AND,((DOMAIN-SUFFIX,video.example),(NETWORK,tcp)),Proxy
          - RULE-SET,local-domains,Domestic
          - RULE-SET,local-cidrs,Proxy,src
          - MATCH,Proxy
        """

        let policy = try XCTUnwrap(parser.parse(yaml).routePolicy)
        XCTAssertEqual(policy.schemaVersion, ProviderRoutePolicy.currentSchemaVersion)
        XCTAssertEqual(policy.rules.count, 11)
        XCTAssertEqual(policy.rules[0].match, .domainRegex("^.*\\.wild\\.example$"))
        XCTAssertEqual(policy.rules[0].action, .proxyCurrentNode)
        XCTAssertEqual(policy.rules[2].match, .ipCIDR("10.0.0.0/8"))
        XCTAssertFalse(policy.rules[2].requiresDestinationResolution)
        XCTAssertTrue(policy.rules[3].requiresDestinationResolution)
        XCTAssertEqual(policy.rules[4].match, .sourceIPCIDR("172.19.0.0/30"))
        XCTAssertEqual(policy.rules[5].match, .destinationPort("80/443/1000-2000"))
        XCTAssertEqual(policy.rules[6].match, .sourcePort("53"))
        XCTAssertEqual(policy.rules[7].match, .network("udp"))
        XCTAssertEqual(
            policy.rules[8].match,
            .logical(mode: .and, rules: [.domainSuffix("video.example"), .network("tcp")])
        )
        XCTAssertEqual(policy.rules[9].action, .direct)
        XCTAssertEqual(policy.rules[10].match, .sourceRuleSet("local-cidrs"))
        XCTAssertEqual(policy.ruleSets.count, 2)
        XCTAssertEqual(
            policy.ruleSets.first(where: { $0.tag == "local-domains" })?.source,
            .inline([.domainSuffix("corp.example"), .domainSuffix("exact.example")])
        )
        XCTAssertEqual(policy.defaultAction, .proxyCurrentNode)
    }

    func testClashSmartSkipsProcessNameBecauseAppleTUNCannotObserveIt() throws {
        let yaml = """
        proxies:
          - { name: HK-01, type: trojan, server: hk.example.invalid, port: 443, password: synthetic }
        proxy-groups:
          - name: Proxy
            type: select
            proxies: [HK-01]
        rules:
          - DOMAIN-SUFFIX,example.com,Proxy
          - PROCESS-NAME,com.viu.phone,Proxy
          - PROCESS-NAME,Telegram.exe,Proxy
          - DOMAIN-SUFFIX,viu.com,Proxy
          - MATCH,Proxy
        """

        let parsed = try parser.parse(yaml)
        XCTAssertEqual(parsed.nodes.map(\.displayName), ["HK-01"])
        let policy = try XCTUnwrap(parsed.routePolicy)
        XCTAssertEqual(policy.rules, [
            ProviderRouteRule(match: .domainSuffix("example.com"), action: .proxyCurrentNode),
            ProviderRouteRule(match: .domainSuffix("viu.com"), action: .proxyCurrentNode),
        ])
        XCTAssertEqual(policy.defaultAction, .proxyCurrentNode)
    }

    func testClashSmartRejectsUnknownRuleInsteadOfSilentlyDroppingIt() {
        let yaml = """
        proxies:
          - { name: HK-01, type: trojan, server: hk.example.invalid, port: 443, password: synthetic }
        rules:
          - MADE-UP-RULE,value,HK-01
          - MATCH,HK-01
        """
        XCTAssertThrowsError(try parser.parse(yaml)) { error in
            XCTAssertEqual(error as? SubscriptionParserError, .unsupportedRouteRule("MADE-UP-RULE"))
        }
    }

    func testClashSmartRejectsPassAsFinalBecauseThereIsNoNextRule() {
        let yaml = """
        proxies:
          - { name: HK-01, type: trojan, server: hk.example.invalid, port: 443, password: synthetic }
        rules:
          - DOMAIN-SUFFIX,example.com,HK-01
          - MATCH,PASS
        """

        XCTAssertThrowsError(try parser.parse(yaml)) { error in
            XCTAssertEqual(
                error as? SubscriptionParserError,
                .invalidRouteRule("MATCH,PASS")
            )
        }
    }

    func testParsesSurgeProxyProfileAndNormalizesRulesWithoutExecutingOtherSections() throws {
        let surge = """
        [General]
        update-url = https://provider.example.invalid/profile

        [Proxy]
        TEST-SS = ss, ss.example.invalid, 8388, encrypt-method=aes-128-gcm, password=synthetic-ss, udp-relay=true
        TEST-VMESS = vmess, vmess.example.invalid, 443, username=aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee, tls=true, ws=true, ws-path=/socket, ws-headers="Host: edge.example.invalid"
        TEST-HY2 = hysteria2, hy2.example.invalid, 443, password=synthetic-hy2, sni=hy2.example.invalid
        UNSUPPORTED = wireguard, wg.example.invalid, 51820, private-key=synthetic

        [Proxy Group]
        Domestic = select, DIRECT, TEST-SS
        Streaming = select, TEST-VMESS

        [Rule]
        DOMAIN-SUFFIX,example.cn,Domestic
        DOMAIN-SUFFIX,streaming.example,Streaming
        DOMAIN-KEYWORD,advertising,REJECT
        FINAL,Streaming

        [URL Rewrite]
        ^https://example.invalid/ script-response-body https://example.invalid/script.js
        """

        let parsed = try parser.parse(surge, suggestedName: "Synthetic Surge")

        XCTAssertEqual(parsed.suggestedName, "Synthetic Surge")
        XCTAssertEqual(parsed.nodes.map(\.protocolKind), [.shadowsocks, .vmess, .hysteria2])
        XCTAssertEqual(parsed.nodes[0].credential.authentication["method"], "aes-128-gcm")
        XCTAssertEqual(parsed.nodes[0].requiresUDP, true)
        XCTAssertEqual(parsed.nodes[1].transport, .webSocket)
        XCTAssertEqual(parsed.nodes[1].security, .tls)
        XCTAssertEqual(parsed.nodes[1].credential.options["path"], "/socket")
        XCTAssertEqual(parsed.nodes[1].credential.options["host"], "edge.example.invalid")
        XCTAssertEqual(parsed.nodes[2].security, .tls)
        XCTAssertEqual(parsed.skippedNodeCount, 1)
        XCTAssertEqual(parsed.routePolicy?.rules, [
            ProviderRouteRule(match: .domainSuffix("example.cn"), action: .direct),
            ProviderRouteRule(match: .domainSuffix("streaming.example"), action: .proxyCurrentNode),
            ProviderRouteRule(match: .domainKeyword("advertising"), action: .reject),
        ])
        XCTAssertEqual(parsed.routePolicy?.defaultAction, .proxyCurrentNode)
    }

    func testRejectsSurgeRuleOnlyProfileWithAHelpfulParserError() {
        let surge = """
        [General]
        dns-server = system

        [Proxy Group]
        Proxy = select, DIRECT

        [Rule]
        FINAL,Proxy
        """

        XCTAssertThrowsError(try parser.parse(surge)) { error in
            XCTAssertEqual(error as? SubscriptionParserError, .surgeProfileContainsNoProxyPolicies)
        }
    }

    func testSurgeSmartPreservesTypedSourceResolutionAndLogicalRules() throws {
        let surge = """
        [Proxy]
        TEST-SS = ss, ss.example.invalid, 8388, encrypt-method=aes-128-gcm, password=synthetic

        [Proxy Group]
        Domestic = select, DIRECT, TEST-SS

        [Rule]
        IP-CIDR,10.0.0.0/8,Domestic,no-resolve
        IP-CIDR6,2001:db8::/32,TEST-SS
        SRC-IP-CIDR,192.0.2.0/24,TEST-SS
        SRC-PORT,443,TEST-SS
        DOMAIN-WILDCARD,*.video?.example,TEST-SS
        AND,((DOMAIN-SUFFIX,example.org),(NETWORK,TCP)),TEST-SS
        FINAL,TEST-SS
        """

        let policy = try XCTUnwrap(parser.parse(surge).routePolicy)
        XCTAssertEqual(policy.rules[0], ProviderRouteRule(
            match: .ipCIDR("10.0.0.0/8"),
            action: .direct,
            requiresDestinationResolution: false
        ))
        XCTAssertEqual(policy.rules[1], ProviderRouteRule(
            match: .ipCIDR("2001:db8::/32"),
            action: .proxyCurrentNode,
            requiresDestinationResolution: true
        ))
        XCTAssertEqual(policy.rules[2].match, .sourceIPCIDR("192.0.2.0/24"))
        XCTAssertEqual(policy.rules[3].match, .sourcePort("443"))
        XCTAssertEqual(policy.rules[4].match, .domainRegex("^.*\\.video.\\.example$"))
        XCTAssertEqual(policy.rules[5].match, .logical(
            mode: .and,
            rules: [.domainSuffix("example.org"), .network("tcp")]
        ))
        XCTAssertEqual(policy.defaultAction, .proxyCurrentNode)
    }

    func testSurgeSmartRejectsUnknownRuleInsteadOfSilentlyDroppingIt() {
        let surge = """
        [Proxy]
        TEST-SS = ss, ss.example.invalid, 8388, encrypt-method=aes-128-gcm, password=synthetic

        [Rule]
        MADE-UP-RULE,value,TEST-SS
        FINAL,TEST-SS
        """

        XCTAssertThrowsError(try parser.parse(surge)) { error in
            XCTAssertEqual(error as? SubscriptionParserError, .unsupportedRouteRule("MADE-UP-RULE"))
        }
    }

    func testSurgeSmartPreservesCompatibleAndPassActions() throws {
        let surge = """
        [Proxy]
        TEST-SS = ss, ss.example.invalid, 8388, encrypt-method=aes-128-gcm, password=synthetic

        [Rule]
        DOMAIN-SUFFIX,direct.example,COMPATIBLE
        DOMAIN-SUFFIX,continue.example,PASS
        FINAL,TEST-SS
        """

        let policy = try XCTUnwrap(parser.parse(surge).routePolicy)
        XCTAssertEqual(policy.rules, [
            ProviderRouteRule(match: .domainSuffix("direct.example"), action: .direct),
            ProviderRouteRule(match: .domainSuffix("continue.example"), action: .continueMatching),
        ])
        XCTAssertEqual(policy.defaultAction, .proxyCurrentNode)
    }

    func testSurgeSmartRejectsPassAsFinalBecauseThereIsNoNextRule() {
        let surge = """
        [Proxy]
        TEST-SS = ss, ss.example.invalid, 8388, encrypt-method=aes-128-gcm, password=synthetic

        [Rule]
        DOMAIN-SUFFIX,example.com,TEST-SS
        FINAL,PASS
        """

        XCTAssertThrowsError(try parser.parse(surge)) { error in
            XCTAssertEqual(
                error as? SubscriptionParserError,
                .invalidRouteRule("FINAL,PASS")
            )
        }
    }

    func testSurgeSmartSkipsInboundPortThatTunCannotObserve() throws {
        let surge = """
        [Proxy]
        TEST-SS = ss, ss.example.invalid, 8388, encrypt-method=aes-128-gcm, password=synthetic

        [Rule]
        IN-PORT,7890,TEST-SS
        DOMAIN-SUFFIX,example.com,TEST-SS
        FINAL,TEST-SS
        """

        let policy = try XCTUnwrap(parser.parse(surge).routePolicy)
        XCTAssertEqual(policy.rules, [
            ProviderRouteRule(match: .domainSuffix("example.com"), action: .proxyCurrentNode),
        ])
        XCTAssertEqual(policy.defaultAction, .proxyCurrentNode)
    }

    func testURIListSkipsMalformedLineInsteadOfFailingTheWholeList() throws {
        let payload = [
            "not a uri at all",
            "vless://11111111-2222-3333-4444-555555555555@good.example.invalid:443?security=tls#GOOD",
            "vless://missing-host-and-port",
        ].joined(separator: "\n")

        let parsed = try parser.parse(payload)
        XCTAssertEqual(parsed.nodes.map(\.displayName), ["GOOD"])
        XCTAssertEqual(parsed.skippedNodeCount, 2)
    }

    func testBinarySmartUsesCurrentNodeOutsideProviderGroup() {
        let normalizer = BinarySmartPolicyNormalizer()
        let groups = [ProviderProxyGroup(name: "US only", members: ["US-01", "US-02"])]

        XCTAssertEqual(normalizer.action(for: "US only", groups: groups), .proxyCurrentNode)
        XCTAssertEqual(normalizer.action(for: "DIRECT", groups: groups), .direct)
        XCTAssertEqual(normalizer.action(for: "COMPATIBLE", groups: groups), .direct)
        XCTAssertEqual(normalizer.action(for: "REJECT-DROP", groups: groups), .reject)
        XCTAssertEqual(normalizer.action(for: "REJECT-TINYGIF", groups: groups), .reject)
        XCTAssertEqual(normalizer.action(for: "PASS", groups: groups), .continueMatching)
    }

    func testRejectsYAMLMergeKeys() {
        let yaml = """
        proxies:
          - <<: *shared
            name: TEST
        """
        XCTAssertThrowsError(try parser.parse(yaml)) { error in
            XCTAssertEqual(error as? SubscriptionParserError, .unsafeYAMLFeature)
        }
    }
}

final class SubscriptionPayloadLoaderClipboardTests: XCTestCase {
    func testUsesProductUserAgentWithCommonClientCompatibilityTokens() {
        let tokens = SubscriptionPayloadLoader.compatibilitySubscriptionUserAgent
        XCTAssertEqual(tokens, "ClashMeta clash.meta Stash Shadowrocket")
        XCTAssertEqual(
            SubscriptionPayloadLoader.subscriptionUserAgent(version: "1.2.3"),
            "Routeva/1.2.3 \(tokens)"
        )
        XCTAssertEqual(
            SubscriptionPayloadLoader.subscriptionUserAgent(version: "1.2 beta!"),
            "Routeva/1.2beta \(tokens)"
        )
        XCTAssertEqual(
            SubscriptionPayloadLoader.subscriptionUserAgent(version: nil),
            "Routeva/1.0 \(tokens)"
        )
        XCTAssertFalse(tokens.split(separator: " ").contains("clash"))
    }

    func testExtractsBareQuotedAndMixedHTTPSLinks() {
        let url = URL(string: "https://provider.example.invalid/sub")!
        XCTAssertEqual(
            SubscriptionPayloadLoader.remoteHTTPSURL(fromClipboard: url.absoluteString),
            url
        )
        XCTAssertEqual(
            SubscriptionPayloadLoader.remoteHTTPSURL(fromClipboard: "\"\(url.absoluteString)\""),
            url
        )
        XCTAssertEqual(
            SubscriptionPayloadLoader.remoteHTTPSURL(
                fromClipboard: "碧影订阅 \(url.absoluteString) 备用"
            ),
            url
        )
    }

    func testExtractsClashOneClickInstallURL() {
        let encoded = "clash://install-config?url=https%3A%2F%2Fprovider.example.invalid%2Fsub"
        XCTAssertEqual(
            SubscriptionPayloadLoader.remoteHTTPSURL(fromClipboard: encoded)?.absoluteString,
            "https://provider.example.invalid/sub"
        )
    }

    func testIgnoresPlainNodeURI() {
        XCTAssertNil(
            SubscriptionPayloadLoader.remoteHTTPSURL(
                fromClipboard: "vless://11111111-2222-3333-4444-555555555555@node.example.invalid:443"
            )
        )
    }

    func testTreatsExplicitHTTPProxyURIAsClipboardPayload() async throws {
        let uri = "https://proxy-user:proxy-pass@proxy.example.invalid:8443#HTTPS-PROXY"
        let resolved = try await SubscriptionPayloadLoader().resolveClipboardText(uri)

        XCTAssertEqual(String(data: resolved.data, encoding: .utf8), uri)
        XCTAssertEqual(resolved.source, .clipboard)
    }

    func testFetchesHTTPSSubscriptionWithExplicitPortPathAndTokenQuery() async throws {
        let url = try XCTUnwrap(
            URL(string: "https://provider.example.invalid:4900/api/v1/client/subscribe?token=synthetic")
        )
        let payload = Data("dHVpYzovL3N5bnRoZXRpYw==".utf8)
        let stub = SubscriptionRequestStub(replies: [
            .init(data: payload, statusCode: 200, headers: [:]),
        ])
        let loader = SubscriptionPayloadLoader { request in
            try await stub.response(for: request)
        }

        let resolved = try await loader.resolveClipboardText(url.absoluteString)

        XCTAssertEqual(resolved.data, payload)
        XCTAssertEqual(resolved.source, .remoteURL(url))
        let requestCount = await stub.requestCount
        XCTAssertEqual(requestCount, 1)
    }

    func testKeepsAuthorityOnlyHTTPURLAsExplicitProxy() async throws {
        let uri = "http://proxy.example.invalid:8080"

        let resolved = try await SubscriptionPayloadLoader().resolveClipboardText(uri)

        XCTAssertEqual(String(data: resolved.data, encoding: .utf8), uri)
        XCTAssertEqual(resolved.source, .clipboard)
    }

    func testDoesNotTreatECHQueryDNSAsSubscriptionURL() {
        let uri = "vless://11111111-2222-3333-4444-555555555555@node.example.invalid:443"
            + "?security=tls&ech=cloudflare-ech.com+https://dns.alidns.com/dns-query#DE"
        XCTAssertNil(SubscriptionPayloadLoader.remoteHTTPSURL(fromClipboard: uri))
    }

    func testRetriesSuccessfulEmptySubscriptionWithBrandedClashCompatibilityUserAgent() async throws {
        let url = try XCTUnwrap(URL(string: "https://provider.example.invalid/subscription"))
        let stub = SubscriptionRequestStub(replies: [
            .init(data: Data(), statusCode: 200, headers: [:]),
            .init(
                data: Data("proxies:\n  - { name: TEST, type: tuic }".utf8),
                statusCode: 200,
                headers: ["subscription-userinfo": "upload=1; download=2; total=10"]
            ),
        ])
        let loader = SubscriptionPayloadLoader { request in
            try await stub.response(for: request)
        }

        let resolved = try await loader.remotePayload(from: url)
        let userAgents = await stub.userAgents

        XCTAssertEqual(userAgents.count, 2)
        XCTAssertTrue(userAgents[0].hasPrefix("Routeva/"))
        XCTAssertTrue(userAgents[0].contains("ClashMeta"))
        XCTAssertTrue(userAgents[0].contains("clash.meta"))
        XCTAssertTrue(userAgents[0].contains("Stash"))
        XCTAssertTrue(userAgents[0].contains("Shadowrocket"))
        XCTAssertEqual(userAgents[1], SubscriptionPayloadLoader.compatibilitySubscriptionUserAgent)
        XCTAssertEqual(String(data: resolved.data, encoding: .utf8), "proxies:\n  - { name: TEST, type: tuic }")
        XCTAssertEqual(resolved.usage?.usedBytes, 3)
    }

    func testDoesNotRetryNonEmptySubscriptionResponse() async throws {
        let url = try XCTUnwrap(URL(string: "https://provider.example.invalid/subscription"))
        let payload = Data("tuic://synthetic@node.example.invalid:443".utf8)
        let stub = SubscriptionRequestStub(replies: [
            .init(data: payload, statusCode: 200, headers: [:]),
        ])
        let loader = SubscriptionPayloadLoader { request in
            try await stub.response(for: request)
        }

        let resolved = try await loader.remotePayload(from: url)
        let requestCount = await stub.userAgents.count

        XCTAssertEqual(resolved.data, payload)
        XCTAssertEqual(requestCount, 1)
    }

    func testStopsAfterOneCompatibilityRetryWhenBothResponsesAreEmpty() async throws {
        let url = try XCTUnwrap(URL(string: "https://provider.example.invalid/subscription"))
        let stub = SubscriptionRequestStub(replies: [
            .init(data: Data(), statusCode: 200, headers: [:]),
            .init(data: Data(), statusCode: 200, headers: [:]),
        ])
        let loader = SubscriptionPayloadLoader { request in
            try await stub.response(for: request)
        }

        do {
            _ = try await loader.remotePayload(from: url)
            XCTFail("Expected an empty compatibility response to fail")
        } catch {
            XCTAssertEqual(error as? SubscriptionPayloadLoaderError, .invalidResponse)
        }
        let requestCount = await stub.requestCount
        XCTAssertEqual(requestCount, 2)
    }
}

private actor SubscriptionRequestStub {
    struct Reply: Sendable {
        let data: Data
        let statusCode: Int
        let headers: [String: String]
    }

    private var replies: [Reply]
    private(set) var userAgents: [String] = []

    var requestCount: Int { userAgents.count }

    init(replies: [Reply]) {
        self.replies = replies
    }

    func response(for request: URLRequest) throws -> (Data, URLResponse) {
        userAgents.append(request.value(forHTTPHeaderField: "User-Agent") ?? "")
        guard !replies.isEmpty, let url = request.url else {
            throw SubscriptionPayloadLoaderError.invalidResponse
        }
        let reply = replies.removeFirst()
        let response = try XCTUnwrap(HTTPURLResponse(
            url: url,
            statusCode: reply.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: reply.headers
        ))
        return (reply.data, response)
    }
}

final class SubscriptionImportServiceTests: XCTestCase {
    private var temporaryDirectory: URL!
    private var database: RoutevaDatabase!
    private var secrets: MemorySecretStore!
    private var service: SubscriptionImportService!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SubscriptionImportTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        database = try RoutevaDatabase(databaseURL: temporaryDirectory.appendingPathComponent("test.sqlite"))
        secrets = MemorySecretStore()
        service = SubscriptionImportService(database: database, secrets: secrets)
    }

    override func tearDownWithError() throws {
        service = nil
        secrets = nil
        database = nil
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }

    func testImportStoresSecretsOutsideSQLiteAndMakesFirstSubscriptionActive() async throws {
        let payload = Data("trojan://synthetic-secret@node.example.invalid:443?security=tls#TEST".utf8)

        let result = try await service.importPayload(
            payload,
            source: .clipboard,
            displayName: "Synthetic",
            makeActive: true
        )

        XCTAssertEqual(result.nodeCount, 1)
        let subscriptions = try await database.subscriptions()
        let nodes = try await database.nodes(subscriptionID: result.subscriptionID)
        XCTAssertEqual(subscriptions.first?.displayName, "Synthetic")
        XCTAssertEqual(subscriptions.first?.isActive, true)
        XCTAssertEqual(nodes.first?.endpointHost, "node.example.invalid")
        let credentialData = try await secrets.data(for: try XCTUnwrap(nodes.first?.credentialReference))
        let credential = try JSONDecoder().decode(ProxyCredentialEnvelope.self, from: credentialData)
        XCTAssertEqual(credential.authentication["password"], "synthetic-secret")

        let databaseBytes = try Data(contentsOf: database.databaseURL)
        XCTAssertNil(String(data: databaseBytes, encoding: .utf8)?.range(of: "synthetic-secret"))
    }

    func testImportResolvesRemoteRuleProviderWithoutPersistingCredentialURL() async throws {
        let credentialURL = "https://rules.example.invalid/provider.yaml?token=private-rule-token"
        let subscription = Data("""
        proxies:
          - { name: HK-01, type: trojan, server: hk.example.invalid, port: 443, password: synthetic }
        proxy-groups:
          - { name: Proxy, type: select, proxies: [HK-01] }
        rule-providers:
          private-domains:
            type: http
            behavior: domain
            format: yaml
            url: \(credentialURL)
        rules:
          - RULE-SET,private-domains,Proxy
          - MATCH,Proxy
        """.utf8)
        let providerPayload = Data("""
        payload:
          - +.resolved.example
          - exact.example
        """.utf8)
        service = SubscriptionImportService(
            database: database,
            secrets: secrets,
            payloadLoader: URLMappedPayloadLoader(payloads: [credentialURL: providerPayload])
        )

        let result = try await service.importPayload(
            subscription,
            source: .clipboard,
            displayName: "Remote Rules",
            makeActive: true
        )
        let storedRecord = try await database.subscription(id: result.subscriptionID)
        let stored = try XCTUnwrap(storedRecord)
        let policyData = try XCTUnwrap(stored.routePolicyJSON)
        let policy = try JSONDecoder().decode(ProviderRoutePolicy.self, from: policyData)
        XCTAssertEqual(
            policy.ruleSets.first?.source,
            .inline([.domainSuffix("resolved.example"), .domainSuffix("exact.example")])
        )
        XCTAssertFalse(String(decoding: policyData, as: UTF8.self).contains("private-rule-token"))
        let databaseBytes = try Data(contentsOf: database.databaseURL)
        XCTAssertFalse(String(decoding: databaseBytes, as: UTF8.self).contains("private-rule-token"))
    }

    func testMalformedReplacementPreservesExistingSubscriptionAndSecrets() async throws {
        _ = try await service.importPayload(
            Data("trojan://first-secret@first.example.invalid:443#FIRST".utf8),
            source: .clipboard,
            displayName: "Existing",
            makeActive: true
        )
        let countBefore = await secrets.count

        do {
            _ = try await service.importPayload(
                Data("not a supported subscription".utf8),
                source: .clipboard,
                displayName: "Broken",
                makeActive: false
            )
            XCTFail("Expected parser failure")
        } catch {
            XCTAssertEqual(error as? SubscriptionParserError, .unsupportedFormat)
        }

        let subscriptions = try await database.subscriptions()
        XCTAssertEqual(subscriptions.map(\.displayName), ["Existing"])
        let countAfter = await secrets.count
        XCTAssertEqual(countAfter, countBefore)
    }

    func testRemoteRefreshAtomicallyReplacesNodesAndPreservesPreferredByName() async throws {
        let remoteURL = try XCTUnwrap(URL(string: "https://subscription.example.invalid/list"))
        let initial = Data([
            "trojan://first-secret@first.example.invalid:443#FIRST",
            "trojan://preferred-secret@old.example.invalid:443#PREFERRED",
        ].joined(separator: "\n").utf8)
        let result = try await service.importPayload(
            initial,
            source: .remoteURL(remoteURL),
            displayName: "Remote",
            makeActive: true
        )
        let oldNodes = try await database.nodes(subscriptionID: result.subscriptionID)
        let oldPreferred = try XCTUnwrap(oldNodes.first(where: { $0.displayName == "PREFERRED" }))
        try await database.setPreferredNode(subscriptionID: result.subscriptionID, nodeID: oldPreferred.id)

        let refreshed = Data([
            "trojan://preferred-new-secret@new.example.invalid:443#PREFERRED",
            "trojan://third-secret@third.example.invalid:443#THIRD",
        ].joined(separator: "\n").utf8)
        service = SubscriptionImportService(
            database: database,
            secrets: secrets,
            payloadLoader: StubPayloadLoader(payload: refreshed)
        )
        let refreshResult = try await service.refreshSubscription(id: result.subscriptionID)

        XCTAssertEqual(refreshResult.nodeCount, 2)
        let newNodes = try await database.nodes(subscriptionID: result.subscriptionID)
        let storedSubscription = try await database.subscription(id: result.subscriptionID)
        let subscription = try XCTUnwrap(storedSubscription)
        let newPreferred = try XCTUnwrap(newNodes.first(where: { $0.displayName == "PREFERRED" }))
        XCTAssertNotEqual(newPreferred.id, oldPreferred.id)
        XCTAssertEqual(subscription.preferredNodeID, newPreferred.id)
        XCTAssertEqual(newPreferred.endpointHost, "new.example.invalid")
        await XCTAssertSecretMissing(oldPreferred.credentialReference)
    }

    func testRemoteRefreshStoresProviderTrafficQuota() async throws {
        let remoteURL = try XCTUnwrap(URL(string: "https://subscription.example.invalid/list"))
        let result = try await service.importPayload(
            Data("trojan://initial-secret@initial.example.invalid:443#INITIAL".utf8),
            source: .remoteURL(remoteURL),
            displayName: "Remote",
            makeActive: true
        )
        let refreshed = Data("trojan://quota-secret@quota.example.invalid:443#QUOTA".utf8)
        service = SubscriptionImportService(
            database: database,
            secrets: secrets,
            payloadLoader: StubPayloadLoader(
                payload: refreshed,
                usage: SubscriptionUsage(
                    usedBytes: 3_000,
                    totalBytes: 10_000,
                    expiresAt: Date(timeIntervalSince1970: 1_800_000_000)
                )
            )
        )

        _ = try await service.refreshSubscription(id: result.subscriptionID)
        let storedSubscription = try await database.subscription(id: result.subscriptionID)
        let subscription = try XCTUnwrap(storedSubscription)
        XCTAssertEqual(subscription.usedBytes, 3_000)
        XCTAssertEqual(subscription.totalBytes, 10_000)
        XCTAssertEqual(subscription.expiresAt, Date(timeIntervalSince1970: 1_800_000_000))
    }

    func testMalformedRemoteRefreshPreservesExistingNodesAndPreferred() async throws {
        let remoteURL = try XCTUnwrap(URL(string: "https://subscription.example.invalid/list"))
        let result = try await service.importPayload(
            Data("trojan://existing-secret@existing.example.invalid:443#EXISTING".utf8),
            source: .remoteURL(remoteURL),
            displayName: "Remote",
            makeActive: true
        )
        let oldNodes = try await database.nodes(subscriptionID: result.subscriptionID)
        let oldNode = try XCTUnwrap(oldNodes.first)
        try await database.setPreferredNode(subscriptionID: result.subscriptionID, nodeID: oldNode.id)
        let secretCountBefore = await secrets.count
        service = SubscriptionImportService(
            database: database,
            secrets: secrets,
            payloadLoader: StubPayloadLoader(payload: Data("broken".utf8))
        )

        do {
            _ = try await service.refreshSubscription(id: result.subscriptionID)
            XCTFail("Expected refresh parse failure")
        } catch {
            XCTAssertEqual(error as? SubscriptionParserError, .unsupportedFormat)
        }

        let currentNodes = try await database.nodes(subscriptionID: result.subscriptionID)
        let currentNode = try XCTUnwrap(currentNodes.first)
        let storedSubscription = try await database.subscription(id: result.subscriptionID)
        let subscription = try XCTUnwrap(storedSubscription)
        let secretCountAfter = await secrets.count
        XCTAssertEqual(currentNode, oldNode)
        XCTAssertEqual(subscription.preferredNodeID, oldNode.id)
        XCTAssertEqual(secretCountAfter, secretCountBefore)
        _ = try await secrets.data(for: oldNode.credentialReference)
    }

    private func XCTAssertSecretMissing(_ reference: String) async {
        do {
            _ = try await secrets.data(for: reference)
            XCTFail("Expected old node credential to be removed")
        } catch {
            XCTAssertEqual(error as? KeychainStoreError, .notFound)
        }
    }
}

private struct StubPayloadLoader: SubscriptionPayloadLoading {
    let payload: Data
    var usage: SubscriptionUsage?

    func remotePayload(from url: URL) async throws -> ResolvedSubscriptionPayload {
        ResolvedSubscriptionPayload(data: payload, source: .remoteURL(url), usage: usage)
    }
}

private struct URLMappedPayloadLoader: SubscriptionPayloadLoading {
    let payloads: [String: Data]

    func remotePayload(from url: URL) async throws -> ResolvedSubscriptionPayload {
        guard let payload = payloads[url.absoluteString] else {
            throw SubscriptionPayloadLoaderError.invalidResponse
        }
        return ResolvedSubscriptionPayload(data: payload, source: .remoteURL(url))
    }
}

private actor MemorySecretStore: SecretStoring {
    private var values: [String: Data] = [:]

    var count: Int { values.count }

    func set(_ data: Data, for reference: String) throws {
        values[reference] = data
    }

    func data(for reference: String) throws -> Data {
        guard let value = values[reference] else { throw KeychainStoreError.notFound }
        return value
    }

    func remove(reference: String) throws {
        values.removeValue(forKey: reference)
    }
}
