import Foundation

public enum ProviderMessageKind: String, Codable, Sendable {
    case status
    case traffic
    case dataPlane = "data_plane"
    case coreProbe = "core_probe"
    case selectNode = "select_node"
    case selectedNode = "selected_node"
    case reloadConfiguration = "reload_configuration"
    case finalizeConfigurationReload = "finalize_configuration_reload"
    /// Connected 时对节点入口做物理路径 TCP RTT（ADR 0069）。只传 node UUID。
    case entryLatency = "entry_latency"
}

public enum ProviderEntryLatencyCode {
    public static let physicalPathUnavailable = "latency.physical_path_unavailable"
    public static let maximumBatchCount = 6
}

public struct ProviderEntryLatencySample: Codable, Equatable, Sendable {
    public let nodeID: UUID
    public let milliseconds: UInt32?

    public init(nodeID: UUID, milliseconds: UInt32?) {
        self.nodeID = nodeID
        self.milliseconds = milliseconds
    }
}

public enum ProviderTunnelProbeCatalog {
    public static let ipv4ResolutionHosts = [
        "www.gstatic.com",
        "cp.cloudflare.com",
    ]
}

/// Numeric candidates resolved by the host before the VPN owns the default
/// route. The provider still chooses only its built-in probe endpoints and
/// validates each address before using it with the original SNI and Host.
public struct ProviderTunnelProbeAddressSet: Codable, Equatable, Sendable {
    public let host: String
    public let ipv4Addresses: [String]

    public init(host: String, ipv4Addresses: [String]) {
        self.host = host
        self.ipv4Addresses = ipv4Addresses
    }
}

public struct ProviderMessageRequest: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1
    public static let maximumEncodedBytes = 4_096

    public let schemaVersion: Int
    public let requestID: UUID
    public let kind: ProviderMessageKind
    /// Optional additive schema-1 field used only by `coreProbe`. Older
    /// request producers remain decodable.
    public let tunnelProbeAddressSets: [ProviderTunnelProbeAddressSet]?
    /// UUID-only selector target used by `selectNode`. The provider validates
    /// it against the manifest catalog already loaded from shared storage.
    public let nodeID: UUID?
    /// Shared-database manifest identifier used to rebuild and hot-reload the
    /// bounded sing-box catalog without carrying configuration or credentials
    /// across the provider message boundary.
    public let manifestID: UUID?
    /// Two-phase catalog reload decision. `true` releases the previous runtime
    /// snapshot after verification; `false` restores it in the same NE session.
    public let acceptConfigurationReload: Bool?
    /// UUID-only batch for `entryLatency`. Endpoints stay in the App Group DB.
    public let entryLatencyNodeIDs: [UUID]?

    public init(
        schemaVersion: Int = ProviderMessageRequest.currentSchemaVersion,
        requestID: UUID = UUID(),
        kind: ProviderMessageKind,
        tunnelProbeAddressSets: [ProviderTunnelProbeAddressSet]? = nil,
        nodeID: UUID? = nil,
        manifestID: UUID? = nil,
        acceptConfigurationReload: Bool? = nil,
        entryLatencyNodeIDs: [UUID]? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.requestID = requestID
        self.kind = kind
        self.tunnelProbeAddressSets = tunnelProbeAddressSets
        self.nodeID = nodeID
        self.manifestID = manifestID
        self.acceptConfigurationReload = acceptConfigurationReload
        self.entryLatencyNodeIDs = entryLatencyNodeIDs
    }
}

public enum ProviderRuntimeStatus: String, Codable, Sendable {
    case idle
    case preparing
    case starting
    case running
    case stopping
    case failed
}

/// Pure retry classification shared by the host controller and tests. It is
/// deliberately limited to IPC transport/readiness failures; a Provider
/// rejection from the actual node probe is authoritative and is never retried
/// as an IPC recovery.
public enum ProviderIPCFailureKind: Equatable, Sendable {
    case responseTimedOut
    case responseMissing
    case sessionUnavailable
    case rateLimited
    case other
}

public struct ProviderIPCRecoveryPolicy: Equatable, Sendable {
    public let maximumReadinessAttempts: Int
    public let maximumCoreProbeAttempts: Int

    public init(
        maximumReadinessAttempts: Int = 4,
        maximumCoreProbeAttempts: Int = 2
    ) {
        self.maximumReadinessAttempts = maximumReadinessAttempts
        self.maximumCoreProbeAttempts = maximumCoreProbeAttempts
    }

    public func shouldRetryReadiness(
        after failure: ProviderIPCFailureKind,
        completedAttempts: Int
    ) -> Bool {
        guard completedAttempts < maximumReadinessAttempts else { return false }
        return switch failure {
        case .responseTimedOut, .responseMissing, .sessionUnavailable, .rateLimited:
            true
        case .other:
            false
        }
    }

    public func shouldRetryCoreProbe(
        after failure: ProviderIPCFailureKind,
        completedAttempts: Int
    ) -> Bool {
        guard completedAttempts < maximumCoreProbeAttempts else { return false }
        return switch failure {
        case .responseTimedOut, .responseMissing, .sessionUnavailable, .rateLimited:
            true
        case .other:
            false
        }
    }
}

public struct ProviderTrafficSnapshot: Codable, Equatable, Sendable {
    public let sessionID: UUID
    public let uploadedBytes: UInt64
    public let downloadedBytes: UInt64

    public init(sessionID: UUID, uploadedBytes: UInt64, downloadedBytes: UInt64) {
        self.sessionID = sessionID
        self.uploadedBytes = uploadedBytes
        self.downloadedBytes = downloadedBytes
    }

    /// Returns one stable cumulative source for the whole response. PacketFlow
    /// is authoritative once the bridge has observed traffic; core totals are
    /// retained only for runtimes that do not report PacketFlow counters.
    public static func userVisible(
        sessionID: UUID,
        coreUploadedBytes: UInt64,
        coreDownloadedBytes: UInt64,
        packetFlowUploadedBytes: UInt64,
        packetFlowDownloadedBytes: UInt64
    ) -> Self {
        let packetFlowIsAvailable = packetFlowUploadedBytes > 0
            || packetFlowDownloadedBytes > 0
        return Self(
            sessionID: sessionID,
            uploadedBytes: packetFlowIsAvailable
                ? packetFlowUploadedBytes : coreUploadedBytes,
            downloadedBytes: packetFlowIsAvailable
                ? packetFlowDownloadedBytes : coreDownloadedBytes
        )
    }
}

public struct ProviderTrafficRate: Equatable, Sendable {
    public let uploadMbps: Double
    public let downloadMbps: Double

    public init(uploadMbps: Double, downloadMbps: Double) {
        self.uploadMbps = uploadMbps
        self.downloadMbps = downloadMbps
    }
}

/// Keeps the short-lived traffic baseline outside the foreground polling
/// task. A recreated task can therefore publish its first fresh rate without
/// an entire extra polling interval, while stale background averages are
/// rejected for accuracy.
public struct ProviderTrafficRateSampler: Sendable {
    private let maximumBaselineAge: TimeInterval
    private var samples: [(snapshot: ProviderTrafficSnapshot, date: Date)] = []

    public init(maximumBaselineAge: TimeInterval = 2) {
        self.maximumBaselineAge = maximumBaselineAge
    }

    public mutating func sample(
        _ snapshot: ProviderTrafficSnapshot,
        at date: Date
    ) -> ProviderTrafficRate? {
        if let previous = samples.last,
           (previous.snapshot.sessionID != snapshot.sessionID
            || snapshot.uploadedBytes < previous.snapshot.uploadedBytes
            || snapshot.downloadedBytes < previous.snapshot.downloadedBytes
            || date.timeIntervalSince(previous.date) <= 0
            || date.timeIntervalSince(previous.date) > maximumBaselineAge) {
            samples.removeAll(keepingCapacity: true)
        }
        samples.append((snapshot, date))
        let cutoff = date.addingTimeInterval(-maximumBaselineAge)
        samples.removeAll(where: { $0.date < cutoff })
        guard let first = samples.first, samples.count >= 2 else { return nil }
        let seconds = date.timeIntervalSince(first.date)
        guard seconds > 0 else { return nil }
        return ProviderTrafficRate(
            uploadMbps: Double(snapshot.uploadedBytes - first.snapshot.uploadedBytes)
                * 8 / seconds / 1_000_000,
            downloadMbps: Double(snapshot.downloadedBytes - first.snapshot.downloadedBytes)
                * 8 / seconds / 1_000_000
        )
    }

    public mutating func reset() {
        samples.removeAll(keepingCapacity: true)
    }
}

/// Successful egress verification performed inside the running core. The
/// response intentionally carries only latency: no URL, address, node tag, or
/// raw core error crosses the extension boundary.
public struct ProviderCoreProbeSnapshot: Codable, Equatable, Sendable {
    public let latencyMilliseconds: UInt32

    public init(latencyMilliseconds: UInt32) {
        self.latencyMilliseconds = latencyMilliseconds
    }
}

/// Incremental parser for the HTTP response head used by the provider's
/// tunnel-bound connectivity Gate. A 204 response has no message body, so the
/// Gate can succeed as soon as the complete head arrives instead of depending
/// on a later TCP FIN (or incorrectly failing when the peer resets afterward).
public enum ProviderHTTPResponseHeadParseResult: Equatable, Sendable {
    case incomplete
    case complete(statusCode: Int)
    case invalid
}

public enum ProviderHTTPResponseHeadParser {
    public static func parse(_ data: Data) -> ProviderHTTPResponseHeadParseResult {
        let headerSeparator = Data([13, 10, 13, 10])
        guard let headerRange = data.range(of: headerSeparator) else {
            return .incomplete
        }
        let header = data[..<headerRange.lowerBound]
        guard let lineEnd = header.range(of: Data([13, 10]))?.lowerBound else {
            return .invalid
        }
        let statusLine = String(decoding: header[..<lineEnd], as: UTF8.self)
        let parts = statusLine.split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count >= 2,
              parts[0].hasPrefix("HTTP/"),
              parts[1].count == 3,
              let statusCode = Int(parts[1]),
              (100...599).contains(statusCode)
        else { return .invalid }
        return .complete(statusCode: statusCode)
    }
}

/// Redacted packet counters used to localize a PacketFlow data-path failure.
/// Counts and byte totals contain no addresses, payloads, node data, or errors.
public struct ProviderDataPlaneSnapshot: Codable, Equatable, Sendable {
    public let sessionID: UUID
    public let packetFlowReadCallbacks: UInt64
    public let packetFlowReadPackets: UInt64
    public let packetFlowToCorePackets: UInt64
    public let packetFlowToCoreBytes: UInt64
    public let coreToPacketFlowPackets: UInt64
    public let coreToPacketFlowBytes: UInt64
    public let packetFlowToCoreDNSQueries: UInt64
    public let coreToPacketFlowDNSResponses: UInt64
    public let coreToPacketFlowDNSSuccessResponses: UInt64
    public let coreToPacketFlowDNSEmptyResponses: UInt64
    public let coreToPacketFlowDNSNameErrorResponses: UInt64
    public let coreToPacketFlowDNSServerFailureResponses: UInt64
    public let coreToPacketFlowDNSOtherErrorResponses: UInt64
    public let packetFlowToCoreUDP443Packets: UInt64
    public let coreToPacketFlowUDP443Packets: UInt64
    public let packetFlowToCoreTCPSYNPackets: UInt64
    public let coreToPacketFlowTCPSYNACKPackets: UInt64
    public let packetFlowToCoreIPv4TCPSYNPackets: UInt64
    public let packetFlowToCoreIPv6TCPSYNPackets: UInt64
    public let coreToPacketFlowIPv4TCPSYNACKPackets: UInt64
    public let coreToPacketFlowIPv6TCPSYNACKPackets: UInt64
    public let coreToPacketFlowTCPRSTPackets: UInt64
    public let coreToPacketFlowICMPErrors: UInt64
    /// TCP packets carrying payload. Distinguishes "handshake completed and
    /// data flowed" from "SYN-ACK seen but the handshake never completed".
    public let packetFlowToCoreTCPDataPackets: UInt64
    public let coreToPacketFlowTCPDataPackets: UInt64
    public let packetFlowToCoreIPv4TCPDataPackets: UInt64
    public let packetFlowToCoreIPv6TCPDataPackets: UInt64
    public let coreToPacketFlowIPv4TCPDataPackets: UInt64
    public let coreToPacketFlowIPv6TCPDataPackets: UInt64
    /// Total `writeLogs` deliveries observed; distinguishes "core logged
    /// nothing matching" from "the log stream never arrived at all".
    public let coreLogEventsReceived: UInt64
    /// Deliveries at error level or above (sing-box panic/fatal/error).
    /// Nonzero with a nil `coreDiagnosticCode` proves a classifier gap.
    public let coreErrorLogEventsReceived: UInt64
    /// A stable allowlisted category derived inside the provider from an
    /// error-level core event. Raw logs, hosts, domains, and payloads never
    /// cross the provider message boundary.
    public let coreDiagnosticCode: String?
    public init(
        sessionID: UUID,
        packetFlowReadCallbacks: UInt64 = 0,
        packetFlowReadPackets: UInt64 = 0,
        packetFlowToCorePackets: UInt64,
        packetFlowToCoreBytes: UInt64,
        coreToPacketFlowPackets: UInt64,
        coreToPacketFlowBytes: UInt64,
        packetFlowToCoreDNSQueries: UInt64 = 0,
        coreToPacketFlowDNSResponses: UInt64 = 0,
        coreToPacketFlowDNSSuccessResponses: UInt64 = 0,
        coreToPacketFlowDNSEmptyResponses: UInt64 = 0,
        coreToPacketFlowDNSNameErrorResponses: UInt64 = 0,
        coreToPacketFlowDNSServerFailureResponses: UInt64 = 0,
        coreToPacketFlowDNSOtherErrorResponses: UInt64 = 0,
        packetFlowToCoreUDP443Packets: UInt64 = 0,
        coreToPacketFlowUDP443Packets: UInt64 = 0,
        packetFlowToCoreTCPSYNPackets: UInt64 = 0,
        coreToPacketFlowTCPSYNACKPackets: UInt64 = 0,
        packetFlowToCoreIPv4TCPSYNPackets: UInt64 = 0,
        packetFlowToCoreIPv6TCPSYNPackets: UInt64 = 0,
        coreToPacketFlowIPv4TCPSYNACKPackets: UInt64 = 0,
        coreToPacketFlowIPv6TCPSYNACKPackets: UInt64 = 0,
        coreToPacketFlowTCPRSTPackets: UInt64 = 0,
        coreToPacketFlowICMPErrors: UInt64 = 0,
        packetFlowToCoreTCPDataPackets: UInt64 = 0,
        coreToPacketFlowTCPDataPackets: UInt64 = 0,
        packetFlowToCoreIPv4TCPDataPackets: UInt64 = 0,
        packetFlowToCoreIPv6TCPDataPackets: UInt64 = 0,
        coreToPacketFlowIPv4TCPDataPackets: UInt64 = 0,
        coreToPacketFlowIPv6TCPDataPackets: UInt64 = 0,
        coreLogEventsReceived: UInt64 = 0,
        coreErrorLogEventsReceived: UInt64 = 0,
        coreDiagnosticCode: String? = nil
    ) {
        self.sessionID = sessionID
        self.packetFlowReadCallbacks = packetFlowReadCallbacks
        self.packetFlowReadPackets = packetFlowReadPackets
        self.packetFlowToCorePackets = packetFlowToCorePackets
        self.packetFlowToCoreBytes = packetFlowToCoreBytes
        self.coreToPacketFlowPackets = coreToPacketFlowPackets
        self.coreToPacketFlowBytes = coreToPacketFlowBytes
        self.packetFlowToCoreDNSQueries = packetFlowToCoreDNSQueries
        self.coreToPacketFlowDNSResponses = coreToPacketFlowDNSResponses
        self.coreToPacketFlowDNSSuccessResponses = coreToPacketFlowDNSSuccessResponses
        self.coreToPacketFlowDNSEmptyResponses = coreToPacketFlowDNSEmptyResponses
        self.coreToPacketFlowDNSNameErrorResponses = coreToPacketFlowDNSNameErrorResponses
        self.coreToPacketFlowDNSServerFailureResponses =
            coreToPacketFlowDNSServerFailureResponses
        self.coreToPacketFlowDNSOtherErrorResponses =
            coreToPacketFlowDNSOtherErrorResponses
        self.packetFlowToCoreUDP443Packets = packetFlowToCoreUDP443Packets
        self.coreToPacketFlowUDP443Packets = coreToPacketFlowUDP443Packets
        self.packetFlowToCoreTCPSYNPackets = packetFlowToCoreTCPSYNPackets
        self.coreToPacketFlowTCPSYNACKPackets = coreToPacketFlowTCPSYNACKPackets
        self.packetFlowToCoreIPv4TCPSYNPackets = packetFlowToCoreIPv4TCPSYNPackets
        self.packetFlowToCoreIPv6TCPSYNPackets = packetFlowToCoreIPv6TCPSYNPackets
        self.coreToPacketFlowIPv4TCPSYNACKPackets =
            coreToPacketFlowIPv4TCPSYNACKPackets
        self.coreToPacketFlowIPv6TCPSYNACKPackets =
            coreToPacketFlowIPv6TCPSYNACKPackets
        self.coreToPacketFlowTCPRSTPackets = coreToPacketFlowTCPRSTPackets
        self.coreToPacketFlowICMPErrors = coreToPacketFlowICMPErrors
        self.packetFlowToCoreTCPDataPackets = packetFlowToCoreTCPDataPackets
        self.coreToPacketFlowTCPDataPackets = coreToPacketFlowTCPDataPackets
        self.packetFlowToCoreIPv4TCPDataPackets =
            packetFlowToCoreIPv4TCPDataPackets
        self.packetFlowToCoreIPv6TCPDataPackets =
            packetFlowToCoreIPv6TCPDataPackets
        self.coreToPacketFlowIPv4TCPDataPackets =
            coreToPacketFlowIPv4TCPDataPackets
        self.coreToPacketFlowIPv6TCPDataPackets =
            coreToPacketFlowIPv6TCPDataPackets
        self.coreLogEventsReceived = coreLogEventsReceived
        self.coreErrorLogEventsReceived = coreErrorLogEventsReceived
        self.coreDiagnosticCode = coreDiagnosticCode
    }

    /// The provider retains only allowlisted categories, never the raw DNS
    /// message or queried hostname. Any code in this family means sing-box
    /// failed while reaching or using an upstream resolver.
    public var dnsUpstreamFailureDiagnosticCode: String? {
        guard let coreDiagnosticCode,
              coreDiagnosticCode.hasPrefix("probe.core_dns_")
        else { return nil }
        return coreDiagnosticCode
    }

    /// Returns a sticky core DNS category only when the current observation
    /// window also contains a new query without any healthy upstream answer.
    /// This prevents an old transient transport error from poisoning later
    /// post-connect probe classification after DNS has recovered.
    public func dnsUpstreamFailureDiagnosticCode(since baseline: Self?) -> String? {
        guard let code = dnsUpstreamFailureDiagnosticCode else { return nil }
        // Without a baseline there is no current observation window. The core
        // category is intentionally sticky, so treating it as current evidence
        // could tear down a recovered session after an earlier transient error.
        guard let baseline else { return nil }
        guard sessionID == baseline.sessionID,
              packetFlowToCoreDNSQueries >= baseline.packetFlowToCoreDNSQueries,
              coreToPacketFlowDNSSuccessResponses
                >= baseline.coreToPacketFlowDNSSuccessResponses,
              coreToPacketFlowDNSEmptyResponses
                >= baseline.coreToPacketFlowDNSEmptyResponses,
              coreToPacketFlowDNSNameErrorResponses
                >= baseline.coreToPacketFlowDNSNameErrorResponses,
              packetFlowToCoreDNSQueries > baseline.packetFlowToCoreDNSQueries
        else { return nil }
        let healthyResponseAdvanced = coreToPacketFlowDNSSuccessResponses
                > baseline.coreToPacketFlowDNSSuccessResponses
            || coreToPacketFlowDNSEmptyResponses
                > baseline.coreToPacketFlowDNSEmptyResponses
            || coreToPacketFlowDNSNameErrorResponses
                > baseline.coreToPacketFlowDNSNameErrorResponses
        return healthyResponseAdvanced ? nil : code
    }

    /// Classifies an App-side DNS preflight that produced no usable address.
    /// Counter deltas keep an old session total from being mistaken for the
    /// current preflight, while the core's redacted code remains authoritative
    /// when one is available.
    public func dnsResolutionFailureDiagnosticCode(since baseline: Self?) -> String? {
        if let code = dnsUpstreamFailureDiagnosticCode(since: baseline) {
            return code
        }
        guard let baseline,
              sessionID == baseline.sessionID,
              packetFlowToCoreDNSQueries > baseline.packetFlowToCoreDNSQueries,
              coreToPacketFlowDNSResponses >= baseline.coreToPacketFlowDNSResponses,
              coreToPacketFlowDNSSuccessResponses
                >= baseline.coreToPacketFlowDNSSuccessResponses,
              coreToPacketFlowDNSEmptyResponses
                >= baseline.coreToPacketFlowDNSEmptyResponses,
              coreToPacketFlowDNSNameErrorResponses
                >= baseline.coreToPacketFlowDNSNameErrorResponses
        else { return nil }
        if coreToPacketFlowDNSResponses == baseline.coreToPacketFlowDNSResponses {
            return "probe.dns_response_missing"
        }
        let healthyResponseAdvanced = coreToPacketFlowDNSSuccessResponses
                > baseline.coreToPacketFlowDNSSuccessResponses
            || coreToPacketFlowDNSEmptyResponses
                > baseline.coreToPacketFlowDNSEmptyResponses
            || coreToPacketFlowDNSNameErrorResponses
                > baseline.coreToPacketFlowDNSNameErrorResponses
        if !healthyResponseAdvanced {
            return "probe.dns_resolution_failed"
        }
        return nil
    }

    public func probeFailureDiagnosticCode(fallback: String) -> String {
        let proxyDiagnosticCode = coreDiagnosticCode.flatMap {
            $0.hasPrefix("probe.core_proxy_") || $0.hasPrefix("probe.core_connection_")
                ? $0 : nil
        }
        let tunnelProbeDiagnosticCode = fallback.hasPrefix("probe.tunnel_http_")
            || fallback.hasPrefix("probe.tunnel_interface_")
            || fallback.hasPrefix("probe.tunnel_probe_")
            ? fallback : nil
        if packetFlowToCorePackets == 0 {
            guard packetFlowReadCallbacks > 0 else { return "probe.packet_flow_read_missing" }
            guard packetFlowReadPackets > 0 else { return "probe.packet_flow_read_empty" }
            return "probe.packet_flow_bridge_forward_missing"
        }
        guard coreToPacketFlowPackets > 0 else { return "probe.core_output_missing" }
        if packetFlowToCoreDNSQueries > 0, coreToPacketFlowDNSResponses == 0 {
            return coreDiagnosticCode ?? "probe.dns_response_missing"
        }
        if packetFlowToCoreTCPSYNPackets > 0, coreToPacketFlowTCPSYNACKPackets == 0 {
            if coreToPacketFlowTCPRSTPackets > 0 { return "probe.tcp_reset" }
            if coreToPacketFlowICMPErrors > 0 { return "probe.network_unreachable" }
            if let proxyDiagnosticCode { return proxyDiagnosticCode }
            return "probe.tcp_handshake_timeout"
        }
        if coreToPacketFlowTCPSYNACKPackets > 0 {
            if let proxyDiagnosticCode { return proxyDiagnosticCode }
            // A SYN-ACK from the local gVisor stack only proves it accepted
            // the connection. TCP payload counters separate a handshake that
            // never completed (bridge/stack issue) from a completed handshake
            // whose TLS bytes vanished inside the proxy chain.
            if packetFlowToCoreTCPDataPackets == 0 {
                return "probe.tcp_handshake_incomplete"
            }
            if coreToPacketFlowTCPDataPackets == 0 {
                return "probe.proxy_response_missing"
            }
            if let tunnelProbeDiagnosticCode { return tunnelProbeDiagnosticCode }
            return "probe.tls_or_http_timeout"
        }
        if packetFlowToCoreUDP443Packets > 0 {
            if let proxyDiagnosticCode { return proxyDiagnosticCode }
            guard coreToPacketFlowUDP443Packets > 0 else {
                return "probe.udp_443_response_missing"
            }
            return "probe.quic_or_udp_443_timeout"
        }
        if let proxyDiagnosticCode { return proxyDiagnosticCode }
        guard fallback == "probe.transport_failed" else { return fallback }
        // Packets crossed the bridge in both directions, yet no DNS, TCP
        // handshake, or QUIC milestone was observed for the probe's own
        // connections during the entire session.
        if coreToPacketFlowDNSResponses > 0 {
            // Tunneled (proxied) DNS answered while no connection packet ever
            // entered the tunnel: the probe traffic bypassed the VPN.
            return "probe.connection_packets_missing"
        }
        return "probe.probe_traffic_absent"
    }

    /// A privacy-safe fallback for the narrow case where the provider-message
    /// reply is lost even though the probe generated real tunnel traffic.
    /// Session identity and monotonic deltas reject stale counter totals.
    public func provesBidirectionalIPv4TunnelProgress(
        since baseline: Self,
        minimumBytesEachDirection: UInt64 = 512
    ) -> Bool {
        guard sessionID == baseline.sessionID,
              packetFlowToCorePackets >= baseline.packetFlowToCorePackets,
              coreToPacketFlowPackets >= baseline.coreToPacketFlowPackets,
              packetFlowToCoreBytes >= baseline.packetFlowToCoreBytes,
              coreToPacketFlowBytes >= baseline.coreToPacketFlowBytes,
              coreToPacketFlowDNSSuccessResponses
                > baseline.coreToPacketFlowDNSSuccessResponses,
              packetFlowToCoreIPv4TCPSYNPackets
                > baseline.packetFlowToCoreIPv4TCPSYNPackets,
              coreToPacketFlowIPv4TCPSYNACKPackets
                > baseline.coreToPacketFlowIPv4TCPSYNACKPackets,
              packetFlowToCoreIPv4TCPDataPackets
                > baseline.packetFlowToCoreIPv4TCPDataPackets,
              coreToPacketFlowIPv4TCPDataPackets
                > baseline.coreToPacketFlowIPv4TCPDataPackets,
              packetFlowToCoreBytes - baseline.packetFlowToCoreBytes
                >= minimumBytesEachDirection,
              coreToPacketFlowBytes - baseline.coreToPacketFlowBytes
                >= minimumBytesEachDirection
        else { return false }
        return true
    }

    /// Compact privacy-safe counter vector for DEBUG diagnostics. Counts and
    /// the stable core code only; no addresses, payloads, node data, or raw
    /// core messages.
    public var probeCounterSummary: String {
        "session=\(sessionID.uuidString.prefix(8)) "
            + "pf2core=\(packetFlowToCorePackets) core2pf=\(coreToPacketFlowPackets) "
            + "bytes=\(packetFlowToCoreBytes)/\(coreToPacketFlowBytes) "
            + "dns=\(packetFlowToCoreDNSQueries)/\(coreToPacketFlowDNSResponses) "
            + "dnsresult=\(coreToPacketFlowDNSSuccessResponses)"
            + "/\(coreToPacketFlowDNSEmptyResponses)"
            + "/\(coreToPacketFlowDNSNameErrorResponses)"
            + "/\(coreToPacketFlowDNSServerFailureResponses)"
            + "/\(coreToPacketFlowDNSOtherErrorResponses) "
            + "syn=\(packetFlowToCoreTCPSYNPackets)/\(coreToPacketFlowTCPSYNACKPackets) "
            + "syn4=\(packetFlowToCoreIPv4TCPSYNPackets)"
            + "/\(coreToPacketFlowIPv4TCPSYNACKPackets) "
            + "syn6=\(packetFlowToCoreIPv6TCPSYNPackets)"
            + "/\(coreToPacketFlowIPv6TCPSYNACKPackets) "
            + "data=\(packetFlowToCoreTCPDataPackets)/\(coreToPacketFlowTCPDataPackets) "
            + "data4=\(packetFlowToCoreIPv4TCPDataPackets)"
            + "/\(coreToPacketFlowIPv4TCPDataPackets) "
            + "data6=\(packetFlowToCoreIPv6TCPDataPackets)"
            + "/\(coreToPacketFlowIPv6TCPDataPackets) "
            + "udp443=\(packetFlowToCoreUDP443Packets)/\(coreToPacketFlowUDP443Packets) "
            + "rst=\(coreToPacketFlowTCPRSTPackets) icmp=\(coreToPacketFlowICMPErrors) "
            + "logevents=\(coreLogEventsReceived)/\(coreErrorLogEventsReceived) "
            + "corelog=\(coreDiagnosticCode ?? "none")"
    }

    /// Merges two probe-time samples. The later sample dominates because
    /// counters are monotonic and the core diagnostic code is sticky, unless
    /// the counters decreased, which proves the packet bridge restarted and
    /// reset them mid-probe.
    public static func preferredProbeSnapshot(
        first: ProviderDataPlaneSnapshot?,
        second: ProviderDataPlaneSnapshot?
    ) -> (snapshot: ProviderDataPlaneSnapshot?, countersReset: Bool) {
        guard let first else { return (second, false) }
        guard let second else { return (first, false) }
        guard second.packetFlowToCorePackets >= first.packetFlowToCorePackets,
              second.coreToPacketFlowPackets >= first.coreToPacketFlowPackets
        else { return (first, true) }
        return (second, false)
    }
}

/// Debounces live DNS health using monotonic, privacy-safe provider counters.
/// One transient lookup failure does not disconnect a session; repeated query
/// windows with a current upstream error do. A successful answer immediately
/// clears the pending failure streak.
public struct ProviderDNSHealthMonitor: Sendable {
    private let consecutiveFailureLimit: Int
    private var previous: ProviderDataPlaneSnapshot?
    private var consecutiveFailureWindows = 0

    public init(consecutiveFailureLimit: Int = 2) {
        self.consecutiveFailureLimit = max(1, consecutiveFailureLimit)
    }

    public mutating func observe(_ snapshot: ProviderDataPlaneSnapshot) -> String? {
        defer { previous = snapshot }
        guard let previous,
              snapshot.sessionID == previous.sessionID,
              snapshot.packetFlowToCoreDNSQueries >= previous.packetFlowToCoreDNSQueries,
              snapshot.coreToPacketFlowDNSResponses
                >= previous.coreToPacketFlowDNSResponses,
              snapshot.coreToPacketFlowDNSSuccessResponses
                >= previous.coreToPacketFlowDNSSuccessResponses,
              snapshot.coreToPacketFlowDNSEmptyResponses
                >= previous.coreToPacketFlowDNSEmptyResponses,
              snapshot.coreToPacketFlowDNSNameErrorResponses
                >= previous.coreToPacketFlowDNSNameErrorResponses,
              snapshot.coreToPacketFlowDNSServerFailureResponses
                >= previous.coreToPacketFlowDNSServerFailureResponses,
              snapshot.coreToPacketFlowDNSOtherErrorResponses
                >= previous.coreToPacketFlowDNSOtherErrorResponses,
              snapshot.coreErrorLogEventsReceived >= previous.coreErrorLogEventsReceived
        else {
            consecutiveFailureWindows = 0
            return nil
        }

        // NOERROR, an empty NOERROR answer, and NXDOMAIN all prove that an
        // upstream resolver answered. They may be application-level misses,
        // but they are not evidence that the VPN's DNS transport is unhealthy.
        let healthyResponseAdvanced = snapshot.coreToPacketFlowDNSSuccessResponses
                > previous.coreToPacketFlowDNSSuccessResponses
            || snapshot.coreToPacketFlowDNSEmptyResponses
                > previous.coreToPacketFlowDNSEmptyResponses
            || snapshot.coreToPacketFlowDNSNameErrorResponses
                > previous.coreToPacketFlowDNSNameErrorResponses
        if healthyResponseAdvanced {
            consecutiveFailureWindows = 0
            return nil
        }

        let queryAdvanced = snapshot.packetFlowToCoreDNSQueries
            > previous.packetFlowToCoreDNSQueries

        guard queryAdvanced,
              let code = snapshot.dnsUpstreamFailureDiagnosticCode
        else { return nil }

        consecutiveFailureWindows += 1
        return consecutiveFailureWindows >= consecutiveFailureLimit ? code : nil
    }

    public mutating func reset() {
        previous = nil
        consecutiveFailureWindows = 0
    }
}

public struct ProviderMessageResponse: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let requestID: UUID
    public let status: ProviderRuntimeStatus?
    public let traffic: ProviderTrafficSnapshot?
    public let dataPlane: ProviderDataPlaneSnapshot?
    public let coreProbe: ProviderCoreProbeSnapshot?
    /// Actual selector state after a selection command or state query.
    public let selectedNodeID: UUID?
    /// `true` only after the provider completes a real TLS/HTTP exchange
    /// through `NEPacketTunnelProvider.virtualInterface`. Optional so older
    /// schema-1 responses remain decodable during an in-place update.
    public let tunnelProbeSucceeded: Bool?
    public let errorCode: String?
    /// Entry-path RTT samples for `entryLatency`. `milliseconds == nil` is Timeout.
    public let entryLatencies: [ProviderEntryLatencySample]?

    public init(
        schemaVersion: Int = ProviderMessageRequest.currentSchemaVersion,
        requestID: UUID,
        status: ProviderRuntimeStatus? = nil,
        traffic: ProviderTrafficSnapshot? = nil,
        dataPlane: ProviderDataPlaneSnapshot? = nil,
        coreProbe: ProviderCoreProbeSnapshot? = nil,
        selectedNodeID: UUID? = nil,
        tunnelProbeSucceeded: Bool? = nil,
        errorCode: String? = nil,
        entryLatencies: [ProviderEntryLatencySample]? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.requestID = requestID
        self.status = status
        self.traffic = traffic
        self.dataPlane = dataPlane
        self.coreProbe = coreProbe
        self.selectedNodeID = selectedNodeID
        self.tunnelProbeSucceeded = tunnelProbeSucceeded
        self.errorCode = errorCode
        self.entryLatencies = entryLatencies
    }
}

public enum ProviderMessageCodecError: Error, Equatable, Sendable {
    case messageTooLarge
    case unsupportedSchema
    case malformedMessage
    case mismatchedResponse
    case providerRejected(String)
}

public enum ProviderMessageCodec {
    public static func encode(_ request: ProviderMessageRequest) throws -> Data {
        let data = try JSONEncoder().encode(request)
        guard data.count <= ProviderMessageRequest.maximumEncodedBytes else {
            throw ProviderMessageCodecError.messageTooLarge
        }
        return data
    }

    public static func decodeRequest(_ data: Data) throws -> ProviderMessageRequest {
        guard data.count <= ProviderMessageRequest.maximumEncodedBytes else {
            throw ProviderMessageCodecError.messageTooLarge
        }
        guard let request = try? JSONDecoder().decode(ProviderMessageRequest.self, from: data) else {
            throw ProviderMessageCodecError.malformedMessage
        }
        guard request.schemaVersion == ProviderMessageRequest.currentSchemaVersion else {
            throw ProviderMessageCodecError.unsupportedSchema
        }
        return request
    }

    public static func encode(_ response: ProviderMessageResponse) throws -> Data {
        let data = try JSONEncoder().encode(response)
        guard data.count <= ProviderMessageRequest.maximumEncodedBytes else {
            throw ProviderMessageCodecError.messageTooLarge
        }
        return data
    }

    public static func decodeResponse(
        _ data: Data,
        matching request: ProviderMessageRequest
    ) throws -> ProviderMessageResponse {
        guard data.count <= ProviderMessageRequest.maximumEncodedBytes else {
            throw ProviderMessageCodecError.messageTooLarge
        }
        guard let response = try? JSONDecoder().decode(ProviderMessageResponse.self, from: data) else {
            throw ProviderMessageCodecError.malformedMessage
        }
        guard response.schemaVersion == ProviderMessageRequest.currentSchemaVersion else {
            throw ProviderMessageCodecError.unsupportedSchema
        }
        guard response.requestID == request.requestID else {
            throw ProviderMessageCodecError.mismatchedResponse
        }
        if let errorCode = response.errorCode {
            throw ProviderMessageCodecError.providerRejected(errorCode)
        }
        return response
    }
}

/// Converts transient sing-box error events into a small, secret-free code
/// vocabulary. The original message is never retained or returned.
public enum CoreLogDiagnosticClassifier {
    public static func stableCode(level: Int32, message: String) -> String? {
        let value = message.lowercased()

        // Libbox's platform stream and its replayable command stream do not
        // expose a reliable severity for every forwarded line. Require an
        // explicit failure marker in the text instead of trusting `level`
        // alone; successful DNS/info lines must never become diagnostics.
        let containsFailureMarker = [
            " error ", "error[", " failed", " failure", " timeout",
            " refused", " unreachable", " no route", "host is down",
            "not permitted", "unexpected", "bad status", "certificate",
            "x509", "tls:", "handshake", "connection reset", "broken pipe",
            "closed network connection", "canceled", "cancelled", " eof",
        ].contains(where: value.contains)
        guard level <= 2 || containsFailureMarker else { return nil }

        if value.contains("missing default interface") {
            return "probe.core_default_interface_missing"
        }

        // These labels describe only the coarse failing layer. They never
        // retain destinations, addresses, UUIDs, or provider-supplied text.
        if value.contains("websocket")
            || value.contains("bad status")
            || value.contains("unexpected status")
            || value.contains("unexpected http response status") {
            return "probe.core_proxy_websocket_failed"
        }

        // Query-based ECH fails while opening the selected proxy transport.
        // Classify it before the nested DNS wording below so a provider-side
        // ECH incompatibility is not presented as ordinary user DNS failure.
        if value.contains("fetch ech config list") {
            return "probe.core_proxy_ech_dns_failed"
        }
        if value.contains("no ech config found in dns records") {
            return "probe.core_proxy_ech_record_missing"
        }
        if value.contains("decode ech config") {
            return "probe.core_proxy_ech_config_invalid"
        }

        // Runtime node outbounds use a per-node `routeva-node-*` tag. Keep
        // accepting the legacy/static `proxy` tag for older sessions and
        // tests, but do not require it or real provider failures disappear
        // into the generic DNS bucket.
        let isSelectedProxy = value.contains("[proxy]")
            || value.contains("[routeva-node-")
        let isProxyFailure = isSelectedProxy
            && (value.contains("open connection to ")
                || value.contains("open packet connection to ")
                || value.contains("listen packet connection using "))
        if isProxyFailure {
            if value.contains("ech rejected without retry config") {
                return "probe.core_proxy_ech_no_retry_config"
            }
            if value.contains("ech retry rejected") {
                return "probe.core_proxy_ech_retry_rejected"
            }
            if value.contains("ech retry unsupported by tls config") {
                return "probe.core_proxy_ech_retry_unsupported"
            }
            if value.contains("ech")
                || value.contains("encrypted client hello") {
                return "probe.core_proxy_ech_rejected"
            }
            if value.contains("network is unreachable")
                || value.contains("no route to host")
                || value.contains("network unreachable")
                || value.contains("host is down")
                || value.contains("operation not permitted") {
                return "probe.core_proxy_unreachable"
            }
            if value.contains("connection refused") {
                return "probe.core_proxy_refused"
            }
            if value.contains("certificate")
                || value.contains("tls handshake")
                || value.contains("x509")
                || value.contains("tls:")
                || value.contains("utls")
                || value.contains("remote error: tls") {
                return "probe.core_proxy_tls_failed"
            }
            if value.contains("i/o timeout")
                || value.contains("deadline exceeded")
                || value.contains("timed out")
                || value.contains("timeout") {
                return "probe.core_proxy_timeout"
            }
            if value.contains("authentication")
                || value.contains("bad response")
                || value.contains("unexpected eof")
                || value.hasSuffix(": eof")
                || value.contains("connection reset")
                || value.contains("broken pipe") {
                return "probe.core_proxy_transport_failed"
            }
            if value.contains("use of closed network connection")
                || value.contains("operation canceled")
                || value.contains("context canceled")
                || value.contains("cancelled") {
                return "probe.core_proxy_cancelled"
            }
            return "probe.core_proxy_failed"
        }

        if value.contains("connection upload handshake:")
            || value.contains("connection download handshake:") {
            if value.contains("i/o timeout")
                || value.contains("deadline exceeded")
                || value.contains("timed out")
                || value.contains("timeout") {
                return "probe.core_connection_handshake_timeout"
            }
            return "probe.core_connection_handshake_failed"
        }

        let isDNSFailure = value.contains("process dns packet")
            || value.contains("exchange failed for")
            || value.contains("lookup failed for")
            || value.contains("dns/")
        guard isDNSFailure else { return nil }

        let scope: String
        if value.contains("dns-bootstrap") {
            scope = "bootstrap"
        } else if value.contains("dns-real") || value.contains("dns-remote") {
            // `dns-real` is the current destination and proxy-endpoint DNS
            // plane. `dns-remote` remains so logs from older sessions still
            // classify.
            scope = "remote"
        } else {
            scope = "upstream"
        }

        if value.contains("network is unreachable")
            || value.contains("no route to host")
            || value.contains("network unreachable") {
            return "probe.core_dns_\(scope)_unreachable"
        }
        if value.contains("connection refused") {
            return "probe.core_dns_\(scope)_refused"
        }
        if value.contains("certificate")
            || value.contains("tls handshake")
            || value.contains("x509") {
            return "probe.core_dns_\(scope)_tls_failed"
        }
        if value.contains("i/o timeout")
            || value.contains("deadline exceeded")
            || value.contains("timed out")
            || value.contains("timeout") {
            return "probe.core_dns_\(scope)_timeout"
        }
        if value.contains("authentication")
            || value.contains("bad response")
            || value.contains("unexpected eof") {
            return "probe.core_dns_\(scope)_transport_failed"
        }
        return "probe.core_dns_\(scope)_failed"
    }

    public static func priority(of code: String?) -> Int {
        guard let code else { return 0 }
        if code == "probe.core_default_interface_missing" { return 4 }
        if code == "probe.core_proxy_ech_no_retry_config"
            || code == "probe.core_proxy_ech_retry_rejected"
            || code == "probe.core_proxy_ech_retry_unsupported" {
            return 4
        }
        if code.hasPrefix("probe.core_proxy_")
            || code.hasPrefix("probe.core_connection_") {
            return 3
        }
        if code.hasSuffix("_failed") && !code.hasSuffix("_transport_failed") { return 1 }
        return 3
    }
}
