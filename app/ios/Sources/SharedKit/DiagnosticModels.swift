import Foundation

public enum DiagnosticLayer: String, Codable, CaseIterable, Sendable {
    case configuration
    case dns
    case tcpTLS = "tcp_tls"
    case protocolHandshake = "protocol_handshake"
    case tunnel
    case probe
}

public enum DiagnosticCheckStatus: String, Codable, Sendable {
    case passed
    case failed
    case skipped
}

public struct DiagnosticCheck: Codable, Equatable, Sendable {
    public let layer: DiagnosticLayer
    public let status: DiagnosticCheckStatus
    public let errorCode: String?

    public init(layer: DiagnosticLayer, status: DiagnosticCheckStatus, errorCode: String? = nil) {
        self.layer = layer
        self.status = status
        self.errorCode = errorCode
    }
}

public enum FailureBucket: String, Codable, Sendable {
    case clientFixable = "client_fixable"
    case providerSide = "provider_side"
    case environment
    case unknown
}

public enum DiagnosticConfidence: String, Codable, Sendable {
    case low
    case medium
    case high
}

public enum RepairAction: String, Codable, CaseIterable, Sendable {
    case switchHealthyNode = "switch_healthy_node"
    case refreshSubscription = "refresh_subscription"
    case rebuildTunnel = "rebuild_tunnel"
    case switchDNSPreset = "switch_dns_preset"
    case preferCompatibilityParameters = "prefer_compatibility_parameters"
    case restoreSnapshot = "restore_snapshot"
}

public struct DiagnosticEvidence: Codable, Equatable, Sendable {
    public let layer: DiagnosticLayer
    public let checkStatus: DiagnosticCheckStatus
    public let errorCode: String?

    public init(layer: DiagnosticLayer, checkStatus: DiagnosticCheckStatus, errorCode: String?) {
        self.layer = layer
        self.checkStatus = checkStatus
        self.errorCode = errorCode
    }
}

public struct DiagnosticResult: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let bucket: FailureBucket
    public let stableErrorCode: String
    public let evidence: [DiagnosticEvidence]
    public let confidence: DiagnosticConfidence
    public let allowedActions: [RepairAction]

    public init(
        schemaVersion: Int = DiagnosticResult.currentSchemaVersion,
        bucket: FailureBucket,
        stableErrorCode: String,
        evidence: [DiagnosticEvidence],
        confidence: DiagnosticConfidence,
        allowedActions: [RepairAction]
    ) {
        self.schemaVersion = schemaVersion
        self.bucket = bucket
        self.stableErrorCode = stableErrorCode
        self.evidence = evidence
        self.confidence = confidence
        self.allowedActions = allowedActions
    }
}

public struct DiagnosticEngine: Sendable {
    public init() {}

    public func evaluate(_ checks: [DiagnosticCheck]) -> DiagnosticResult {
        let ordered = DiagnosticLayer.allCases.compactMap { layer in
            checks.last(where: { $0.layer == layer })
        }
        let evidence = ordered.map {
            DiagnosticEvidence(layer: $0.layer, checkStatus: $0.status, errorCode: stable($0.errorCode))
        }

        if failed(.configuration, in: ordered) {
            return result(
                .clientFixable, "diagnostic.configuration.invalid", .high,
                [.refreshSubscription, .restoreSnapshot], evidence
            )
        }
        if failed(.dns, in: ordered) {
            return result(
                .clientFixable, "diagnostic.dns.failed", .high,
                [.switchDNSPreset, .rebuildTunnel], evidence
            )
        }
        if failed(.tunnel, in: ordered) {
            return result(
                .clientFixable, "diagnostic.tunnel.failed", .medium,
                [.rebuildTunnel, .restoreSnapshot], evidence
            )
        }
        if failed(.tcpTLS, in: ordered) || failed(.protocolHandshake, in: ordered) {
            return result(
                .providerSide, "diagnostic.provider.handshake_failed", .high,
                [.switchHealthyNode, .refreshSubscription], evidence
            )
        }
        if failed(.probe, in: ordered), passed(.tunnel, in: ordered) {
            return result(
                .clientFixable, "diagnostic.probe.failed", .medium,
                [.switchHealthyNode, .switchDNSPreset, .rebuildTunnel], evidence
            )
        }
        if failed(.probe, in: ordered) {
            return result(
                .environment, "diagnostic.environment.unreachable", .medium,
                [], evidence
            )
        }
        return result(.unknown, "diagnostic.unknown", .low, [], evidence)
    }

    private func failed(_ layer: DiagnosticLayer, in checks: [DiagnosticCheck]) -> Bool {
        checks.contains { $0.layer == layer && $0.status == .failed }
    }

    private func passed(_ layer: DiagnosticLayer, in checks: [DiagnosticCheck]) -> Bool {
        checks.contains { $0.layer == layer && $0.status == .passed }
    }

    private func stable(_ code: String?) -> String? {
        guard let code, !code.isEmpty, code.count <= 96,
              code.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || "._-".contains($0)) })
        else { return nil }
        return code
    }

    private func result(
        _ bucket: FailureBucket,
        _ code: String,
        _ confidence: DiagnosticConfidence,
        _ actions: [RepairAction],
        _ evidence: [DiagnosticEvidence]
    ) -> DiagnosticResult {
        DiagnosticResult(
            bucket: bucket,
            stableErrorCode: code,
            evidence: evidence,
            confidence: confidence,
            allowedActions: actions
        )
    }
}
