import Foundation

/// Cover Flow 延迟分档。与角标绿/黄/红同一阈值：&lt;100 绿。
public enum NodeLatencyTier: Sendable {
    public static let goodMillisecondLimit = 100

    public static func isGood(_ milliseconds: Int) -> Bool {
        milliseconds < goodMillisecondLimit
    }
}

/// 静默测 / *Test* 轮末的 Cover Flow 预停下标（不改列表序）。
///
/// 当前节点已是绿色则留下，不自动跳到更低 ms。
/// 非绿且未连接：落到已测样本里 ms 最低的节点；无人测过则保持当前。
public enum CoverFlowLatencyPrestop: Sendable {
    public static func index(
        currentIndex: Int,
        nodeIDs: [UUID],
        measuredMilliseconds: [UUID: Int]
    ) -> Int {
        guard !nodeIDs.isEmpty else { return 0 }
        let current = min(max(currentIndex, 0), nodeIDs.count - 1)
        let currentID = nodeIDs[current]
        if let milliseconds = measuredMilliseconds[currentID],
           NodeLatencyTier.isGood(milliseconds) {
            return current
        }

        var bestIndex: Int?
        var bestMilliseconds: Int?
        for (index, nodeID) in nodeIDs.enumerated() {
            guard let milliseconds = measuredMilliseconds[nodeID] else { continue }
            if let bestMilliseconds, milliseconds >= bestMilliseconds { continue }
            bestMilliseconds = milliseconds
            bestIndex = index
        }
        return bestIndex ?? current
    }
}
