import Foundation
import SharedKit

public actor UnavailableCoreAdapter: CoreRuntimeAdapter {
    public nonisolated let identifier: CoreIdentifier
    public nonisolated let isLinked = false

    public init(identifier: CoreIdentifier) {
        self.identifier = identifier
    }

    public func validate(_ config: SensitiveRuntimeConfig) async throws {
        throw CoreRuntimeError.binaryNotLinked(identifier)
    }

    public func start(_ config: SensitiveRuntimeConfig) async throws {
        throw CoreRuntimeError.binaryNotLinked(identifier)
    }

    public func stop() async {}

    public func status() async -> CoreRuntimeStatus {
        .stopped
    }

    public func queryTraffic() async throws -> TrafficSnapshot {
        throw CoreRuntimeError.binaryNotLinked(identifier)
    }

    public func testOutbound() async throws {
        throw CoreRuntimeError.binaryNotLinked(identifier)
    }
}
