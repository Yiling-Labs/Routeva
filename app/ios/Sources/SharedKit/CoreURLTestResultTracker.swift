import Foundation

/// Thread-safe handoff from Libbox's asynchronous Group stream to the
/// provider-message request waiting for a native core URL-test result.
public final class CoreURLTestResultTracker: @unchecked Sendable {
    private let condition = NSCondition()
    private var testTime: Int64 = 0
    private var latencyMilliseconds: Int32 = 0

    public init() {}

    public func reset() {
        condition.lock()
        testTime = 0
        latencyMilliseconds = 0
        condition.broadcast()
        condition.unlock()
    }

    /// Records only the redacted result fields already produced by Libbox.
    /// A zero test time means the outbound has no successful URL-test history.
    public func record(testTime: Int64, latencyMilliseconds: Int32) {
        condition.lock()
        self.testTime = testTime
        self.latencyMilliseconds = latencyMilliseconds
        condition.broadcast()
        condition.unlock()
    }

    public func currentLatencyMilliseconds() -> UInt32? {
        condition.lock()
        defer { condition.unlock() }
        return successfulLatency()
    }

    public func waitForSuccess(timeout: TimeInterval) -> UInt32? {
        let deadline = Date().addingTimeInterval(timeout)
        condition.lock()
        defer { condition.unlock() }
        while successfulLatency() == nil {
            guard condition.wait(until: deadline) else { return nil }
        }
        return successfulLatency()
    }

    private func successfulLatency() -> UInt32? {
        guard testTime > 0, latencyMilliseconds >= 0 else { return nil }
        return UInt32(latencyMilliseconds)
    }
}

/// Thread-safe handoff from Libbox's asynchronous Group stream to node
/// selection commands. The Group stream is the authoritative view of the
/// selector inside sing-box; command acceptance alone is not treated as proof.
public final class SingBoxSelectorSelectionTracker: @unchecked Sendable {
    private let condition = NSCondition()
    private var selectedNodeID: UUID?

    public init() {}

    public func reset() {
        condition.lock()
        selectedNodeID = nil
        condition.broadcast()
        condition.unlock()
    }

    public func record(selectedOutboundTag: String) {
        condition.lock()
        selectedNodeID = SingBoxNodeSelector.nodeID(
            fromOutboundTag: selectedOutboundTag
        )
        condition.broadcast()
        condition.unlock()
    }

    public func currentNodeID() -> UUID? {
        condition.lock()
        defer { condition.unlock() }
        return selectedNodeID
    }

    public func waitForSelection(
        _ expectedNodeID: UUID,
        timeout: TimeInterval
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        condition.lock()
        defer { condition.unlock() }
        while selectedNodeID != expectedNodeID {
            guard condition.wait(until: deadline) else { return false }
        }
        return true
    }
}
