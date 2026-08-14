import Foundation
import Network

public enum DirectRouteAddressValidator {
    public static let maximumAddressCount = 256

    public static func validated(_ addresses: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        result.reserveCapacity(min(addresses.count, maximumAddressCount))

        for address in addresses {
            guard address == address.trimmingCharacters(in: .whitespacesAndNewlines),
                  IPv4Address(address) != nil || IPv6Address(address) != nil,
                  seen.insert(address).inserted else {
                continue
            }
            result.append(address)
            if result.count == maximumAddressCount { break }
        }
        return result
    }

    /// Reports whether any resolved destination address equals an excluded
    /// (direct-routed) address, which would silently bypass the tunnel. Pure
    /// in-memory address comparison; no value is logged or persisted.
    public static func containsExcludedMatch(
        excludedRoutes: [String],
        resolvedAddresses: [String]
    ) -> Bool {
        guard !excludedRoutes.isEmpty, !resolvedAddresses.isEmpty else { return false }
        let excluded = Set(excludedRoutes.map(normalizedAddress))
        return resolvedAddresses.contains { excluded.contains(normalizedAddress($0)) }
    }

    private static func normalizedAddress(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let ipv4 = IPv4Address(trimmed) { return "\(ipv4)" }
        if let ipv6 = IPv6Address(trimmed) { return "\(ipv6)".lowercased() }
        return trimmed.lowercased()
    }
}
