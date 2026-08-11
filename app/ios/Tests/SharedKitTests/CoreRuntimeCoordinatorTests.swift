import CoreBridge
import Foundation
import XCTest
@testable import SharedKit

final class CoreRuntimeCoordinatorTests: XCTestCase {
    func testAutomaticStartsAndProbesSingBox() async throws {
        let singBox = FakeCoreAdapter(identifier: .singBox)
        let coordinator = CoreRuntimeCoordinator(registry: CoreRegistry(adapters: [singBox]))

        let result = try await coordinator.start(
            manifest: makeManifest(policy: .automatic),
            configuration: { _ in SensitiveRuntimeConfig(bytes: Data("{}".utf8)) },
            probe: { _ in }
        )

        XCTAssertEqual(result.core, .singBox)
        XCTAssertEqual(result.attemptedCores, [.singBox])
        let startCount = await singBox.startCount
        XCTAssertEqual(startCount, 1)
    }

    func testPinnedSingBoxFailureDoesNotRetryAnotherRuntime() async throws {
        let singBox = FakeCoreAdapter(identifier: .singBox, startError: SyntheticError.startFailed)
        let coordinator = CoreRuntimeCoordinator(registry: CoreRegistry(adapters: [singBox]))

        do {
            _ = try await coordinator.start(
                manifest: makeManifest(policy: .singBox),
                configuration: { _ in SensitiveRuntimeConfig(bytes: Data("{}".utf8)) },
                probe: { _ in }
            )
            XCTFail("Expected pinned core start to fail")
        } catch {
            XCTAssertEqual(error as? SyntheticError, .startFailed)
            let startCount = await singBox.startCount
            let stopCount = await singBox.stopCount
            XCTAssertEqual(startCount, 1)
            XCTAssertEqual(stopCount, 1)
        }
    }

    private func makeManifest(policy: CorePolicy) -> RuntimeManifest {
        RuntimeManifest(
            corePolicy: policy,
            profile: RuntimeProfile(
                id: UUID(),
                protocolKind: .vmess,
                transport: .tcp,
                security: .none,
                requiresUDP: false,
                credential: SecretReference(keychainIdentifier: "synthetic-test-secret")
            )
        )
    }
}

private enum SyntheticError: Error, Equatable {
    case startFailed
}

private actor FakeCoreAdapter: CoreRuntimeAdapter {
    nonisolated let identifier: CoreIdentifier
    nonisolated let isLinked = true
    private let startError: Error?
    private(set) var startCount = 0
    private(set) var stopCount = 0

    init(identifier: CoreIdentifier, startError: Error? = nil) {
        self.identifier = identifier
        self.startError = startError
    }

    func validate(_ config: SensitiveRuntimeConfig) async throws {}

    func start(_ config: SensitiveRuntimeConfig) async throws {
        startCount += 1
        if let startError { throw startError }
    }

    func stop() async {
        stopCount += 1
    }

    func status() async -> CoreRuntimeStatus { .running }

    func queryTraffic() async throws -> TrafficSnapshot {
        TrafficSnapshot(sessionID: UUID(), uploadedBytes: 0, downloadedBytes: 0)
    }

    func testOutbound() async throws {}
}
