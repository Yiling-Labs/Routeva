import Foundation
import Network

/// 入口路径探测用的物理网卡：Wi‑Fi / 蜂窝 / 有线。不含 utun。
public enum PhysicalNetworkInterface {
    public static func isPhysical(_ type: NWInterface.InterfaceType) -> Bool {
        switch type {
        case .wifi, .cellular, .wiredEthernet: true
        default: false
        }
    }

    public static func preferred(
        from path: NWPath?,
        excludingName: String? = nil
    ) -> NWInterface? {
        guard let path else { return nil }
        let physical = path.availableInterfaces.filter {
            isPhysical($0.type) && $0.name != excludingName
        }
        return physical.first(where: { $0.type == .wifi })
            ?? physical.first(where: { $0.type == .wiredEthernet })
            ?? physical.first
    }

    /// 纯函数：从 (name, type) 里挑物理网卡类型，便于单测。
    public static func preferredType<S: Sequence>(
        from interfaces: S,
        excludingName: String? = nil
    ) -> NWInterface.InterfaceType? where S.Element == (name: String, type: NWInterface.InterfaceType) {
        let physical = interfaces.filter { isPhysical($0.type) && $0.name != excludingName }
        return physical.first(where: { $0.type == .wifi })?.type
            ?? physical.first(where: { $0.type == .wiredEthernet })?.type
            ?? physical.first?.type
    }
}
