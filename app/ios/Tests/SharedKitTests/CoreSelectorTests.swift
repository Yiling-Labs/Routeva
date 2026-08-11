import XCTest
@testable import SharedKit

final class CoreSelectorTests: XCTestCase {
    private let selector = CoreSelector()

    func testAutomaticSelectsOnlySingBoxCore() throws {
        let decision = try selector.select(
            manifest: makeManifest(protocolKind: .vless, security: .reality),
            health: availableHealth
        )

        XCTAssertEqual(decision.selected, .singBox)
        XCTAssertEqual(decision.orderedCandidates, [.singBox])
        XCTAssertEqual(decision.reason, .onlyCompatibleCore)
    }

    func testPinnedSingBoxDoesNotSilentlyIgnoreUnavailability() throws {
        let manifest = makeManifest(protocolKind: .vmess, policy: .singBox)

        XCTAssertThrowsError(
            try selector.select(
                manifest: manifest,
                health: availableHealth,
                excluding: [.singBox]
            )
        ) { error in
            XCTAssertEqual(error as? CoreSelectionError, .pinnedCoreUnavailable(.singBox))
        }
    }

    func testUnsupportedTransportFailsClosed() throws {
        XCTAssertThrowsError(
            try selector.select(
                manifest: makeManifest(protocolKind: .vless, transport: .splitHTTP),
                health: availableHealth
            )
        ) { error in
            XCTAssertEqual(error as? CoreSelectionError, .noCompatibleCore)
        }
    }

    private var availableHealth: [CoreIdentifier: CoreHealth] {
        [.singBox: CoreHealth(isAvailable: true)]
    }

    private func makeManifest(
        protocolKind: ProxyProtocol,
        transport: TransportKind = .tcp,
        security: SecurityKind = .none,
        requiresUDP: Bool = false,
        policy: CorePolicy = .automatic
    ) -> RuntimeManifest {
        RuntimeManifest(
            corePolicy: policy,
            profile: RuntimeProfile(
                id: UUID(),
                protocolKind: protocolKind,
                transport: transport,
                security: security,
                requiresUDP: requiresUDP,
                credential: SecretReference(keychainIdentifier: "synthetic-test-secret")
            )
        )
    }
}
