import Foundation

/// 0069：Latency Test 何时可以开跑。静默与用户 *Test* 同测量，不同准入。
public enum LatencyTestAdmission: Equatable, Sendable {
    case run
    /// Connected 时静默全表测必须停。
    case ignoreSilent
    /// Connecting 时不测；进行中的一轮应取消。
    case refuseConnecting

    public static func evaluate(
        userInitiated: Bool,
        isConnecting: Bool,
        isConnected: Bool
    ) -> Self {
        if isConnecting { return .refuseConnecting }
        if isConnected && !userInitiated { return .ignoreSilent }
        return .run
    }
}
