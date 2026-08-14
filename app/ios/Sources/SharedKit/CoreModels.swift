import Foundation

public enum CoreIdentifier: String, Codable, CaseIterable, Sendable {
    case singBox = "sing-box"
}

/// System-owned tunnel state observed by the containing App. The Packet
/// Tunnel extension can outlive the App process, so this snapshot—not a host
/// lifecycle callback—is the source of truth after launch and foregrounding.
public enum ProviderConnectionSnapshot: Equatable, Sendable {
    case disconnected
    case connecting(core: CoreIdentifier)
    case connected(core: CoreIdentifier, since: Date?)
    case reasserting(core: CoreIdentifier, since: Date?)
    case disconnecting(core: CoreIdentifier)

    public var core: CoreIdentifier? {
        switch self {
        case .disconnected:
            nil
        case let .connecting(core),
             let .connected(core, _),
             let .reasserting(core, _),
             let .disconnecting(core):
            core
        }
    }

    public var connectedSince: Date? {
        switch self {
        case let .connected(_, since), let .reasserting(_, since):
            since
        default:
            nil
        }
    }

    public var presentsAsConnected: Bool {
        switch self {
        case .connected, .reasserting:
            true
        default:
            false
        }
    }
}

/// Coalesces overlapping system-status refresh requests without discarding the
/// result already in flight. A burst becomes at most the current pass plus one
/// follow-up pass, so lifecycle events cannot starve UI reconciliation.
public struct ProviderStatusRefreshGate: Equatable, Sendable {
    private var isRefreshing = false
    private var needsFollowUp = false

    public init() {}

    /// Returns `true` only to the caller that owns the refresh loop.
    public mutating func requestRefresh() -> Bool {
        guard !isRefreshing else {
            needsFollowUp = true
            return false
        }
        isRefreshing = true
        return true
    }

    /// Returns `true` when the owner should immediately perform one more pass.
    public mutating func finishPass() -> Bool {
        guard needsFollowUp else {
            isRefreshing = false
            return false
        }
        needsFollowUp = false
        return true
    }

    public mutating func cancel() {
        isRefreshing = false
        needsFollowUp = false
    }
}

public enum CorePolicy: String, Codable, Sendable {
    case automatic
    case singBox = "sing-box"

    public var pinnedCore: CoreIdentifier? {
        switch self {
        case .automatic: nil
        case .singBox: .singBox
        }
    }
}

public enum ProxyProtocol: String, Codable, CaseIterable, Sendable {
    case shadowsocks
    case vmess
    case vless
    case trojan
    case hysteria2
    case anyTLS = "anytls"
    case socks5
    case http
    case tuic
}

public enum TransportKind: String, Codable, CaseIterable, Sendable {
    case tcp
    case http
    case webSocket
    case grpc
    case httpUpgrade
    case splitHTTP
    case quic
}

public enum SecurityKind: String, Codable, CaseIterable, Sendable {
    case none
    case tls
    case reality
}

public struct CoreCapabilities: Equatable, Sendable {
    public let protocols: Set<ProxyProtocol>
    public let transports: Set<TransportKind>
    public let security: Set<SecurityKind>
    public let supportsUDP: Bool

    public init(
        protocols: Set<ProxyProtocol>,
        transports: Set<TransportKind>,
        security: Set<SecurityKind>,
        supportsUDP: Bool
    ) {
        self.protocols = protocols
        self.transports = transports
        self.security = security
        self.supportsUDP = supportsUDP
    }

    public func supports(_ profile: RuntimeProfile) -> Bool {
        supports(
            protocolKind: profile.protocolKind,
            transport: profile.transport,
            security: profile.security,
            requiresUDP: profile.requiresUDP
        )
    }

    public func supports(
        protocolKind: ProxyProtocol,
        transport: TransportKind,
        security: SecurityKind,
        requiresUDP: Bool
    ) -> Bool {
        guard protocols.contains(protocolKind)
            && transports.contains(transport)
            && self.security.contains(security)
            && (!requiresUDP || supportsUDP)
        else { return false }

        switch protocolKind {
        case .anyTLS:
            return transport == .tcp && security == .tls
        case .socks5:
            return transport == .tcp && security == .none
        case .http:
            return transport == .tcp && security != .reality && !requiresUDP
        case .tuic, .hysteria2:
            return transport == .quic && security == .tls && requiresUDP
        case .shadowsocks, .vmess, .vless, .trojan:
            return true
        }
    }
}

public extension CoreIdentifier {
    var declaredCapabilities: CoreCapabilities {
        switch self {
        case .singBox:
            CoreCapabilities(
                protocols: [
                    .shadowsocks, .vmess, .vless, .trojan, .hysteria2,
                    .anyTLS, .socks5, .http, .tuic,
                ],
                transports: [.tcp, .http, .webSocket, .grpc, .httpUpgrade, .quic],
                security: [.none, .tls, .reality],
                supportsUDP: true
            )
        }
    }
}
