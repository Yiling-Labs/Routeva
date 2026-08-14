import Foundation
import Network

public enum NodeLatencyProbeResult: Equatable, Sendable {
    case measured(Int)
    case timeout
    /// 绑定了物理网卡，但就绪路径不是该网卡（探测会进隧道）。
    case pathUnavailable
}

/// 到节点入口的 TCP RTT。可选绑到指定物理网卡，避免经当前隧道绕路。
public enum NodeLatencyProbe {
    public static func measure(
        host: String,
        port: Int,
        timeout: TimeInterval,
        requiredInterface: NWInterface? = nil
    ) async -> NodeLatencyProbeResult {
        guard (1...65_535).contains(port),
              let endpointPort = NWEndpoint.Port(rawValue: UInt16(port)) else {
            return .timeout
        }
        return await withCheckedContinuation { continuation in
            let parameters = NWParameters.tcp
            if let requiredInterface {
                parameters.requiredInterface = requiredInterface
            }
            let connection = NWConnection(
                host: NWEndpoint.Host(host),
                port: endpointPort,
                using: parameters
            )
            let completion = NodeLatencyCompletion(
                continuation: continuation,
                connection: connection,
                startedAt: Date()
            )
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if let required = requiredInterface {
                        let path = connection.currentPath
                        let usesRequired = path?.usesInterfaceType(required.type) == true
                        if !usesRequired {
                            completion.finish(.pathUnavailable)
                            return
                        }
                    }
                    completion.finish(
                        .measured(Int(Date().timeIntervalSince(completion.startedAt) * 1_000))
                    )
                case .failed, .cancelled:
                    completion.finish(.timeout)
                default:
                    break
                }
            }
            connection.start(queue: DispatchQueue(label: "com.yilinglabs.routeva.node-latency"))
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) {
                completion.finish(.timeout)
            }
        }
    }
}

private final class NodeLatencyCompletion: @unchecked Sendable {
    let startedAt: Date
    private let lock = NSLock()
    private var continuation: CheckedContinuation<NodeLatencyProbeResult, Never>?
    private let connection: NWConnection

    init(
        continuation: CheckedContinuation<NodeLatencyProbeResult, Never>,
        connection: NWConnection,
        startedAt: Date
    ) {
        self.continuation = continuation
        self.connection = connection
        self.startedAt = startedAt
    }

    func finish(_ result: NodeLatencyProbeResult) {
        lock.lock()
        guard let continuation else {
            lock.unlock()
            return
        }
        self.continuation = nil
        lock.unlock()
        connection.cancel()
        continuation.resume(returning: result)
    }
}
