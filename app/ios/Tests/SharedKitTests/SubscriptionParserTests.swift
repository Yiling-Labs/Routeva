import DataKit
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

    func testSurgeSmartRejectsInboundPortThatTunCannotObserve() {
        let surge = """
        [Proxy]
        TEST-SS = ss, ss.example.invalid, 8388, encrypt-method=aes-128-gcm, password=synthetic

        [Rule]
        IN-PORT,7890,TEST-SS
        FINAL,TEST-SS
        """

        XCTAssertThrowsError(try parser.parse(surge)) { error in
            XCTAssertEqual(error as? SubscriptionParserError, .unsupportedRouteRule("IN-PORT"))
        }
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
