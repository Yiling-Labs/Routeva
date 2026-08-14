import CoreConfigKit
import Darwin
import DataKit
import Foundation
import Libbox
import SharedKit
import XCTest

final class SingBoxConfigurationValidationTests: XCTestCase {
    func testCommandServerStartsGVisorStackAndReturnsPacketFlowDatagram() throws {
        let runtimeDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("routeva-libbox-start-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: runtimeDirectory,
            withIntermediateDirectories: true
        )

        let setup = LibboxSetupOptions()
        setup.basePath = runtimeDirectory.path
        setup.workingPath = runtimeDirectory.appendingPathComponent("working", isDirectory: true).path
        setup.tempPath = runtimeDirectory.appendingPathComponent("temporary", isDirectory: true).path
        setup.logMaxLines = 32
        setup.debug = true
        var commandPort: Int32 = 0
        var portError: NSError?
        XCTAssertTrue(LibboxAvailablePort(19_091, &commandPort, &portError))
        XCTAssertNil(portError)
        setup.commandServerListenPort = commandPort
        var setupError: NSError?
        XCTAssertTrue(LibboxSetup(setup, &setupError), setupError?.localizedDescription ?? "")

        let platform = SyntheticPacketFlowPlatform()
        var createError: NSError?
        let server = try XCTUnwrap(LibboxNewCommandServer(platform, platform, &createError))
        defer {
            try? server.closeService()
            server.close()
            platform.closeDescriptors()
        }

        let nodeID = UUID()
        let credentialReference = "synthetic-credential-\(nodeID.uuidString)"
        let node = NodeRecord(
            id: nodeID,
            subscriptionID: UUID(),
            sortIndex: 0,
            displayName: "TEST-SS",
            protocolKind: .shadowsocks,
            transport: .tcp,
            security: .none,
            requiresUDP: true,
            endpointHost: "proxy.example.invalid",
            endpointPort: 8_388,
            credentialReference: credentialReference
        )
        let secondNodeID = UUID()
        let secondCredentialReference = "synthetic-credential-\(secondNodeID.uuidString)"
        let secondNode = NodeRecord(
            id: secondNodeID,
            subscriptionID: node.subscriptionID,
            sortIndex: 1,
            displayName: "TEST-SS-SECOND",
            protocolKind: .shadowsocks,
            transport: .tcp,
            security: .none,
            requiresUDP: true,
            endpointHost: "proxy-second.example.invalid",
            endpointPort: 8_389,
            credentialReference: secondCredentialReference
        )
        let selectedProfile = RuntimeProfile(
            id: nodeID,
            protocolKind: .shadowsocks,
            transport: .tcp,
            security: .none,
            requiresUDP: true,
            credential: SecretReference(keychainIdentifier: credentialReference)
        )
        let secondProfile = RuntimeProfile(
            id: secondNodeID,
            protocolKind: .shadowsocks,
            transport: .tcp,
            security: .none,
            requiresUDP: true,
            credential: SecretReference(keychainIdentifier: secondCredentialReference)
        )
        let manifest = RuntimeManifest(
            corePolicy: .singBox,
            profile: selectedProfile,
            profiles: [selectedProfile, secondProfile],
            routingMode: .global,
            dnsPreset: .automatic
        )
        let compiled = try CoreConfigurationCompiler().compile(
            manifest: manifest,
            nodes: [node, secondNode],
            credentials: [
                nodeID: ProxyCredentialEnvelope(authentication: [
                    "method": "aes-128-gcm",
                    "password": "synthetic-password",
                ]),
                secondNodeID: ProxyCredentialEnvelope(authentication: [
                    "method": "aes-128-gcm",
                    "password": "synthetic-second-password",
                ]),
            ],
            for: .singBox
        )
        let configuration = compiled.json

        do {
            try server.checkConfig(configuration)
        } catch {
            XCTFail("Libbox checkConfig failed: \(error.localizedDescription)")
            return
        }
        do {
            try server.start()
        } catch {
            XCTFail("Libbox command server start failed: \(error.localizedDescription)")
            return
        }
        do {
            try server.startOrReloadService(configuration, options: LibboxOverrideOptions())
        } catch {
            XCTFail("Libbox service start failed: \(error.localizedDescription)")
            return
        }
        XCTAssertTrue(platform.didOpenTun)

        let clientOptions = LibboxCommandClientOptions()
        clientOptions.addCommand(LibboxCommandGroup)
        let groupClient = try XCTUnwrap(LibboxNewCommandClient(platform, clientOptions))
        defer { try? groupClient.disconnect() }
        try groupClient.connect()
        XCTAssertTrue(
            platform.waitForRoutevaProbeGroup(timeout: 2),
            "Libbox Group stream did not expose the compiled routeva-probe group"
        )
        XCTAssertNoThrow(try groupClient.selectOutbound(
            SingBoxNodeSelector.groupTag,
            outboundTag: SingBoxNodeSelector.outboundTag(for: secondNodeID)
        ))
        XCTAssertTrue(
            platform.waitForSelectedOutboundTag(
                SingBoxNodeSelector.outboundTag(for: secondNodeID),
                timeout: 2
            ),
            "Libbox Group stream did not confirm the selected outbound"
        )
        XCTAssertNoThrow(try groupClient.closeConnections())
        XCTAssertNoThrow(try groupClient.urlTest("routeva-probe"))

        let directManifest = RuntimeManifest(
            corePolicy: .singBox,
            profile: manifest.profile,
            routingMode: .direct,
            dnsPreset: .automatic
        )
        let compiledDirectConfiguration = try CoreConfigurationCompiler().compile(
            manifest: directManifest,
            node: node,
            credential: ProxyCredentialEnvelope(authentication: [
                "method": "aes-128-gcm",
                "password": "synthetic-password",
            ]),
            for: .singBox
        ).json
        let directConfiguration = try configurationForSyntheticDataPlaneTest(
            compiledDirectConfiguration
        )
        try server.startOrReloadService(directConfiguration, options: LibboxOverrideOptions())

        let udpServer = try makeUDPServer()
        let destinationAddress = try firstNonLoopbackIPv4Address()
        defer { Darwin.close(udpServer.descriptor) }
        let requestPayload = Data("routeva-gvisor-request".utf8)
        let requestPacket = ipv4UDPDatagram(
            destinationAddress: destinationAddress,
            destinationPort: udpServer.port,
            payload: requestPayload
        )
        XCTAssertEqual(ipv4HeaderChecksum(Array(requestPacket.prefix(20))), 0)
        try sendPacketFlowDatagram(
            requestPacket,
            to: try XCTUnwrap(platform.latestFlowDescriptor)
        )
        let received: (data: Data, source: sockaddr_storage, sourceLength: socklen_t)
        do {
            received = try receiveUDPDatagram(from: udpServer.descriptor)
        } catch {
            XCTFail(
                "gVisor did not forward the injected PacketFlow UDP datagram; "
                    + "pending core datagram bytes: \(platform.pendingCoreDatagramBytes()); "
                    + platform.debugMessages.suffix(16).joined(separator: " | ")
            )
            return
        }
        XCTAssertEqual(received.data, requestPayload)

        let responsePayload = Data("routeva-gvisor-response".utf8)
        try sendUDPDatagram(
            responsePayload,
            from: udpServer.descriptor,
            to: received.source,
            sourceLength: received.sourceLength
        )
        let returned: Data
        do {
            returned = try receivePacketFlowDatagram(
                from: try XCTUnwrap(platform.latestFlowDescriptor)
            )
        } catch {
            XCTFail("gVisor did not return the UDP response to PacketFlow")
            return
        }
        XCTAssertEqual(Array(returned.prefix(4)), [0, 0, 0, UInt8(AF_INET)])
        XCTAssertTrue(returned.suffix(responsePayload.count).elementsEqual(responsePayload))
    }

    func testCompiledHysteria2PassesLinkedLibboxValidation() throws {
        let nodeID = UUID()
        let credentialReference = "synthetic-credential-\(nodeID.uuidString)"
        let node = NodeRecord(
            id: nodeID,
            subscriptionID: UUID(),
            sortIndex: 0,
            displayName: "TEST-HY2",
            protocolKind: .hysteria2,
            transport: .quic,
            security: .tls,
            requiresUDP: true,
            endpointHost: "hy2.example.invalid",
            endpointPort: 443,
            credentialReference: credentialReference
        )
        let manifest = RuntimeManifest(
            corePolicy: .singBox,
            profile: RuntimeProfile(
                id: nodeID,
                protocolKind: .hysteria2,
                transport: .quic,
                security: .tls,
                requiresUDP: true,
                credential: SecretReference(keychainIdentifier: credentialReference)
            ),
            dnsPreset: .compatibility
        )
        let compiled = try CoreConfigurationCompiler().compile(
            manifest: manifest,
            node: node,
            credential: ProxyCredentialEnvelope(
                authentication: ["password": "synthetic-password"],
                options: ["sni": "hy2.example.invalid"]
            ),
            for: .singBox
        )

        var validationError: NSError?
        XCTAssertTrue(LibboxCheckConfig(compiled.json, &validationError), validationError?.localizedDescription ?? "")
        XCTAssertNil(validationError)
    }

    func testCompiledFirstBatchOutboundsPassLinkedLibboxValidation() throws {
        let cases: [(ProxyProtocol, TransportKind, SecurityKind, Bool, ProxyCredentialEnvelope)] = [
            (
                .anyTLS, .tcp, .tls, true,
                ProxyCredentialEnvelope(
                    authentication: ["password": "anytls-pass"],
                    options: ["sni": "anytls.example.invalid", "min-idle-session": "2"]
                )
            ),
            (
                .socks5, .tcp, .none, true,
                ProxyCredentialEnvelope(
                    authentication: ["username": "socks-user", "password": "socks-pass"]
                )
            ),
            (
                .http, .tcp, .tls, false,
                ProxyCredentialEnvelope(
                    authentication: ["username": "http-user", "password": "http-pass"],
                    options: ["sni": "http.example.invalid"]
                )
            ),
            (
                .tuic, .quic, .tls, true,
                ProxyCredentialEnvelope(
                    authentication: [
                        "uuid": "11111111-2222-3333-4444-555555555555",
                        "password": "tuic-pass",
                    ],
                    options: [
                        "sni": "tuic.example.invalid",
                        "congestion-controller": "bbr",
                        "udp-relay-mode": "native",
                    ]
                )
            ),
        ]

        for (protocolKind, transport, security, requiresUDP, credential) in cases {
            let nodeID = UUID()
            let credentialReference = "synthetic-credential-\(nodeID.uuidString)"
            let node = NodeRecord(
                id: nodeID,
                subscriptionID: UUID(),
                sortIndex: 0,
                displayName: "TEST-\(protocolKind.rawValue.uppercased())",
                protocolKind: protocolKind,
                transport: transport,
                security: security,
                requiresUDP: requiresUDP,
                endpointHost: "\(protocolKind.rawValue).example.invalid",
                endpointPort: 443,
                credentialReference: credentialReference
            )
            let manifest = RuntimeManifest(
                corePolicy: .singBox,
                profile: RuntimeProfile(
                    id: nodeID,
                    protocolKind: protocolKind,
                    transport: transport,
                    security: security,
                    requiresUDP: requiresUDP,
                    credential: SecretReference(keychainIdentifier: credentialReference)
                ),
                dnsPreset: .compatibility
            )
            let compiled = try CoreConfigurationCompiler().compile(
                manifest: manifest,
                node: node,
                credential: credential,
                for: .singBox
            )

            var validationError: NSError?
            XCTAssertTrue(
                LibboxCheckConfig(compiled.json, &validationError),
                "\(protocolKind.rawValue): \(validationError?.localizedDescription ?? "unknown validation error")"
            )
            XCTAssertNil(validationError)
        }
    }

    func testCompiledQueryECHAndCommonTransportsPassLinkedLibboxValidation() throws {
        for (transport, options) in [
            (
                TransportKind.webSocket,
                [
                    "sni": "edge.example.invalid",
                    "ech": "cloudflare-ech.com+https://resolver.example/dns-query",
                    "ws-opts.path": "/socket",
                    "ws-opts.max-early-data": "2048",
                    "ws-opts.early-data-header-name": "Sec-WebSocket-Protocol",
                    "alpn": "[h2, http/1.1]",
                ]
            ),
            (
                TransportKind.http,
                [
                    "sni": "edge.example.invalid",
                    "host": "edge.example.invalid",
                    "path": "/h2",
                ]
            ),
        ] {
            let nodeID = UUID()
            let credentialReference = "synthetic-credential-\(nodeID.uuidString)"
            let node = NodeRecord(
                id: nodeID,
                subscriptionID: UUID(),
                sortIndex: 0,
                displayName: "TEST-VLESS",
                protocolKind: .vless,
                transport: transport,
                security: .tls,
                requiresUDP: true,
                endpointHost: "203.0.113.10",
                endpointPort: 443,
                credentialReference: credentialReference
            )
            let manifest = RuntimeManifest(
                corePolicy: .singBox,
                profile: RuntimeProfile(
                    id: nodeID,
                    protocolKind: .vless,
                    transport: transport,
                    security: .tls,
                    requiresUDP: true,
                    credential: SecretReference(keychainIdentifier: credentialReference)
                ),
                dnsPreset: .automatic,
                dnsBootstrapAddressMap: [
                    "resolver.example": ["203.0.113.53"],
                ]
            )
            let compiled = try CoreConfigurationCompiler().compile(
                manifest: manifest,
                node: node,
                credential: ProxyCredentialEnvelope(
                    authentication: ["uuid": "11111111-2222-3333-4444-555555555555"],
                    options: options
                ),
                for: .singBox
            )

            var validationError: NSError?
            XCTAssertTrue(
                LibboxCheckConfig(compiled.json, &validationError),
                validationError?.localizedDescription ?? ""
            )
            XCTAssertNil(validationError)
        }
    }

    func testCompiledShadowsocksPluginsPassLinkedLibboxValidation() throws {
        let nodeID = UUID()
        let credentialReference = "synthetic-credential-\(nodeID.uuidString)"
        let node = NodeRecord(
            id: nodeID,
            subscriptionID: UUID(),
            sortIndex: 0,
            displayName: "TEST-SS-PLUGIN",
            protocolKind: .shadowsocks,
            transport: .tcp,
            security: .none,
            requiresUDP: true,
            endpointHost: "proxy.example.invalid",
            endpointPort: 8_388,
            credentialReference: credentialReference
        )
        let manifest = RuntimeManifest(
            corePolicy: .singBox,
            profile: RuntimeProfile(
                id: nodeID,
                protocolKind: .shadowsocks,
                transport: .tcp,
                security: .none,
                requiresUDP: true,
                credential: SecretReference(keychainIdentifier: credentialReference)
            ),
            routingMode: .global,
            dnsPreset: .automatic,
            dnsBootstrapAddressMap: [
                "proxy.example.invalid": ["203.0.113.20"],
            ]
        )
        let authentication = [
            "method": "aes-128-gcm",
            "password": "synthetic-password",
        ]
        for pluginOptions in [
            [
                "plugin": "obfs",
                "plugin-opts.mode": "tls",
                "plugin-opts.host": "edge.example.invalid",
            ],
            [
                "plugin": "v2ray-plugin;tls;host=edge.example.invalid;path=/socket",
            ],
        ] {
            let compiled = try CoreConfigurationCompiler().compile(
                manifest: manifest,
                node: node,
                credential: ProxyCredentialEnvelope(
                    authentication: authentication,
                    options: pluginOptions
                ),
                for: .singBox
            )
            var validationError: NSError?
            XCTAssertTrue(
                LibboxCheckConfig(compiled.json, &validationError),
                validationError?.localizedDescription ?? ""
            )
            XCTAssertNil(validationError)
        }
    }

    func testCompleteSmartRulesPassLinkedLibboxValidation() throws {
        let nodeID = UUID()
        let credentialReference = "synthetic-credential-\(nodeID.uuidString)"
        let node = NodeRecord(
            id: nodeID,
            subscriptionID: UUID(),
            sortIndex: 0,
            displayName: "TEST-SMART-SS",
            protocolKind: .shadowsocks,
            transport: .tcp,
            security: .none,
            requiresUDP: true,
            endpointHost: "proxy.example.invalid",
            endpointPort: 8_388,
            credentialReference: credentialReference
        )
        // Match the real subscription scale that exposed the old 4,096-rule
        // sanitizer. The compiler may batch adjacent values for serialization,
        // but Libbox must accept and start with every logical rule retained.
        let bulkDomainRules = (0..<9_815).map { index in
            ProviderRouteRule(
                match: .domainSuffix("bulk-\(index).example"),
                action: .direct
            )
        }
        let manifest = RuntimeManifest(
            corePolicy: .singBox,
            profile: RuntimeProfile(
                id: nodeID,
                protocolKind: .shadowsocks,
                transport: .tcp,
                security: .none,
                requiresUDP: true,
                credential: SecretReference(keychainIdentifier: credentialReference)
            ),
            routingMode: .automatic,
            dnsPreset: .automatic,
            providerRoutePolicy: ProviderRoutePolicy(
                rules: [
                    .init(match: .domainSuffix("supported.example"), action: .direct),
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
                ] + bulkDomainRules,
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
        let compiled = try CoreConfigurationCompiler().compile(
            manifest: manifest,
            node: node,
            credential: ProxyCredentialEnvelope(
                authentication: [
                    "method": "aes-128-gcm",
                    "password": "synthetic-password",
                ],
                options: [
                    "plugin": "obfs",
                    "plugin-opts.mode": "tls",
                    "plugin-opts.host": "edge.example.invalid",
                ]
            ),
            for: .singBox
        )
        XCTAssertTrue(compiled.json.contains("supported.example"))
        XCTAssertTrue(compiled.json.contains("blocked"))
        XCTAssertTrue(compiled.json.contains("10.0.0.0\\/8"))
        XCTAssertTrue(compiled.json.contains("1000:2000"))
        XCTAssertTrue(compiled.json.contains("\"action\":\"sniff\""))
        XCTAssertTrue(compiled.json.contains("\"protocol\":[\"http\"]"))
        XCTAssertTrue(compiled.json.contains("provider-rules"))
        XCTAssertTrue(compiled.json.contains("ruleset.example"))
        XCTAssertTrue(compiled.json.contains("bulk-9814.example"))
        XCTAssertTrue(compiled.json.contains("\"final\":\"direct\""))

        var validationError: NSError?
        XCTAssertTrue(
            LibboxCheckConfig(compiled.json, &validationError),
            validationError?.localizedDescription ?? ""
        )
        XCTAssertNil(validationError)

        let privacyManifest = RuntimeManifest(
            corePolicy: .singBox,
            profile: manifest.profile,
            routingMode: .global,
            dnsPreset: .privacy,
            providerRoutePolicy: manifest.providerRoutePolicy
        )
        let privacyConfiguration = try CoreConfigurationCompiler().compile(
            manifest: privacyManifest,
            node: node,
            credential: ProxyCredentialEnvelope(
                authentication: [
                    "method": "aes-128-gcm",
                    "password": "synthetic-password",
                ],
                options: [
                    "plugin": "obfs",
                    "plugin-opts.mode": "tls",
                    "plugin-opts.host": "edge.example.invalid",
                ]
            ),
            for: .singBox
        ).json
        XCTAssertTrue(privacyConfiguration.contains("9.9.9.10"))
        XCTAssertTrue(privacyConfiguration.contains("dns10.quad9.net"))
        validationError = nil
        XCTAssertTrue(
            LibboxCheckConfig(privacyConfiguration, &validationError),
            validationError?.localizedDescription ?? ""
        )
        XCTAssertNil(validationError)

        let runtimeDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("routeva-libbox-smart-start-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: runtimeDirectory,
            withIntermediateDirectories: true
        )
        let setup = LibboxSetupOptions()
        setup.basePath = runtimeDirectory.path
        setup.workingPath = runtimeDirectory.appendingPathComponent("working", isDirectory: true).path
        setup.tempPath = runtimeDirectory.appendingPathComponent("temporary", isDirectory: true).path
        setup.logMaxLines = 32
        setup.debug = true
        var commandPort: Int32 = 0
        var portError: NSError?
        XCTAssertTrue(LibboxAvailablePort(19_191, &commandPort, &portError))
        XCTAssertNil(portError)
        setup.commandServerListenPort = commandPort
        var setupError: NSError?
        XCTAssertTrue(LibboxSetup(setup, &setupError), setupError?.localizedDescription ?? "")
        XCTAssertNil(setupError)

        let platform = SyntheticPacketFlowPlatform()
        var createError: NSError?
        let server = try XCTUnwrap(LibboxNewCommandServer(platform, platform, &createError))
        defer {
            try? server.closeService()
            server.close()
            platform.closeDescriptors()
        }
        try server.start()
        do {
            try server.startOrReloadService(compiled.json, options: LibboxOverrideOptions())
        } catch {
            XCTFail("Libbox Smart service start failed: \(error.localizedDescription)")
            return
        }
        XCTAssertTrue(platform.didOpenTun)
    }

    func testBinarySmartAndDirectDNSPassLinkedLibboxValidation() throws {
        let nodeID = UUID()
        let credentialReference = "synthetic-credential-\(nodeID.uuidString)"
        let node = NodeRecord(
            id: nodeID,
            subscriptionID: UUID(),
            sortIndex: 0,
            displayName: "TEST-TROJAN",
            protocolKind: .trojan,
            transport: .tcp,
            security: .tls,
            requiresUDP: true,
            endpointHost: "trojan.example.invalid",
            endpointPort: 443,
            credentialReference: credentialReference
        )
        let manifest = RuntimeManifest(
            corePolicy: .singBox,
            profile: RuntimeProfile(
                id: nodeID,
                protocolKind: .trojan,
                transport: .tcp,
                security: .tls,
                requiresUDP: true,
                credential: SecretReference(keychainIdentifier: credentialReference)
            ),
            routingMode: .direct,
            dnsPreset: .compatibility,
            providerRoutePolicy: ProviderRoutePolicy(
                rules: [.init(match: .domainSuffix("ignored.example"), action: .reject)],
                defaultAction: .proxyCurrentNode
            ),
            domainOverrides: [.init(domain: "force.example", action: .proxyCurrentNode)]
        )
        let compiled = try CoreConfigurationCompiler().compile(
            manifest: manifest,
            node: node,
            credential: ProxyCredentialEnvelope(
                authentication: ["password": "synthetic-password"],
                options: ["sni": "trojan.example.invalid"]
            ),
            for: .singBox
        )

        var validationError: NSError?
        XCTAssertTrue(LibboxCheckConfig(compiled.json, &validationError), validationError?.localizedDescription ?? "")
        XCTAssertNil(validationError)
    }

    private func makeUDPServer() throws -> (descriptor: Int32, port: UInt16) {
        let descriptor = Darwin.socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard descriptor >= 0 else { throw POSIXError(.EIO) }
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = 0
        address.sin_addr = in_addr(s_addr: INADDR_ANY)
        let bindResult = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else {
            Darwin.close(descriptor)
            throw POSIXError(.EADDRNOTAVAIL)
        }
        var boundAddress = sockaddr_in()
        var boundLength = socklen_t(MemoryLayout<sockaddr_in>.size)
        let nameResult = withUnsafeMutablePointer(to: &boundAddress) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.getsockname(descriptor, $0, &boundLength)
            }
        }
        guard nameResult == 0 else {
            Darwin.close(descriptor)
            throw POSIXError(.EIO)
        }
        return (descriptor, UInt16(bigEndian: boundAddress.sin_port))
    }

    private func firstNonLoopbackIPv4Address() throws -> [UInt8] {
        var addresses: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addresses) == 0, let first = addresses else {
            throw POSIXError(.EADDRNOTAVAIL)
        }
        defer { freeifaddrs(first) }
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let interface = cursor {
            defer { cursor = interface.pointee.ifa_next }
            guard let address = interface.pointee.ifa_addr,
                  address.pointee.sa_family == sa_family_t(AF_INET),
                  interface.pointee.ifa_flags & UInt32(IFF_UP) != 0,
                  interface.pointee.ifa_flags & UInt32(IFF_LOOPBACK) == 0
            else { continue }
            let ipv4 = UnsafeRawPointer(address).assumingMemoryBound(to: sockaddr_in.self).pointee
            let value = UInt32(bigEndian: ipv4.sin_addr.s_addr)
            return [
                UInt8(value >> 24),
                UInt8((value >> 16) & 0xff),
                UInt8((value >> 8) & 0xff),
                UInt8(value & 0xff),
            ]
        }
        throw POSIXError(.EADDRNOTAVAIL)
    }

    private func configurationForSyntheticDataPlaneTest(_ configuration: String) throws -> String {
        var root = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(configuration.utf8)) as? [String: Any]
        )
        root["log"] = ["disabled": false, "level": "trace"]
        var route = try XCTUnwrap(root["route"] as? [String: Any])
        route["auto_detect_interface"] = false
        root["route"] = route
        return String(
            decoding: try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys]),
            as: UTF8.self
        )
    }

    private func ipv4UDPDatagram(
        destinationAddress: [UInt8],
        destinationPort: UInt16,
        payload: Data
    ) -> Data {
        let headerLength = 20
        let udpHeaderLength = 8
        let totalLength = headerLength + udpHeaderLength + payload.count
        var bytes = [UInt8](repeating: 0, count: totalLength)
        bytes[0] = 0x45
        setUInt16(UInt16(totalLength), in: &bytes, at: 2)
        setUInt16(0x4000, in: &bytes, at: 6)
        bytes[8] = 64
        bytes[9] = UInt8(IPPROTO_UDP)
        bytes.replaceSubrange(12..<16, with: [172, 19, 0, 2])
        bytes.replaceSubrange(16..<20, with: destinationAddress)
        setUInt16(ipv4HeaderChecksum(Array(bytes[0..<headerLength])), in: &bytes, at: 10)
        setUInt16(40_000, in: &bytes, at: headerLength)
        setUInt16(destinationPort, in: &bytes, at: headerLength + 2)
        setUInt16(UInt16(udpHeaderLength + payload.count), in: &bytes, at: headerLength + 4)
        bytes.replaceSubrange((headerLength + udpHeaderLength)..<totalLength, with: payload)
        return Data(bytes)
    }

    private func setUInt16(_ value: UInt16, in bytes: inout [UInt8], at offset: Int) {
        bytes[offset] = UInt8(value >> 8)
        bytes[offset + 1] = UInt8(value & 0xff)
    }

    private func ipv4HeaderChecksum(_ bytes: [UInt8]) -> UInt16 {
        var sum: UInt32 = 0
        for offset in stride(from: 0, to: bytes.count, by: 2) {
            sum += UInt32(bytes[offset]) << 8 | UInt32(bytes[offset + 1])
        }
        while sum > 0xffff { sum = (sum & 0xffff) + (sum >> 16) }
        return UInt16(~sum & 0xffff)
    }

    private func sendPacketFlowDatagram(_ packet: Data, to descriptor: Int32) throws {
        var framed = Data([0, 0, 0, UInt8(AF_INET)])
        framed.append(packet)
        let sent = framed.withUnsafeBytes {
            Darwin.send(descriptor, $0.baseAddress, $0.count, 0)
        }
        guard sent == framed.count else { throw POSIXError(.EIO) }
    }

    private func receiveUDPDatagram(
        from descriptor: Int32
    ) throws -> (data: Data, source: sockaddr_storage, sourceLength: socklen_t) {
        try waitUntilReadable(descriptor)
        var bytes = [UInt8](repeating: 0, count: 4_096)
        var source = sockaddr_storage()
        var sourceLength = socklen_t(MemoryLayout<sockaddr_storage>.size)
        let count = withUnsafeMutablePointer(to: &source) { sourcePointer in
            sourcePointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.recvfrom(descriptor, &bytes, bytes.count, 0, $0, &sourceLength)
            }
        }
        guard count > 0 else { throw POSIXError(.EIO) }
        return (Data(bytes.prefix(count)), source, sourceLength)
    }

    private func sendUDPDatagram(
        _ data: Data,
        from descriptor: Int32,
        to destination: sockaddr_storage,
        sourceLength: socklen_t
    ) throws {
        var destination = destination
        let sent = data.withUnsafeBytes { bytes in
            withUnsafePointer(to: &destination) { destinationPointer in
                destinationPointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    Darwin.sendto(
                        descriptor,
                        bytes.baseAddress,
                        bytes.count,
                        0,
                        $0,
                        sourceLength
                    )
                }
            }
        }
        guard sent == data.count else { throw POSIXError(.EIO) }
    }

    private func receivePacketFlowDatagram(from descriptor: Int32) throws -> Data {
        try waitUntilReadable(descriptor)
        var bytes = [UInt8](repeating: 0, count: 4_100)
        let count = Darwin.recv(descriptor, &bytes, bytes.count, 0)
        guard count > 0 else { throw POSIXError(.EIO) }
        return Data(bytes.prefix(count))
    }

    private func waitUntilReadable(_ descriptor: Int32) throws {
        var pollDescriptor = pollfd(fd: descriptor, events: Int16(POLLIN), revents: 0)
        guard Darwin.poll(&pollDescriptor, 1, 2_000) == 1 else {
            throw POSIXError(.ETIMEDOUT)
        }
    }
}

private final class SyntheticPacketFlowPlatform: NSObject,
    LibboxPlatformInterfaceProtocol,
    LibboxCommandServerHandlerProtocol,
    LibboxCommandClientHandlerProtocol
{
    private let debugMessageLock = NSLock()
    private let groupCondition = NSCondition()
    private var storedDebugMessages: [String] = []
    private var sawRoutevaProbeGroup = false
    private var selectedOutboundTag: String?
    private var descriptors: [Int32] = []
    private(set) var didOpenTun = false
    private(set) var latestCoreDescriptor: Int32?
    private(set) var latestFlowDescriptor: Int32?

    var debugMessages: [String] {
        debugMessageLock.withLock { storedDebugMessages }
    }

    func waitForRoutevaProbeGroup(timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        groupCondition.lock()
        defer { groupCondition.unlock() }
        while !sawRoutevaProbeGroup {
            guard groupCondition.wait(until: deadline) else { return false }
        }
        return true
    }

    func waitForSelectedOutboundTag(
        _ expectedTag: String,
        timeout: TimeInterval
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        groupCondition.lock()
        defer { groupCondition.unlock() }
        while selectedOutboundTag != expectedTag {
            guard groupCondition.wait(until: deadline) else { return false }
        }
        return true
    }

    func openTun(_ options: LibboxTunOptionsProtocol?, ret0_: UnsafeMutablePointer<Int32>?) throws {
        guard options != nil, let ret0_ else { throw SyntheticPlatformError.invalidRequest }
        var pair: [Int32] = [-1, -1]
        guard socketpair(AF_UNIX, SOCK_DGRAM, 0, &pair) == 0 else {
            throw SyntheticPlatformError.socketPairFailed
        }
        descriptors.append(contentsOf: pair)
        didOpenTun = true
        latestCoreDescriptor = pair[0]
        latestFlowDescriptor = pair[1]
        ret0_.pointee = pair[0]
    }

    func pendingCoreDatagramBytes() -> Int {
        guard let descriptor = latestCoreDescriptor else { return -1 }
        var bytes = [UInt8](repeating: 0, count: 4_100)
        let count = Darwin.recv(descriptor, &bytes, bytes.count, MSG_PEEK | MSG_DONTWAIT)
        if count >= 0 { return count }
        return Darwin.errno == EAGAIN || Darwin.errno == EWOULDBLOCK ? 0 : -Int(Darwin.errno)
    }

    func closeDescriptors() {
        for descriptor in descriptors where descriptor >= 0 {
            Darwin.close(descriptor)
        }
        descriptors.removeAll()
        latestCoreDescriptor = nil
        latestFlowDescriptor = nil
    }

    func usePlatformAutoDetectControl() -> Bool { false }
    func usePlatformPacketFlowBridge() -> Bool { true }
    func autoDetectControl(_ fd: Int32) throws {}
    func useProcFS() -> Bool { false }
    func underNetworkExtension() -> Bool { true }
    func includeAllNetworks() -> Bool { false }
    func localDNSTransport() -> LibboxLocalDNSTransportProtocol? { nil }
    func systemCertificates() -> LibboxStringIteratorProtocol? { nil }
    func readWIFIState() -> LibboxWIFIState? { nil }
    func send(_ notification: LibboxNotification?) throws {}
    func clearDNSCache() {}

    func findConnectionOwner(
        _ ipProtocol: Int32,
        sourceAddress: String?,
        sourcePort: Int32,
        destinationAddress: String?,
        destinationPort: Int32
    ) throws -> LibboxConnectionOwner {
        throw SyntheticPlatformError.invalidRequest
    }

    func startDefaultInterfaceMonitor(_ listener: LibboxInterfaceUpdateListenerProtocol?) throws {}
    func closeDefaultInterfaceMonitor(_ listener: LibboxInterfaceUpdateListenerProtocol?) throws {}
    func getInterfaces() throws -> LibboxNetworkInterfaceIteratorProtocol {
        SyntheticNetworkInterfaceIterator()
    }

    func serviceStop() throws {}
    func serviceReload() throws {}
    func getSystemProxyStatus() throws -> LibboxSystemProxyStatus {
        let status = LibboxSystemProxyStatus()
        status.available = false
        status.enabled = false
        return status
    }
    func setSystemProxyEnabled(_ enabled: Bool) throws {}
    func writeDebugMessage(_ message: String?) {
        guard let message else { return }
        debugMessageLock.withLock { storedDebugMessages.append(message) }
    }

    func clearLogs() {}
    func connected() {}
    func disconnected(_ message: String?) {}
    func initializeClashMode(_ modeList: LibboxStringIteratorProtocol?, currentMode: String?) {}
    func setDefaultLogLevel(_ level: Int32) {}
    func updateClashMode(_ newMode: String?) {}
    func write(_ events: LibboxConnectionEvents?) {}
    func writeGroups(_ message: LibboxOutboundGroupIteratorProtocol?) {
        guard let message else { return }
        var foundProbe = false
        var reportedSelection: String?
        while message.hasNext() {
            guard let group = message.next() else { continue }
            if group.tag == "routeva-probe" { foundProbe = true }
            if group.tag == SingBoxNodeSelector.groupTag {
                reportedSelection = group.selected
            }
        }
        groupCondition.lock()
        if foundProbe { sawRoutevaProbeGroup = true }
        if let reportedSelection { selectedOutboundTag = reportedSelection }
        groupCondition.broadcast()
        groupCondition.unlock()
    }
    func writeLogs(_ messageList: LibboxLogIteratorProtocol?) {}
    func writeStatus(_ message: LibboxStatusMessage?) {}
}

private final class SyntheticNetworkInterfaceIterator: NSObject, LibboxNetworkInterfaceIteratorProtocol {
    func hasNext() -> Bool { false }
    func next() -> LibboxNetworkInterface? { nil }
}

private enum SyntheticPlatformError: Error {
    case invalidRequest
    case socketPairFailed
}
