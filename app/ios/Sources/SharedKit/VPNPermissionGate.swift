import Foundation

/// 首次安装 VPN 配置时，iOS 可能弹出授权，也可能把 App 切到系统 VPN 页。
/// 此时 `isEnabled` 和前台状态必须一起看，不能立刻 `startVPNTunnel`。
public enum VPNPermissionGate: Sendable {
    public enum Decision: Equatable, Sendable {
        /// 配置已启用且 App 在前台，可以 start。
        case startTunnel
        /// 用户还在系统授权/设置页。等回前台再读一次偏好，不要 start。
        case waitForForeground
        /// 前台仍未启用：用户拒绝，或设置页没有真正写入配置。
        case failNotPersisted
    }

    public static func decision(isEnabled: Bool, sceneIsActive: Bool) -> Decision {
        if isEnabled, sceneIsActive { return .startTunnel }
        if sceneIsActive { return .failNotPersisted }
        return .waitForForeground
    }

    /// 从系统 VPN 页回到 App，且本轮还停在 Connecting、配置仍未启用：应立刻回 Idle。
    public static func shouldAbandonConnectingOnForeground(
        isConnecting: Bool,
        hasInFlightConnection: Bool,
        hasEnabledConfiguration: Bool
    ) -> Bool {
        isConnecting && hasInFlightConnection && !hasEnabledConfiguration
    }
}

/// 超时后丢下仍在跑的操作，避免 `saveToPreferences` 这类不可取消系统调用拖死 Connecting。
public enum AbandonableAsync: Sendable {
    public static func firstFinished<Success: Sendable>(
        timeout: Duration,
        operation: @escaping @Sendable () async throws -> Success,
        timeoutError: @escaping @Sendable () -> Error
    ) async throws -> Success {
        try await withCheckedThrowingContinuation { continuation in
            let once = OnceResume<Success>()
            once.arm(continuation)
            Task {
                do {
                    once.resume(returning: try await operation())
                } catch {
                    once.resume(throwing: error)
                }
            }
            Task {
                try? await Task.sleep(for: timeout)
                once.resume(throwing: timeoutError())
            }
        }
    }
}

private final class OnceResume<Success: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Success, Error>?
    private var pendingResult: Result<Success, Error>?
    private var didResume = false

    func arm(_ continuation: CheckedContinuation<Success, Error>) {
        lock.lock()
        if didResume {
            lock.unlock()
            return
        }
        if let pendingResult {
            didResume = true
            lock.unlock()
            continuation.resume(with: pendingResult)
            return
        }
        self.continuation = continuation
        lock.unlock()
    }

    func resume(returning value: Success) {
        resume(with: .success(value))
    }

    func resume(throwing error: Error) {
        resume(with: .failure(error))
    }

    private func resume(with result: Result<Success, Error>) {
        lock.lock()
        guard !didResume else {
            lock.unlock()
            return
        }
        if let continuation {
            didResume = true
            self.continuation = nil
            lock.unlock()
            continuation.resume(with: result)
            return
        }
        pendingResult = result
        lock.unlock()
    }
}
