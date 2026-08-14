import Foundation
import SharedKit
import XCTest

final class RuntimeManifestTests: XCTestCase {
    func testVersionOneManifestDecodesWithSafeRoutingAndDNSDefaults() throws {
        let current = RuntimeManifest(
            corePolicy: .automatic,
            profile: RuntimeProfile(
                id: UUID(), protocolKind: .vless, transport: .tcp,
                security: .tls, requiresUDP: true,
                credential: SecretReference(keychainIdentifier: "synthetic")
            )
        )
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(current)) as? [String: Any]
        )
        object["schemaVersion"] = 1
        object.removeValue(forKey: "routingMode")
        object.removeValue(forKey: "dnsPreset")
        object.removeValue(forKey: "directRouteAddresses")
        object.removeValue(forKey: "dnsBootstrapAddressMap")
        object.removeValue(forKey: "providerRoutePolicy")
        object.removeValue(forKey: "domainOverrides")
        object.removeValue(forKey: "profiles")

        let decoded = try JSONDecoder().decode(
            RuntimeManifest.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        XCTAssertEqual(decoded.schemaVersion, 1)
        XCTAssertEqual(decoded.routingMode, .automatic)
        XCTAssertEqual(decoded.dnsPreset, .automatic)
        XCTAssertTrue(decoded.directRouteAddresses.isEmpty)
        XCTAssertTrue(decoded.dnsBootstrapAddressMap.isEmpty)
        XCTAssertNil(decoded.providerRoutePolicy)
        XCTAssertTrue(decoded.domainOverrides.isEmpty)
        XCTAssertEqual(decoded.profiles, [decoded.profile])
    }

    func testSchemaSixCatalogBootstrapAddressesAndStableOutboundTagsRoundTrip() throws {
        let first = RuntimeProfile(
            id: UUID(), protocolKind: .shadowsocks, transport: .tcp,
            security: .none, requiresUDP: true,
            credential: SecretReference(keychainIdentifier: "first")
        )
        let second = RuntimeProfile(
            id: UUID(), protocolKind: .trojan, transport: .grpc,
            security: .tls, requiresUDP: true,
            credential: SecretReference(keychainIdentifier: "second")
        )
        let manifest = RuntimeManifest(
            corePolicy: .singBox,
            profile: second,
            profiles: [first, second],
            dnsBootstrapAddressMap: [
                "resolver.example": ["203.0.113.53", "2001:db8::53"],
            ]
        )

        let decoded = try JSONDecoder().decode(
            RuntimeManifest.self,
            from: JSONEncoder().encode(manifest)
        )
        XCTAssertEqual(decoded.schemaVersion, 6)
        XCTAssertEqual(decoded.profiles, [first, second])
        XCTAssertEqual(decoded.dnsBootstrapAddressMap, manifest.dnsBootstrapAddressMap)
        for profile in decoded.profiles {
            let tag = SingBoxNodeSelector.outboundTag(for: profile.id)
            XCTAssertEqual(SingBoxNodeSelector.nodeID(fromOutboundTag: tag), profile.id)
        }
        XCTAssertNil(SingBoxNodeSelector.nodeID(fromOutboundTag: "proxy"))
    }

    func testLargeCatalogWindowKeepsSelectedAndRollbackNodesFirst() {
        let nodes = (0..<500).map { _ in UUID() }
        let selected = nodes[420]
        let rollback = nodes[377]
        let result = SingBoxRuntimeCatalogPlanner.nodeIDs(
            selectedNodeID: selected,
            preferredAdditionalNodeIDs: [rollback, selected, rollback],
            availableNodeIDs: nodes
        )

        XCTAssertEqual(result.count, RuntimeManifest.maximumSingBoxCatalogProfiles)
        XCTAssertEqual(Array(result.prefix(2)), [selected, rollback])
        XCTAssertEqual(Set(result).count, result.count)
    }

    func testDirectRouteAddressesRejectMalformedDuplicatesAndOversizedInput() {
        let input = [
            "203.0.113.10",
            "2001:db8::10",
            "203.0.113.10",
            "203.0.113.10/24",
            " 203.0.113.11",
            "not-an-address",
        ] + Array(repeating: "198.51.100.20", count: 300)

        XCTAssertEqual(
            DirectRouteAddressValidator.validated(input),
            ["203.0.113.10", "2001:db8::10", "198.51.100.20"]
        )
    }

    func testDirectRouteAddressCountIsBoundedBeforeNetworkSettings() {
        let input = (0..<300).map { "2001:db8::\(String($0, radix: 16))" }
        XCTAssertEqual(
            DirectRouteAddressValidator.validated(input).count,
            DirectRouteAddressValidator.maximumAddressCount
        )
    }

    func testInvalidDirectRouteValuesDoNotConsumeTheValidAddressLimit() {
        let input = Array(repeating: "resolver.example.invalid", count: 300)
            + ["203.0.113.53"]

        XCTAssertEqual(
            DirectRouteAddressValidator.validated(input),
            ["203.0.113.53"]
        )
    }

    func testExcludedRouteMatchDetectsCollisionsAcrossAddressSpellings() {
        XCTAssertTrue(
            DirectRouteAddressValidator.containsExcludedMatch(
                excludedRoutes: ["203.0.113.10"],
                resolvedAddresses: ["198.51.100.7", "203.0.113.10"]
            )
        )
        // IPv6 case/expansion differences must still compare equal.
        XCTAssertTrue(
            DirectRouteAddressValidator.containsExcludedMatch(
                excludedRoutes: ["2001:DB8::10"],
                resolvedAddresses: ["2001:0db8:0:0:0:0:0:10"]
            )
        )
        XCTAssertFalse(
            DirectRouteAddressValidator.containsExcludedMatch(
                excludedRoutes: ["203.0.113.10"],
                resolvedAddresses: ["203.0.113.11", "2001:db8::99"]
            )
        )
        XCTAssertFalse(
            DirectRouteAddressValidator.containsExcludedMatch(
                excludedRoutes: [],
                resolvedAddresses: ["203.0.113.10"]
            )
        )
        XCTAssertFalse(
            DirectRouteAddressValidator.containsExcludedMatch(
                excludedRoutes: ["203.0.113.10"],
                resolvedAddresses: []
            )
        )
    }
}
