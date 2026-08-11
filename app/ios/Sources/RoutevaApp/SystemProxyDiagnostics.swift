import CFNetwork
import Foundation

enum SystemProxyDiagnostics {
    /// Privacy-safe environment evidence. Hosts, ports, and PAC URLs are never
    /// retained or printed; only whether a manual proxy or PAC/WPAD is active.
    static var summary: String {
        guard let copied = CFNetworkCopySystemProxySettings() else {
            return "sysproxy=unknown pac=unknown"
        }
        let settings = copied.takeRetainedValue() as NSDictionary
        func enabled(_ key: String) -> Bool {
            if let number = settings[key] as? NSNumber { return number.boolValue }
            if let value = settings[key] as? Bool { return value }
            return false
        }

        // HTTPS/SOCKS constants are unavailable in the iOS SDK even though
        // CFNetwork may return these dictionary fields. Reading stable keys
        // avoids referencing unavailable API while keeping the data redacted.
        let manual = enabled("HTTPEnable")
            || enabled("HTTPSEnable")
            || enabled("SOCKSEnable")
        let automatic = enabled("ProxyAutoConfigEnable")
            || enabled("ProxyAutoDiscoveryEnable")
        return "sysproxy=\(manual ? 1 : 0) pac=\(automatic ? 1 : 0)"
    }
}
