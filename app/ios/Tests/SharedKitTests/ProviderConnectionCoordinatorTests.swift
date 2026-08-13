import CoreBridge
import Foundation
import SharedKit
import XCTest

final class ProviderConnectionCoordinatorTests: XCTestCase {
    func testAutomaticStartsOnlySingBoxProvider() async throws {
        let recorder = ProviderRecorder()
        let coordinator = ProviderConnectionCoordinator()

        let result = try await coordinator.start(
            manifest: makeManifest(policy: .automatic),
            health: availableHealth,
            startProvider: { core, _ in await recorder.started(core) },
            stopProvider: { core in await recorder.stopped(core) },
            probe: { _ in }
        )

        XCTAssertEqual(result.attemptedCores, [.singBox])
        XCTAssertEqual(result.core, .singBox)
        let events = await recorder.events
        XCTAssertEqual(events, ["start:sing-box"])
    }

    func testPinnedProviderFailureStopsWithoutRuntimeFallback() async throws {
        let recorder = ProviderRecorder()
        let coordinator = ProviderConnectionCoordinator()

        do {
            _ = try await coordinator.start(
                manifest: makeManifest(policy: .singBox),
                health: availableHealth,
                startProvider: { core, _ in await recorder.started(core) },
                stopProvider: { core in await recorder.stopped(core) },
                probe: { _ in throw SyntheticProviderError.probeFailed }
            )
            XCTFail("Expected failure")
        } catch {
            XCTAssertEqual(error as? SyntheticProviderError, .probeFailed)
        }
        let events = await recorder.events
        XCTAssertEqual(events, ["start:sing-box", "stop:sing-box"])
    }

    func testThreeAttemptBudgetAppliesAcrossConnectionRequestsWithinWindow() async throws {
        let recorder = ProviderRecorder()
        let coordinator = ProviderConnectionCoordinator(maximumAttempts: 3)
        let manifest = makeManifest(policy: .automatic)

        for _ in 0..<3 {
            do {
                _ = try await coordinator.start(
                    manifest: manifest,
                    health: availableHealth,
                    startProvider: { core, _ in await recorder.started(core) },
                    stopProvider: { core in await recorder.stopped(core) },
                    probe: { _ in throw SyntheticProviderError.probeFailed }
                )
                XCTFail("Expected provider failure")
            } catch {
                XCTAssertEqual(
                    error as? ProviderConnectionError,
                    .allCandidatesFailed([.singBox])
                )
            }
        }

        do {
            _ = try await coordinator.start(
                manifest: manifest,
                health: availableHealth,
                startProvider: { core, _ in await recorder.started(core) },
                stopProvider: { core in await recorder.stopped(core) },
                probe: { _ in }
            )
            XCTFail("Expected budget failure")
        } catch {
            XCTAssertEqual(error as? ProviderConnectionError, .failureBudgetExhausted)
        }
        let startCount = await recorder.events.filter { $0.hasPrefix("start:") }.count
        XCTAssertEqual(startCount, 3)
    }

    func testSuccessfulReconnectsDoNotConsumeFailureBudget() async throws {
        let recorder = ProviderRecorder()
        let coordinator = ProviderConnectionCoordinator(maximumAttempts: 3)
        let manifest = makeManifest(policy: .singBox)

        for _ in 0..<4 {
            _ = try await coordinator.start(
                manifest: manifest,
                health: availableHealth,
                startProvider: { core, _ in await recorder.started(core) },
                stopProvider: { core in await recorder.stopped(core) },
                probe: { _ in }
            )
            await coordinator.stop(stopProvider: { core in await recorder.stopped(core) })
        }

        let startCount = await recorder.events.filter { $0.hasPrefix("start:") }.count
        XCTAssertEqual(startCount, 4)
    }

    func testRecoveredSystemConnectionCanBeStopped() async {
        let recorder = ProviderRecorder()
        let coordinator = ProviderConnectionCoordinator()

        await coordinator.reconcile(.connected(core: .singBox, since: nil))
        await coordinator.stop(stopProvider: { core in await recorder.stopped(core) })

        let events = await recorder.events
        XCTAssertEqual(events, ["stop:sing-box"])
        let state = await coordinator.state
        XCTAssertEqual(state, .idle)
    }

    func testExternalDisconnectionAllowsAFormerlyConnectedCoordinatorToStartAgain() async throws {
        let recorder = ProviderRecorder()
        let coordinator = ProviderConnectionCoordinator()
        let manifest = makeManifest(policy: .singBox)

        _ = try await coordinator.start(
            manifest: manifest,
            health: availableHealth,
            startProvider: { core, _ in await recorder.started(core) },
            stopProvider: { core in await recorder.stopped(core) },
            probe: { _ in }
        )
        await coordinator.reconcile(.disconnected)
        _ = try await coordinator.start(
            manifest: manifest,
            health: availableHealth,
            startProvider: { core, _ in await recorder.started(core) },
            stopProvider: { core in await recorder.stopped(core) },
            probe: { _ in }
        )

        let events = await recorder.events
        XCTAssertEqual(events, ["start:sing-box", "start:sing-box"])
    }

    private var availableHealth: [CoreIdentifier: CoreHealth] {
        [.singBox: CoreHealth(isAvailable: true)]
    }

    private func makeManifest(policy: CorePolicy) -> RuntimeManifest {
        RuntimeManifest(
            corePolicy: policy,
            profile: RuntimeProfile(
                id: UUID(),
                protocolKind: .vless,
                transport: .tcp,
                security: .tls,
                requiresUDP: true,
                credential: SecretReference(keychainIdentifier: "synthetic")
            )
        )
    }
}

private enum SyntheticProviderError: Error, Equatable {
    case probeFailed
}

private actor ProviderRecorder {
    private(set) var events: [String] = []

    func started(_ core: CoreIdentifier) { events.append("start:\(core.rawValue)") }
    func stopped(_ core: CoreIdentifier) { events.append("stop:\(core.rawValue)") }
}
