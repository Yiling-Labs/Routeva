/// 0070：切换 Active 时对当前会话做什么。节点热切仍只发生在同一 Active 内。
public enum ActiveSubscriptionSwitch: Equatable, Sendable {
    /// 直接改 Active。
    case apply
    /// 目标已是 Active。
    case ignore
    /// 先停 Connected 会话再改 Active。
    case stopConnected
    /// 取消尚未完成的 Connecting，再改 Active。
    case abortConnecting

    public static func evaluate(
        isAlreadyActive: Bool,
        isConnecting: Bool,
        isConnected: Bool
    ) -> Self {
        if isAlreadyActive { return .ignore }
        if isConnected { return .stopConnected }
        if isConnecting { return .abortConnecting }
        return .apply
    }
}
