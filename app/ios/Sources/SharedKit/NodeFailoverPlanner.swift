import Foundation

public struct NodeFailoverCandidate: Equatable, Sendable {
    public let index: Int
    public let healthScore: Int?

    public init(index: Int, healthScore: Int? = nil) {
        self.index = index
        self.healthScore = healthScore
    }
}

public struct NodeFailoverPlanner: Sendable {
    public init() {}

    public func candidates(
        routingMode: RuntimeManifest.RoutingMode,
        isPreferredPinned: Bool,
        currentIndex: Int,
        available: [NodeFailoverCandidate],
        maximumAttempts: Int = 3
    ) -> [Int] {
        guard maximumAttempts > 0,
              available.contains(where: { $0.index == currentIndex }) else { return [] }
        guard routingMode == .automatic, !isPreferredPinned else { return [currentIndex] }

        let remainder = available
            .filter { $0.index != currentIndex }
            .sorted { lhs, rhs in
                switch (lhs.healthScore, rhs.healthScore) {
                case let (.some(left), .some(right)):
                    return left == right ? lhs.index < rhs.index : left < right
                case (.some, .none):
                    return true
                case (.none, .some):
                    return false
                case (.none, .none):
                    return lhs.index < rhs.index
                }
            }
        return Array(([currentIndex] + remainder.map(\.index)).prefix(maximumAttempts))
    }
}
