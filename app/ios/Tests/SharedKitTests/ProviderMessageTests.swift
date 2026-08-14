import Foundation
import SharedKit
import XCTest

final class ProviderMessageTests: XCTestCase {
    func testProviderStatusRefreshGateCoalescesABurstWithoutDiscardingCurrentPass() {
        var gate = ProviderStatusRefreshGate()

        XCTAssertTrue(gate.requestRefresh())
        XCTAssertFalse(gate.requestRefresh())
        XCTAssertFalse(gate.requestRefresh())
        XCTAssertTrue(gate.finishPass())
        XCTAssertFalse(gate.finishPass())
        XCTAssertTrue(gate.requestRefresh())
    }

    func testProviderConnectionSnapshotKeepsReassertingVisibleAsConnected() {
        let since = Date(timeIntervalSinceReferenceDate: 1_000)
        let connected = ProviderConnectionSnapshot.connected(
            core: .singBox,
            since: since
        )
        let reasserting = ProviderConnectionSnapshot.reasserting(
            core: .singBox,
            since: since
        )

        XCTAssertTrue(connected.presentsAsConnected)
        XCTAssertTrue(reasserting.presentsAsConnected)
        XCTAssertEqual(connected.core, .singBox)
        XCTAssertEqual(reasserting.connectedSince, since)
    }

    func testProviderConnectionSnapshotDoesNotPresentTransitionsAsConnected() {
        let snapshots: [ProviderConnectionSnapshot] = [
            .disconnected,
            .connecting(core: .singBox),
            .disconnecting(core: .singBox),
        ]

        XCTAssertTrue(snapshots.allSatisfy { !$0.presentsAsConnected })
        XCTAssertNil(ProviderConnectionSnapshot.disconnected.core)
        XCTAssertNil(ProviderConnectionSnapshot.connecting(core: .singBox).connectedSince)
    }

    func testClassifiesRedactedCoreDNSFailures() {
        XCTAssertEqual(
            CoreLogDiagnosticClassifier.stableCode(
                level: 2,
                message: "dns/https[dns-remote]: exchange failed for private.example. IN A: dial tcp: i/o timeout"
            ),
            "probe.core_dns_remote_timeout"
        )
        XCTAssertEqual(
            CoreLogDiagnosticClassifier.stableCode(
                level: 2,
                message: "dns/https[dns-real]: exchange failed for private.example. IN A: unexpected eof"
            ),
            "probe.core_dns_remote_transport_failed"
        )
        XCTAssertEqual(
            CoreLogDiagnosticClassifier.stableCode(
                level: 2,
                message: "dns/udp[dns-bootstrap]: lookup failed for private.example: network is unreachable"
            ),
            "probe.core_dns_bootstrap_unreachable"
        )
        XCTAssertNil(CoreLogDiagnosticClassifier.stableCode(
            level: 4,
            message: "dns/https[dns-remote]: successful query for private.example"
        ))
        XCTAssertNil(CoreLogDiagnosticClassifier.stableCode(
            level: 2,
            message: "outbound connection to private.example closed"
        ))
    }

    func testClassifiesProxyFailuresWithoutRetainingDestinations() {
        XCTAssertEqual(
            CoreLogDiagnosticClassifier.stableCode(
                level: 2,
                message: "open connection to private.example:443 using outbound/shadowsocks[proxy]: dial tcp 192.0.2.1:443: i/o timeout"
            ),
            "probe.core_proxy_timeout"
        )
        XCTAssertEqual(
            CoreLogDiagnosticClassifier.stableCode(
                level: 2,
                message: "open packet connection to private.example:443 using outbound/vmess[proxy]: connection refused"
            ),
            "probe.core_proxy_refused"
        )
        XCTAssertEqual(
            CoreLogDiagnosticClassifier.stableCode(
                level: 2,
                message: "open connection to private.example:443 using outbound/trojan[proxy]: tls handshake: x509 certificate error"
            ),
            "probe.core_proxy_tls_failed"
        )
        XCTAssertNil(CoreLogDiagnosticClassifier.stableCode(
            level: 2,
            message: "open connection to private.example:443 using outbound/direct[direct]: i/o timeout"
        ))
        XCTAssertEqual(
            CoreLogDiagnosticClassifier.stableCode(
                level: 2,
                message: "connection download handshake: unexpected EOF from private.example"
            ),
            "probe.core_connection_handshake_failed"
        )
    }

    func testClassifiesRuntimeNodeAndECHFailuresAsProxyFailures() {
        XCTAssertEqual(
            CoreLogDiagnosticClassifier.stableCode(
                level: 2,
                message: "open connection to private.example:443 using outbound/vless[routeva-node-00000000-0000-0000-0000-000000000000]: dial tcp: i/o timeout"
            ),
            "probe.core_proxy_timeout"
        )
        XCTAssertEqual(
            CoreLogDiagnosticClassifier.stableCode(
                level: 2,
                message: "open connection to private.example:443 using outbound/vless[routeva-node-00000000-0000-0000-0000-000000000000]: fetch ECH config list: exchange failed for private-ech.example. IN HTTPS"
            ),
            "probe.core_proxy_ech_dns_failed"
        )
        XCTAssertEqual(
            CoreLogDiagnosticClassifier.stableCode(
                level: 2,
                message: "open connection to private.example:443 using outbound/vless[routeva-node-00000000-0000-0000-0000-000000000000]: no ECH config found in DNS records"
            ),
            "probe.core_proxy_ech_record_missing"
        )
        XCTAssertEqual(
            CoreLogDiagnosticClassifier.stableCode(
                level: 2,
                message: "open connection to private.example:443 using outbound/vless[routeva-node-00000000-0000-0000-0000-000000000000]: websocket: bad status"
            ),
            "probe.core_proxy_websocket_failed"
        )
        XCTAssertEqual(
            CoreLogDiagnosticClassifier.stableCode(
                level: 4,
                message: "open connection to private.example:443 using outbound/vless[routeva-node-00000000-0000-0000-0000-000000000000]: unexpected HTTP response status: 403"
            ),
            "probe.core_proxy_websocket_failed"
        )
        XCTAssertEqual(
            CoreLogDiagnosticClassifier.stableCode(
                level: 2,
                message: "open connection to private.example:443 using outbound/vless[routeva-node-00000000-0000-0000-0000-000000000000]: read tcp: use of closed network connection"
            ),
            "probe.core_proxy_cancelled"
        )
        XCTAssertEqual(
            CoreLogDiagnosticClassifier.stableCode(
                level: 2,
                message: "open connection to private.example:443 using outbound/vless[routeva-node-00000000-0000-0000-0000-000000000000]: tls: encrypted client hello rejected"
            ),
            "probe.core_proxy_ech_rejected"
        )
        XCTAssertEqual(
            CoreLogDiagnosticClassifier.stableCode(
                level: 2,
                message: "open connection to private.example:443 using outbound/vless[routeva-node-00000000-0000-0000-0000-000000000000]: ECH rejected without retry config: tls: server rejected ECH"
            ),
            "probe.core_proxy_ech_no_retry_config"
        )
        XCTAssertEqual(
            CoreLogDiagnosticClassifier.stableCode(
                level: 2,
                message: "open connection to private.example:443 using outbound/vless[routeva-node-00000000-0000-0000-0000-000000000000]: ECH retry rejected: tls: server rejected ECH"
            ),
            "probe.core_proxy_ech_retry_rejected"
        )
        XCTAssertEqual(
            CoreLogDiagnosticClassifier.stableCode(
                level: 2,
                message: "open connection to private.example:443 using outbound/vless[routeva-node-00000000-0000-0000-0000-000000000000]: ECH retry unsupported by TLS config: tls: server rejected ECH"
            ),
            "probe.core_proxy_ech_retry_unsupported"
        )
        XCTAssertEqual(
            CoreLogDiagnosticClassifier.stableCode(
                level: 2,
                message: "open connection to private.example:443 using outbound/vless[routeva-node-00000000-0000-0000-0000-000000000000]: remote error: tls: handshake failure"
            ),
            "probe.core_proxy_tls_failed"
        )
        XCTAssertGreaterThan(
            CoreLogDiagnosticClassifier.priority(of: "probe.core_proxy_ech_rejected"),
            CoreLogDiagnosticClassifier.priority(of: "probe.core_dns_upstream_failed")
        )
        XCTAssertGreaterThan(
            CoreLogDiagnosticClassifier.priority(of: "probe.core_proxy_websocket_failed"),
            CoreLogDiagnosticClassifier.priority(of: "probe.core_dns_upstream_failed")
        )
    }

    func testCoreDNSCategoryRefinesMissingDNSResponse() {
        let snapshot = ProviderDataPlaneSnapshot(
            sessionID: UUID(),
            packetFlowToCorePackets: 1,
            packetFlowToCoreBytes: 64,
            coreToPacketFlowPackets: 1,
            coreToPacketFlowBytes: 64,
            packetFlowToCoreDNSQueries: 1,
            coreToPacketFlowDNSResponses: 0,
            coreDiagnosticCode: "probe.core_dns_remote_timeout"
        )
        XCTAssertEqual(
            snapshot.probeFailureDiagnosticCode(fallback: "probe.transport_failed"),
            "probe.core_dns_remote_timeout"
        )
    }

    func testTrafficResponseRoundTripRequiresMatchingRequest() throws {
        let request = ProviderMessageRequest(kind: .traffic)
        let requestData = try ProviderMessageCodec.encode(request)
        XCTAssertEqual(try ProviderMessageCodec.decodeRequest(requestData), request)

        let snapshot = ProviderTrafficSnapshot(
            sessionID: UUID(),
            uploadedBytes: 42,
            downloadedBytes: 84
        )
        let responseData = try ProviderMessageCodec.encode(ProviderMessageResponse(
            requestID: request.requestID,
            traffic: snapshot
        ))
        let response = try ProviderMessageCodec.decodeResponse(responseData, matching: request)
        XCTAssertEqual(response.traffic, snapshot)
    }

    func testNodeSelectionMessagesRoundTripOnlyUUIDState() throws {
        let nodeID = UUID()
        let request = ProviderMessageRequest(kind: .selectNode, nodeID: nodeID)
        let encodedRequest = try ProviderMessageCodec.encode(request)
        XCTAssertEqual(try ProviderMessageCodec.decodeRequest(encodedRequest), request)

        let responseData = try ProviderMessageCodec.encode(ProviderMessageResponse(
            requestID: request.requestID,
            selectedNodeID: nodeID
        ))
        let response = try ProviderMessageCodec.decodeResponse(
            responseData,
            matching: request
        )
        XCTAssertEqual(response.selectedNodeID, nodeID)
        XCTAssertLessThan(responseData.count, ProviderMessageRequest.maximumEncodedBytes)
    }

    func testConfigurationReloadMessageCarriesOnlyManifestIdentifier() throws {
        let manifestID = UUID()
        let request = ProviderMessageRequest(
            kind: .reloadConfiguration,
            manifestID: manifestID
        )
        let encoded = try ProviderMessageCodec.encode(request)
        let decoded = try ProviderMessageCodec.decodeRequest(encoded)

        XCTAssertEqual(decoded, request)
        XCTAssertEqual(decoded.manifestID, manifestID)
        XCTAssertNil(decoded.nodeID)
        XCTAssertNil(decoded.acceptConfigurationReload)
        XCTAssertNil(decoded.tunnelProbeAddressSets)
        XCTAssertLessThan(encoded.count, ProviderMessageRequest.maximumEncodedBytes)
    }

    func testConfigurationReloadFinalizationRoundTripsDecisionAndExpectedNode() throws {
        let nodeID = UUID()
        let request = ProviderMessageRequest(
            kind: .finalizeConfigurationReload,
            nodeID: nodeID,
            acceptConfigurationReload: false
        )
        let decoded = try ProviderMessageCodec.decodeRequest(
            ProviderMessageCodec.encode(request)
        )

        XCTAssertEqual(decoded, request)
        XCTAssertEqual(decoded.nodeID, nodeID)
        XCTAssertEqual(decoded.acceptConfigurationReload, false)
        XCTAssertNil(decoded.manifestID)
    }

    func testUserVisibleTrafficUsesPacketFlowConsistentlyWithCoreOnlyFallback() {
        let sessionID = UUID()
        let packetFlowFallback = ProviderTrafficSnapshot.userVisible(
            sessionID: sessionID,
            coreUploadedBytes: 0,
            coreDownloadedBytes: 12,
            packetFlowUploadedBytes: 2_048,
            packetFlowDownloadedBytes: 8_192
        )
        XCTAssertEqual(packetFlowFallback.sessionID, sessionID)
        XCTAssertEqual(packetFlowFallback.uploadedBytes, 2_048)
        XCTAssertEqual(packetFlowFallback.downloadedBytes, 8_192)

        let stablePacketFlow = ProviderTrafficSnapshot.userVisible(
            sessionID: sessionID,
            coreUploadedBytes: 4_096,
            coreDownloadedBytes: 16_384,
            packetFlowUploadedBytes: 2_048,
            packetFlowDownloadedBytes: 8_192
        )
        XCTAssertEqual(stablePacketFlow.uploadedBytes, 2_048)
        XCTAssertEqual(stablePacketFlow.downloadedBytes, 8_192)

        let coreFallback = ProviderTrafficSnapshot.userVisible(
            sessionID: sessionID,
            coreUploadedBytes: 4_096,
            coreDownloadedBytes: 16_384,
            packetFlowUploadedBytes: 0,
            packetFlowDownloadedBytes: 0
        )
        XCTAssertEqual(coreFallback.uploadedBytes, 4_096)
        XCTAssertEqual(coreFallback.downloadedBytes, 16_384)
    }

    func testEntryLatencyRequestRoundTripsNodeIDsWithoutEndpoints() throws {
        let nodeIDs = [UUID(), UUID(), UUID()]
        let request = ProviderMessageRequest(
            kind: .entryLatency,
            entryLatencyNodeIDs: nodeIDs
        )
        let encoded = try ProviderMessageCodec.encode(request)
        XCTAssertLessThan(encoded.count, ProviderMessageRequest.maximumEncodedBytes)
        XCTAssertEqual(try ProviderMessageCodec.decodeRequest(encoded), request)
        XCTAssertFalse(String(decoding: encoded, as: UTF8.self).contains("endpoint"))
    }

    func testEntryLatencyResponseRoundTripsSamplesAndLegacyResponsesStayDecodable() throws {
        let request = ProviderMessageRequest(kind: .entryLatency)
        let samples = [
            ProviderEntryLatencySample(nodeID: UUID(), milliseconds: 42),
            ProviderEntryLatencySample(nodeID: UUID(), milliseconds: nil),
        ]
        let encoded = try ProviderMessageCodec.encode(ProviderMessageResponse(
            requestID: request.requestID,
            entryLatencies: samples
        ))
        let response = try ProviderMessageCodec.decodeResponse(encoded, matching: request)
        XCTAssertEqual(response.entryLatencies, samples)

        let legacy = try ProviderMessageCodec.encode(ProviderMessageResponse(
            requestID: request.requestID,
            status: .running
        ))
        let decodedLegacy = try ProviderMessageCodec.decodeResponse(legacy, matching: request)
        XCTAssertNil(decodedLegacy.entryLatencies)
    }

    func testEntryLatencyUnavailableCodeIsRejectedByCodec() throws {
        let request = ProviderMessageRequest(kind: .entryLatency)
        let encoded = try ProviderMessageCodec.encode(ProviderMessageResponse(
            requestID: request.requestID,
            errorCode: ProviderEntryLatencyCode.physicalPathUnavailable
        ))
        XCTAssertThrowsError(try ProviderMessageCodec.decodeResponse(encoded, matching: request)) {
            XCTAssertEqual(
                $0 as? ProviderMessageCodecError,
                .providerRejected(ProviderEntryLatencyCode.physicalPathUnavailable)
            )
        }
    }

    func testCoreProbeResponseRoundTripsOnlyLatency() throws {
        let request = ProviderMessageRequest(kind: .coreProbe)
        let snapshot = ProviderCoreProbeSnapshot(latencyMilliseconds: 86)
        let responseData = try ProviderMessageCodec.encode(ProviderMessageResponse(
            requestID: request.requestID,
            coreProbe: snapshot
        ))

        let response = try ProviderMessageCodec.decodeResponse(
            responseData,
            matching: request
        )
        XCTAssertEqual(response.coreProbe, snapshot)
        XCTAssertLessThan(responseData.count, ProviderMessageRequest.maximumEncodedBytes)
    }

    func testCoreProbeRequestRoundTripsPreTunnelIPv4Candidates() throws {
        let request = ProviderMessageRequest(
            kind: .coreProbe,
            tunnelProbeAddressSets: [
                ProviderTunnelProbeAddressSet(
                    host: "www.gstatic.com",
                    ipv4Addresses: ["142.250.72.131"]
                ),
                ProviderTunnelProbeAddressSet(
                    host: "cp.cloudflare.com",
                    ipv4Addresses: ["104.16.132.229", "104.16.133.229"]
                ),
            ]
        )
        let encoded = try ProviderMessageCodec.encode(request)
        XCTAssertLessThan(encoded.count, ProviderMessageRequest.maximumEncodedBytes)
        XCTAssertEqual(try ProviderMessageCodec.decodeRequest(encoded), request)
    }

    func testTrafficRateSamplerKeepsRecentBaselineAndRejectsStaleOrNewSession() {
        let sessionID = UUID()
        let start = Date(timeIntervalSinceReferenceDate: 1_000)
        var sampler = ProviderTrafficRateSampler(maximumBaselineAge: 2)

        XCTAssertNil(sampler.sample(
            ProviderTrafficSnapshot(
                sessionID: sessionID,
                uploadedBytes: 1_000,
                downloadedBytes: 2_000
            ),
            at: start
        ))
        XCTAssertEqual(
            sampler.sample(
                ProviderTrafficSnapshot(
                    sessionID: sessionID,
                    uploadedBytes: 126_000,
                    downloadedBytes: 252_000
                ),
                at: start.addingTimeInterval(0.5)
            ),
            ProviderTrafficRate(uploadMbps: 2, downloadMbps: 4)
        )
        XCTAssertEqual(
            sampler.sample(
                ProviderTrafficSnapshot(
                    sessionID: sessionID,
                    uploadedBytes: 126_000,
                    downloadedBytes: 252_000
                ),
                at: start.addingTimeInterval(1)
            ),
            ProviderTrafficRate(uploadMbps: 1, downloadMbps: 2)
        )
        XCTAssertNil(sampler.sample(
            ProviderTrafficSnapshot(
                sessionID: sessionID,
                uploadedBytes: 127_000,
                downloadedBytes: 253_000
            ),
            at: start.addingTimeInterval(5)
        ))
        XCTAssertNil(sampler.sample(
            ProviderTrafficSnapshot(
                sessionID: UUID(),
                uploadedBytes: 10,
                downloadedBytes: 20
            ),
            at: start.addingTimeInterval(5.5)
        ))
    }

    func testTunnelProbeSuccessRoundTripsWithoutFabricatedLatency() throws {
        let request = ProviderMessageRequest(kind: .coreProbe)
        let responseData = try ProviderMessageCodec.encode(ProviderMessageResponse(
            requestID: request.requestID,
            tunnelProbeSucceeded: true
        ))

        let response = try ProviderMessageCodec.decodeResponse(
            responseData,
            matching: request
        )
        XCTAssertEqual(response.tunnelProbeSucceeded, true)
        XCTAssertNil(response.coreProbe)
        XCTAssertNil(response.errorCode)
    }

    func testCoreURLTestResultTrackerIgnoresFailuresAndWakesForSuccess() {
        let tracker = CoreURLTestResultTracker()
        tracker.record(testTime: 0, latencyMilliseconds: 0)
        XCTAssertNil(tracker.currentLatencyMilliseconds())

        DispatchQueue.global().asyncAfter(deadline: .now() + 0.01) {
            tracker.record(testTime: 1_786_320_000, latencyMilliseconds: 31)
        }
        XCTAssertEqual(tracker.waitForSuccess(timeout: 1), 31)

        tracker.reset()
        XCTAssertNil(tracker.currentLatencyMilliseconds())
    }

    func testSingBoxSelectorTrackerUsesAuthoritativeGroupSelection() {
        let tracker = SingBoxSelectorSelectionTracker()
        let nodeID = UUID()

        tracker.record(selectedOutboundTag: "not-a-routeva-node")
        XCTAssertNil(tracker.currentNodeID())

        DispatchQueue.global().asyncAfter(deadline: .now() + 0.01) {
            tracker.record(
                selectedOutboundTag: SingBoxNodeSelector.outboundTag(for: nodeID)
            )
        }
        XCTAssertTrue(tracker.waitForSelection(nodeID, timeout: 1))
        XCTAssertEqual(tracker.currentNodeID(), nodeID)

        tracker.reset()
        XCTAssertNil(tracker.currentNodeID())
    }

    func testMismatchedResponseIsRejected() throws {
        let request = ProviderMessageRequest(kind: .status)
        let responseData = try ProviderMessageCodec.encode(ProviderMessageResponse(
            requestID: UUID(),
            status: .running
        ))
        XCTAssertThrowsError(try ProviderMessageCodec.decodeResponse(responseData, matching: request)) {
            XCTAssertEqual($0 as? ProviderMessageCodecError, .mismatchedResponse)
        }
    }

    func testDataPlaneResponseRoundTripsOnlyCounters() throws {
        let request = ProviderMessageRequest(kind: .dataPlane)
        let snapshot = ProviderDataPlaneSnapshot(
            sessionID: UUID(),
            packetFlowToCorePackets: 2,
            packetFlowToCoreBytes: 120,
            coreToPacketFlowPackets: 1,
            coreToPacketFlowBytes: 80,
            packetFlowToCoreDNSQueries: 1,
            coreToPacketFlowDNSResponses: 1,
            coreToPacketFlowDNSSuccessResponses: 1,
            coreToPacketFlowDNSEmptyResponses: 2,
            coreToPacketFlowDNSNameErrorResponses: 3,
            coreToPacketFlowDNSServerFailureResponses: 4,
            coreToPacketFlowDNSOtherErrorResponses: 5,
            packetFlowToCoreTCPSYNPackets: 1,
            coreToPacketFlowTCPSYNACKPackets: 1,
            packetFlowToCoreIPv4TCPSYNPackets: 1,
            coreToPacketFlowIPv4TCPSYNACKPackets: 1,
            packetFlowToCoreIPv4TCPDataPackets: 2,
            packetFlowToCoreIPv6TCPDataPackets: 3,
            coreToPacketFlowIPv4TCPDataPackets: 4,
            coreToPacketFlowIPv6TCPDataPackets: 5
        )
        let data = try ProviderMessageCodec.encode(ProviderMessageResponse(
            requestID: request.requestID,
            dataPlane: snapshot
        ))

        let response = try ProviderMessageCodec.decodeResponse(data, matching: request)
        XCTAssertEqual(response.dataPlane, snapshot)
        XCTAssertLessThan(data.count, ProviderMessageRequest.maximumEncodedBytes)
    }

    func testDataPlaneDiagnosticLocalizesProtocolMilestones() {
        let base = ProviderDataPlaneSnapshot(
            sessionID: UUID(),
            packetFlowToCorePackets: 3,
            packetFlowToCoreBytes: 180,
            coreToPacketFlowPackets: 1,
            coreToPacketFlowBytes: 80,
            packetFlowToCoreDNSQueries: 1,
            coreToPacketFlowDNSResponses: 1,
            packetFlowToCoreTCPSYNPackets: 1
        )
        XCTAssertEqual(
            base.probeFailureDiagnosticCode(fallback: "probe.transport_failed"),
            "probe.tcp_handshake_timeout"
        )

        let reset = ProviderDataPlaneSnapshot(
            sessionID: UUID(),
            packetFlowToCorePackets: 3,
            packetFlowToCoreBytes: 180,
            coreToPacketFlowPackets: 2,
            coreToPacketFlowBytes: 100,
            packetFlowToCoreDNSQueries: 1,
            coreToPacketFlowDNSResponses: 1,
            packetFlowToCoreTCPSYNPackets: 1,
            coreToPacketFlowTCPRSTPackets: 1
        )
        XCTAssertEqual(
            reset.probeFailureDiagnosticCode(fallback: "probe.transport_failed"),
            "probe.tcp_reset"
        )

        let tls = ProviderDataPlaneSnapshot(
            sessionID: UUID(),
            packetFlowToCorePackets: 3,
            packetFlowToCoreBytes: 180,
            coreToPacketFlowPackets: 3,
            coreToPacketFlowBytes: 180,
            packetFlowToCoreDNSQueries: 1,
            coreToPacketFlowDNSResponses: 1,
            packetFlowToCoreTCPSYNPackets: 1,
            coreToPacketFlowTCPSYNACKPackets: 1,
            packetFlowToCoreTCPDataPackets: 1,
            coreToPacketFlowTCPDataPackets: 1
        )
        XCTAssertEqual(
            tls.probeFailureDiagnosticCode(fallback: "probe.transport_failed"),
            "probe.tls_or_http_timeout"
        )
    }

    func testDataPlaneDiagnosticSeparatesHandshakeFromProxyChain() {
        // SYN-ACK without any payload from the app: the three-way handshake
        // never completed, so the failure is in the bridge/stack, not proxy.
        let handshakeStalled = ProviderDataPlaneSnapshot(
            sessionID: UUID(),
            packetFlowToCorePackets: 3,
            packetFlowToCoreBytes: 180,
            coreToPacketFlowPackets: 6,
            coreToPacketFlowBytes: 360,
            packetFlowToCoreDNSQueries: 1,
            coreToPacketFlowDNSResponses: 1,
            packetFlowToCoreTCPSYNPackets: 1,
            coreToPacketFlowTCPSYNACKPackets: 6
        )
        XCTAssertEqual(
            handshakeStalled.probeFailureDiagnosticCode(fallback: "probe.tunnel_transport_failed"),
            "probe.tcp_handshake_incomplete"
        )

        // Payload left the app but nothing came back: TLS bytes vanished in
        // the proxy chain (server silently dropping, wrong plugin/cipher...).
        let proxySilent = ProviderDataPlaneSnapshot(
            sessionID: UUID(),
            packetFlowToCorePackets: 5,
            packetFlowToCoreBytes: 700,
            coreToPacketFlowPackets: 3,
            coreToPacketFlowBytes: 180,
            packetFlowToCoreDNSQueries: 1,
            coreToPacketFlowDNSResponses: 1,
            packetFlowToCoreTCPSYNPackets: 1,
            coreToPacketFlowTCPSYNACKPackets: 1,
            packetFlowToCoreTCPDataPackets: 2
        )
        XCTAssertEqual(
            proxySilent.probeFailureDiagnosticCode(fallback: "probe.tunnel_transport_failed"),
            "probe.proxy_response_missing"
        )

        // Bidirectional payload but TLS/HTTP still failed.
        let bidirectionalData = ProviderDataPlaneSnapshot(
            sessionID: UUID(),
            packetFlowToCorePackets: 6,
            packetFlowToCoreBytes: 900,
            coreToPacketFlowPackets: 6,
            coreToPacketFlowBytes: 900,
            packetFlowToCoreTCPSYNPackets: 1,
            coreToPacketFlowTCPSYNACKPackets: 1,
            packetFlowToCoreTCPDataPackets: 2,
            coreToPacketFlowTCPDataPackets: 2
        )
        XCTAssertEqual(
            bidirectionalData.probeFailureDiagnosticCode(fallback: "probe.tunnel_transport_failed"),
            "probe.tls_or_http_timeout"
        )
        XCTAssertEqual(
            bidirectionalData.probeFailureDiagnosticCode(
                fallback: "probe.tunnel_http_body_mismatch"
            ),
            "probe.tunnel_http_body_mismatch"
        )
        XCTAssertEqual(
            bidirectionalData.probeFailureDiagnosticCode(
                fallback: "probe.tunnel_http_response_too_large"
            ),
            "probe.tunnel_http_response_too_large"
        )
        XCTAssertEqual(
            bidirectionalData.probeFailureDiagnosticCode(
                fallback: "probe.tunnel_probe_ipc_failed"
            ),
            "probe.tunnel_probe_ipc_failed"
        )

        // A classified core proxy failure still overrides the data split.
        let proxyFailure = ProviderDataPlaneSnapshot(
            sessionID: UUID(),
            packetFlowToCorePackets: 5,
            packetFlowToCoreBytes: 700,
            coreToPacketFlowPackets: 3,
            coreToPacketFlowBytes: 180,
            packetFlowToCoreTCPSYNPackets: 1,
            coreToPacketFlowTCPSYNACKPackets: 1,
            packetFlowToCoreTCPDataPackets: 2,
            coreDiagnosticCode: "probe.core_proxy_timeout"
        )
        XCTAssertEqual(
            proxyFailure.probeFailureDiagnosticCode(fallback: "probe.tunnel_transport_failed"),
            "probe.core_proxy_timeout"
        )
    }

    func testIPCFailureFallbackRequiresSameSessionBidirectionalIPv4Deltas() {
        let sessionID = UUID()
        let baseline = ProviderDataPlaneSnapshot(
            sessionID: sessionID,
            packetFlowToCorePackets: 10,
            packetFlowToCoreBytes: 1_000,
            coreToPacketFlowPackets: 9,
            coreToPacketFlowBytes: 2_000,
            coreToPacketFlowDNSSuccessResponses: 2,
            packetFlowToCoreIPv4TCPSYNPackets: 1,
            coreToPacketFlowIPv4TCPSYNACKPackets: 1,
            packetFlowToCoreIPv4TCPDataPackets: 1,
            coreToPacketFlowIPv4TCPDataPackets: 1
        )
        let progress = ProviderDataPlaneSnapshot(
            sessionID: sessionID,
            packetFlowToCorePackets: 20,
            packetFlowToCoreBytes: 1_700,
            coreToPacketFlowPackets: 21,
            coreToPacketFlowBytes: 2_900,
            coreToPacketFlowDNSSuccessResponses: 3,
            packetFlowToCoreIPv4TCPSYNPackets: 2,
            coreToPacketFlowIPv4TCPSYNACKPackets: 2,
            packetFlowToCoreIPv4TCPDataPackets: 2,
            coreToPacketFlowIPv4TCPDataPackets: 2
        )
        XCTAssertTrue(progress.provesBidirectionalIPv4TunnelProgress(since: baseline))

        let staleOtherSession = ProviderDataPlaneSnapshot(
            sessionID: UUID(),
            packetFlowToCorePackets: 20,
            packetFlowToCoreBytes: 1_700,
            coreToPacketFlowPackets: 21,
            coreToPacketFlowBytes: 2_900,
            coreToPacketFlowDNSSuccessResponses: 3,
            packetFlowToCoreIPv4TCPSYNPackets: 2,
            coreToPacketFlowIPv4TCPSYNACKPackets: 2,
            packetFlowToCoreIPv4TCPDataPackets: 2,
            coreToPacketFlowIPv4TCPDataPackets: 2
        )
        XCTAssertFalse(
            staleOtherSession.provesBidirectionalIPv4TunnelProgress(since: baseline)
        )
    }

    func testDataPlaneDiagnosticLocalizesUDP443AndProxyFailures() {
        let noResponse = ProviderDataPlaneSnapshot(
            sessionID: UUID(),
            packetFlowToCorePackets: 2,
            packetFlowToCoreBytes: 1_200,
            coreToPacketFlowPackets: 1,
            coreToPacketFlowBytes: 80,
            packetFlowToCoreUDP443Packets: 1
        )
        XCTAssertEqual(
            noResponse.probeFailureDiagnosticCode(fallback: "probe.transport_failed"),
            "probe.udp_443_response_missing"
        )

        let bidirectional = ProviderDataPlaneSnapshot(
            sessionID: UUID(),
            packetFlowToCorePackets: 2,
            packetFlowToCoreBytes: 1_200,
            coreToPacketFlowPackets: 2,
            coreToPacketFlowBytes: 1_200,
            packetFlowToCoreUDP443Packets: 1,
            coreToPacketFlowUDP443Packets: 1
        )
        XCTAssertEqual(
            bidirectional.probeFailureDiagnosticCode(fallback: "probe.transport_failed"),
            "probe.quic_or_udp_443_timeout"
        )

        let proxyTimeout = ProviderDataPlaneSnapshot(
            sessionID: UUID(),
            packetFlowToCorePackets: 2,
            packetFlowToCoreBytes: 1_200,
            coreToPacketFlowPackets: 1,
            coreToPacketFlowBytes: 80,
            packetFlowToCoreUDP443Packets: 1,
            coreDiagnosticCode: "probe.core_proxy_timeout"
        )
        XCTAssertEqual(
            proxyTimeout.probeFailureDiagnosticCode(fallback: "probe.transport_failed"),
            "probe.core_proxy_timeout"
        )
    }

    func testDataPlaneDiagnosticSplitsZeroMilestoneBypassCases() {
        // Tunneled DNS answered, but no connection packet ever entered the
        // tunnel: the probe's connections bypassed the VPN interface.
        let dnsOnly = ProviderDataPlaneSnapshot(
            sessionID: UUID(),
            packetFlowToCorePackets: 12,
            packetFlowToCoreBytes: 900,
            coreToPacketFlowPackets: 9,
            coreToPacketFlowBytes: 700,
            packetFlowToCoreDNSQueries: 2,
            coreToPacketFlowDNSResponses: 2
        )
        XCTAssertEqual(
            dnsOnly.probeFailureDiagnosticCode(fallback: "probe.transport_failed"),
            "probe.connection_packets_missing"
        )

        // Bidirectional packets without any DNS/TCP/QUIC milestone at all.
        let chatterOnly = ProviderDataPlaneSnapshot(
            sessionID: UUID(),
            packetFlowToCorePackets: 4,
            packetFlowToCoreBytes: 300,
            coreToPacketFlowPackets: 3,
            coreToPacketFlowBytes: 240
        )
        XCTAssertEqual(
            chatterOnly.probeFailureDiagnosticCode(fallback: "probe.transport_failed"),
            "probe.probe_traffic_absent"
        )

        // Non-transport probe fallbacks are preserved unchanged.
        XCTAssertEqual(
            chatterOnly.probeFailureDiagnosticCode(fallback: "probe.invalid_response"),
            "probe.invalid_response"
        )

        // A classified core proxy failure still overrides the bypass codes.
        let proxyFailure = ProviderDataPlaneSnapshot(
            sessionID: UUID(),
            packetFlowToCorePackets: 4,
            packetFlowToCoreBytes: 300,
            coreToPacketFlowPackets: 3,
            coreToPacketFlowBytes: 240,
            coreDiagnosticCode: "probe.core_proxy_refused"
        )
        XCTAssertEqual(
            proxyFailure.probeFailureDiagnosticCode(fallback: "probe.transport_failed"),
            "probe.core_proxy_refused"
        )
    }

    func testPreferredProbeSnapshotDetectsCounterResetAndPrefersLaterSample() {
        let early = ProviderDataPlaneSnapshot(
            sessionID: UUID(),
            packetFlowToCorePackets: 20,
            packetFlowToCoreBytes: 1_500,
            coreToPacketFlowPackets: 15,
            coreToPacketFlowBytes: 1_200
        )
        let grown = ProviderDataPlaneSnapshot(
            sessionID: early.sessionID,
            packetFlowToCorePackets: 24,
            packetFlowToCoreBytes: 1_900,
            coreToPacketFlowPackets: 18,
            coreToPacketFlowBytes: 1_500,
            coreDiagnosticCode: "probe.core_proxy_timeout"
        )
        let grownMerge = ProviderDataPlaneSnapshot.preferredProbeSnapshot(
            first: early,
            second: grown
        )
        XCTAssertFalse(grownMerge.countersReset)
        XCTAssertEqual(grownMerge.snapshot?.coreDiagnosticCode, "probe.core_proxy_timeout")

        let shrunk = ProviderDataPlaneSnapshot(
            sessionID: UUID(),
            packetFlowToCorePackets: 2,
            packetFlowToCoreBytes: 160,
            coreToPacketFlowPackets: 1,
            coreToPacketFlowBytes: 80
        )
        let resetMerge = ProviderDataPlaneSnapshot.preferredProbeSnapshot(
            first: early,
            second: shrunk
        )
        XCTAssertTrue(resetMerge.countersReset)
        XCTAssertEqual(resetMerge.snapshot?.packetFlowToCorePackets, 20)

        XCTAssertEqual(
            ProviderDataPlaneSnapshot.preferredProbeSnapshot(first: nil, second: grown)
                .snapshot?.packetFlowToCorePackets,
            24
        )
        XCTAssertNil(
            ProviderDataPlaneSnapshot.preferredProbeSnapshot(first: nil, second: nil).snapshot
        )
    }

    func testDNSHealthMonitorRequiresSustainedUpstreamFailure() {
        let sessionID = UUID()
        var monitor = ProviderDNSHealthMonitor(consecutiveFailureLimit: 2)

        XCTAssertNil(monitor.observe(dnsSnapshot(
            sessionID: sessionID,
            queries: 10,
            successes: 10,
            coreErrors: 0
        )))
        XCTAssertNil(monitor.observe(dnsSnapshot(
            sessionID: sessionID,
            queries: 11,
            successes: 10,
            coreErrors: 1,
            code: "probe.core_dns_remote_timeout"
        )))
        XCTAssertEqual(monitor.observe(dnsSnapshot(
            sessionID: sessionID,
            queries: 12,
            successes: 10,
            coreErrors: 2,
            code: "probe.core_dns_remote_timeout"
        )), "probe.core_dns_remote_timeout")
    }

    func testDNSHealthMonitorClearsPendingFailureAfterSuccessfulAnswer() {
        let sessionID = UUID()
        var monitor = ProviderDNSHealthMonitor(consecutiveFailureLimit: 2)

        XCTAssertNil(monitor.observe(dnsSnapshot(
            sessionID: sessionID,
            queries: 1,
            successes: 1,
            coreErrors: 0
        )))
        XCTAssertNil(monitor.observe(dnsSnapshot(
            sessionID: sessionID,
            queries: 2,
            successes: 1,
            coreErrors: 1,
            code: "probe.core_dns_upstream_failed"
        )))
        XCTAssertNil(monitor.observe(dnsSnapshot(
            sessionID: sessionID,
            queries: 3,
            successes: 2,
            coreErrors: 1,
            code: "probe.core_dns_upstream_failed"
        )))
        XCTAssertNil(monitor.observe(dnsSnapshot(
            sessionID: sessionID,
            queries: 4,
            successes: 2,
            coreErrors: 2,
            code: "probe.core_dns_upstream_failed"
        )))
    }

    func testDNSHealthMonitorTreatsNameErrorAsHealthyUpstreamResponse() {
        let sessionID = UUID()
        var monitor = ProviderDNSHealthMonitor(consecutiveFailureLimit: 2)

        XCTAssertNil(monitor.observe(dnsSnapshot(
            sessionID: sessionID,
            queries: 1,
            responses: 1,
            successes: 1,
            coreErrors: 0
        )))
        XCTAssertNil(monitor.observe(dnsSnapshot(
            sessionID: sessionID,
            queries: 2,
            responses: 1,
            successes: 1,
            coreErrors: 1,
            code: "probe.core_dns_upstream_failed"
        )))
        XCTAssertNil(monitor.observe(dnsSnapshot(
            sessionID: sessionID,
            queries: 3,
            responses: 2,
            successes: 1,
            nameErrors: 1,
            coreErrors: 1,
            code: "probe.core_dns_upstream_failed"
        )))
        XCTAssertNil(monitor.observe(dnsSnapshot(
            sessionID: sessionID,
            queries: 4,
            responses: 2,
            successes: 1,
            nameErrors: 1,
            coreErrors: 2,
            code: "probe.core_dns_upstream_failed"
        )))
    }

    func testDNSResolutionFailurePrefersRedactedCoreCodeAndUsesCounterFallback() {
        let sessionID = UUID()
        let baseline = dnsSnapshot(
            sessionID: sessionID,
            queries: 3,
            successes: 2,
            coreErrors: 0
        )
        let missingResponse = dnsSnapshot(
            sessionID: sessionID,
            queries: 4,
            successes: 2,
            coreErrors: 0
        )
        let classified = dnsSnapshot(
            sessionID: sessionID,
            queries: 5,
            successes: 2,
            coreErrors: 1,
            code: "probe.core_dns_remote_timeout"
        )

        XCTAssertEqual(
            missingResponse.dnsResolutionFailureDiagnosticCode(since: baseline),
            "probe.dns_response_missing"
        )
        XCTAssertEqual(
            classified.dnsResolutionFailureDiagnosticCode(since: baseline),
            "probe.core_dns_remote_timeout"
        )
    }

    func testDNSResolutionFailureTreatsAnsweredNoAddressAsHealthyTransport() {
        let sessionID = UUID()
        let baseline = dnsSnapshot(
            sessionID: sessionID,
            queries: 3,
            responses: 3,
            successes: 3,
            coreErrors: 0
        )
        let answeredWithoutAddress = dnsSnapshot(
            sessionID: sessionID,
            queries: 5,
            responses: 5,
            successes: 3,
            emptyResponses: 1,
            nameErrors: 1,
            coreErrors: 0
        )
        let serverFailure = dnsSnapshot(
            sessionID: sessionID,
            queries: 4,
            responses: 4,
            successes: 3,
            serverFailures: 1,
            coreErrors: 0
        )

        XCTAssertNil(
            answeredWithoutAddress.dnsResolutionFailureDiagnosticCode(since: baseline)
        )
        XCTAssertEqual(
            serverFailure.dnsResolutionFailureDiagnosticCode(since: baseline),
            "probe.dns_resolution_failed"
        )
    }

    func testDNSFailureClassificationIgnoresStickyCodeAfterHealthyAnswer() {
        let sessionID = UUID()
        let baseline = dnsSnapshot(
            sessionID: sessionID,
            queries: 3,
            responses: 3,
            successes: 3,
            coreErrors: 0
        )
        let recovered = dnsSnapshot(
            sessionID: sessionID,
            queries: 4,
            responses: 4,
            successes: 4,
            coreErrors: 1,
            code: "probe.core_dns_upstream_transport_failed"
        )
        let currentFailure = dnsSnapshot(
            sessionID: sessionID,
            queries: 5,
            responses: 4,
            successes: 4,
            coreErrors: 2,
            code: "probe.core_dns_upstream_transport_failed"
        )

        XCTAssertNil(recovered.dnsUpstreamFailureDiagnosticCode(since: baseline))
        XCTAssertNil(recovered.dnsResolutionFailureDiagnosticCode(since: baseline))
        XCTAssertNil(currentFailure.dnsUpstreamFailureDiagnosticCode(since: nil))
        XCTAssertEqual(
            currentFailure.dnsUpstreamFailureDiagnosticCode(since: recovered),
            "probe.core_dns_upstream_transport_failed"
        )
    }

    func testProbeCounterSummaryContainsOnlyCountsAndStableCode() {
        let snapshot = ProviderDataPlaneSnapshot(
            sessionID: UUID(),
            packetFlowToCorePackets: 12,
            packetFlowToCoreBytes: 900,
            coreToPacketFlowPackets: 9,
            coreToPacketFlowBytes: 700,
            packetFlowToCoreDNSQueries: 2,
            coreToPacketFlowDNSResponses: 2,
            coreDiagnosticCode: "probe.core_proxy_timeout"
        )
        let summary = snapshot.probeCounterSummary
        XCTAssertTrue(summary.contains("pf2core=12"))
        XCTAssertTrue(summary.contains("core2pf=9"))
        XCTAssertTrue(summary.contains("bytes=900/700"))
        XCTAssertTrue(summary.contains("dns=2/2"))
        XCTAssertTrue(summary.contains("dnsresult=0/0/0/0/0"))
        XCTAssertTrue(summary.contains("syn=0/0"))
        XCTAssertTrue(summary.contains("syn4=0/0"))
        XCTAssertTrue(summary.contains("syn6=0/0"))
        XCTAssertTrue(summary.contains("udp443=0/0"))
        XCTAssertTrue(summary.contains("corelog=probe.core_proxy_timeout"))

        let withoutCode = ProviderDataPlaneSnapshot(
            sessionID: UUID(),
            packetFlowToCorePackets: 1,
            packetFlowToCoreBytes: 80,
            coreToPacketFlowPackets: 1,
            coreToPacketFlowBytes: 60
        )
        XCTAssertTrue(withoutCode.probeCounterSummary.contains("corelog=none"))
    }

    func testDataPlaneDiagnosticSeparatesPacketFlowReadFromBridgeForwarding() {
        let noRead = ProviderDataPlaneSnapshot(
            sessionID: UUID(),
            packetFlowToCorePackets: 0,
            packetFlowToCoreBytes: 0,
            coreToPacketFlowPackets: 0,
            coreToPacketFlowBytes: 0
        )
        XCTAssertEqual(
            noRead.probeFailureDiagnosticCode(fallback: "probe.transport_failed"),
            "probe.packet_flow_read_missing"
        )

        let emptyRead = ProviderDataPlaneSnapshot(
            sessionID: UUID(),
            packetFlowReadCallbacks: 1,
            packetFlowToCorePackets: 0,
            packetFlowToCoreBytes: 0,
            coreToPacketFlowPackets: 0,
            coreToPacketFlowBytes: 0
        )
        XCTAssertEqual(
            emptyRead.probeFailureDiagnosticCode(fallback: "probe.transport_failed"),
            "probe.packet_flow_read_empty"
        )

        let bridgeStalled = ProviderDataPlaneSnapshot(
            sessionID: UUID(),
            packetFlowReadCallbacks: 1,
            packetFlowReadPackets: 1,
            packetFlowToCorePackets: 0,
            packetFlowToCoreBytes: 0,
            coreToPacketFlowPackets: 0,
            coreToPacketFlowBytes: 0
        )
        XCTAssertEqual(
            bridgeStalled.probeFailureDiagnosticCode(fallback: "probe.transport_failed"),
            "probe.packet_flow_bridge_forward_missing"
        )
    }

    func testOversizedAndUnknownMessagesAreRejected() {
        XCTAssertThrowsError(try ProviderMessageCodec.decodeRequest(
            Data(repeating: 0, count: ProviderMessageRequest.maximumEncodedBytes + 1)
        )) {
            XCTAssertEqual($0 as? ProviderMessageCodecError, .messageTooLarge)
        }
        XCTAssertThrowsError(try ProviderMessageCodec.decodeRequest(Data("{}".utf8))) {
            XCTAssertEqual($0 as? ProviderMessageCodecError, .malformedMessage)
        }
    }

    func testProviderErrorIsNotAcceptedAsTraffic() throws {
        let request = ProviderMessageRequest(kind: .traffic)
        let responseData = try ProviderMessageCodec.encode(ProviderMessageResponse(
            requestID: request.requestID,
            errorCode: "provider.rate_limited"
        ))
        XCTAssertThrowsError(try ProviderMessageCodec.decodeResponse(responseData, matching: request)) {
            XCTAssertEqual(
                $0 as? ProviderMessageCodecError,
                .providerRejected("provider.rate_limited")
            )
        }
    }

    func testHTTPResponseHeadParserCompletesWithoutWaitingForConnectionClose() {
        XCTAssertEqual(
            ProviderHTTPResponseHeadParser.parse(Data("HTTP/1.1 204 No Content\r\n".utf8)),
            .incomplete
        )
        XCTAssertEqual(
            ProviderHTTPResponseHeadParser.parse(Data(
                "HTTP/1.1 204 No Content\r\nServer: example\r\n\r\n".utf8
            )),
            .complete(statusCode: 204)
        )
        XCTAssertEqual(
            ProviderHTTPResponseHeadParser.parse(Data(
                "HTTP/1.1 nope\r\nConnection: close\r\n\r\n".utf8
            )),
            .invalid
        )
    }

    private func dnsSnapshot(
        sessionID: UUID,
        queries: UInt64,
        responses: UInt64? = nil,
        successes: UInt64,
        emptyResponses: UInt64 = 0,
        nameErrors: UInt64 = 0,
        serverFailures: UInt64 = 0,
        otherErrors: UInt64 = 0,
        coreErrors: UInt64,
        code: String? = nil
    ) -> ProviderDataPlaneSnapshot {
        let responseCount = responses
            ?? successes + emptyResponses + nameErrors + serverFailures + otherErrors
        return ProviderDataPlaneSnapshot(
            sessionID: sessionID,
            packetFlowToCorePackets: queries,
            packetFlowToCoreBytes: queries * 80,
            coreToPacketFlowPackets: responseCount,
            coreToPacketFlowBytes: responseCount * 80,
            packetFlowToCoreDNSQueries: queries,
            coreToPacketFlowDNSResponses: responseCount,
            coreToPacketFlowDNSSuccessResponses: successes,
            coreToPacketFlowDNSEmptyResponses: emptyResponses,
            coreToPacketFlowDNSNameErrorResponses: nameErrors,
            coreToPacketFlowDNSServerFailureResponses: serverFailures,
            coreToPacketFlowDNSOtherErrorResponses: otherErrors,
            coreErrorLogEventsReceived: coreErrors,
            coreDiagnosticCode: code
        )
    }
}
