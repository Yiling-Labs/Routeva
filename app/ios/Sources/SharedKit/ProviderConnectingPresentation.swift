import Foundation

/// Home 是否要把系统还停在 `.connecting` 的快照画成 Connecting。
///
/// App 已经放弃这一轮（用户取消、失败、超时）之后，Network Extension 仍可能
/// 停在 `.connecting`——尤其是 `startTunnel` 还没回调时 `stopVPNTunnel` 送不进去。
/// 这时再把 Home 锁回 Connecting，用户只能杀进程。
public enum ProviderConnectingPresentation: Equatable, Sendable {
    /// 宿主进程中途死掉留下的 Connecting：短暂展示并进入回收。
    case presentOrphaned
    /// 保持 Idle，只在后台继续 stop 残留 provider。
    case suppressAndReap

    public static func evaluate(appReleasedConnecting: Bool) -> Self {
        appReleasedConnecting ? .suppressAndReap : .presentOrphaned
    }
}
