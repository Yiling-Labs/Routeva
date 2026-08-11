import Foundation
import SharedKit

public enum CoreRuntimeStatus: Equatable, Sendable {
    case stopped
    case starting
    case running
    case stopping
    case failed(code: String)
}

public struct TrafficSnapshot: Equatable, Sendable {
    public let sessionID: UUID
    public let uploadedBytes: UInt64
    public let downloadedBytes: UInt64

    public init(sessionID: UUID, uploadedBytes: UInt64, downloadedBytes: UInt64) {
        self.sessionID = sessionID
        self.uploadedBytes = uploadedBytes
        self.downloadedBytes = downloadedBytes
    }
}

public struct SensitiveRuntimeConfig: @unchecked Sendable {
    public let bytes: Data

    public init(bytes: Data) {
        self.bytes = bytes
    }
}

public protocol CoreRuntimeAdapter: Actor {
    nonisolated var identifier: CoreIdentifier { get }
    nonisolated var isLinked: Bool { get }

    func validate(_ config: SensitiveRuntimeConfig) async throws
    func start(_ config: SensitiveRuntimeConfig) async throws
    func stop() async
    func status() async -> CoreRuntimeStatus
    func queryTraffic() async throws -> TrafficSnapshot
    func testOutbound() async throws
}

public enum CoreRuntimeError: Error, Equatable, Sendable {
    case binaryNotLinked(CoreIdentifier)
    case alreadyRunning(CoreIdentifier)
    case invalidConfiguration(CoreIdentifier)
    case startFailed(CoreIdentifier, code: String)
    case notRunning(CoreIdentifier)
}
