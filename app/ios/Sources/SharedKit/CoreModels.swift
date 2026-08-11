import Foundation

public enum CoreIdentifier: String, Codable, CaseIterable, Sendable {
    case singBox = "sing-box"
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
}

public enum TransportKind: String, Codable, CaseIterable, Sendable {
    case tcp
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
        protocols.contains(protocolKind)
            && transports.contains(transport)
            && self.security.contains(security)
            && (!requiresUDP || supportsUDP)
    }
}

public extension CoreIdentifier {
    var declaredCapabilities: CoreCapabilities {
        switch self {
        case .singBox:
            CoreCapabilities(
                protocols: [.shadowsocks, .vmess, .vless, .trojan, .hysteria2],
                transports: [.tcp, .webSocket, .grpc, .httpUpgrade, .quic],
                security: [.none, .tls, .reality],
                supportsUDP: true
            )
        }
    }
}
