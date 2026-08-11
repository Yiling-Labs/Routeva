import Foundation

public enum ProtocolSupportLevel: String, Codable, Sendable {
    case verified = "A"
    case experimental = "B"
    case unsupported = "C"

    public var displayLabel: String {
        switch self {
        case .verified: "Supported"
        case .experimental: "Experimental"
        case .unsupported: "Unsupported"
        }
    }
}

public struct ProtocolVerificationKey: Codable, Hashable, Sendable {
    public let protocolKind: ProxyProtocol
    public let transport: TransportKind
    public let security: SecurityKind
    public let requiresUDP: Bool

    public init(
        protocolKind: ProxyProtocol,
        transport: TransportKind,
        security: SecurityKind,
        requiresUDP: Bool
    ) {
        self.protocolKind = protocolKind
        self.transport = transport
        self.security = security
        self.requiresUDP = requiresUDP
    }

    public init(profile: RuntimeProfile) {
        self.init(
            protocolKind: profile.protocolKind,
            transport: profile.transport,
            security: profile.security,
            requiresUDP: profile.requiresUDP
        )
    }
}

public struct ProtocolSupportStatus: Equatable, Sendable {
    public let level: ProtocolSupportLevel
    public let compatibleCores: [CoreIdentifier]
    public let reasonCode: String

    public init(
        level: ProtocolSupportLevel,
        compatibleCores: [CoreIdentifier],
        reasonCode: String
    ) {
        self.level = level
        self.compatibleCores = compatibleCores
        self.reasonCode = reasonCode
    }
}

public struct ProtocolSupportClassifier: Sendable {
    private let verifiedProfiles: Set<ProtocolVerificationKey>

    public init(verifiedProfiles: Set<ProtocolVerificationKey> = []) {
        self.verifiedProfiles = verifiedProfiles
    }

    public func classify(
        protocolKind: ProxyProtocol,
        transport: TransportKind,
        security: SecurityKind,
        requiresUDP: Bool
    ) -> ProtocolSupportStatus {
        let key = ProtocolVerificationKey(
            protocolKind: protocolKind,
            transport: transport,
            security: security,
            requiresUDP: requiresUDP
        )
        let compatible = CoreIdentifier.allCases.filter {
            $0.declaredCapabilities.supports(
                protocolKind: protocolKind,
                transport: transport,
                security: security,
                requiresUDP: requiresUDP
            )
        }

        guard !compatible.isEmpty else {
            return ProtocolSupportStatus(
                level: .unsupported,
                compatibleCores: [],
                reasonCode: "unsupported.core-capability"
            )
        }
        if verifiedProfiles.contains(key) {
            return ProtocolSupportStatus(
                level: .verified,
                compatibleCores: compatible,
                reasonCode: "verified.real-device-matrix"
            )
        }
        return ProtocolSupportStatus(
            level: .experimental,
            compatibleCores: compatible,
            reasonCode: "experimental.awaiting-real-device-matrix"
        )
    }
}
