import Foundation
import SharedKit

final class ProviderRuntimeStateStore: @unchecked Sendable {
    private struct State {
        var status: ProviderRuntimeStatus = .idle
        var sessionID = UUID()
        var uploadedBytes: UInt64 = 0
        var downloadedBytes: UInt64 = 0
        var packetFlowReadCallbacks: UInt64 = 0
        var packetFlowReadPackets: UInt64 = 0
        var packetFlowToCorePackets: UInt64 = 0
        var packetFlowToCoreBytes: UInt64 = 0
        var coreToPacketFlowPackets: UInt64 = 0
        var coreToPacketFlowBytes: UInt64 = 0
        var packetFlowToCoreDNSQueries: UInt64 = 0
        var coreToPacketFlowDNSResponses: UInt64 = 0
        var coreToPacketFlowDNSSuccessResponses: UInt64 = 0
        var coreToPacketFlowDNSEmptyResponses: UInt64 = 0
        var coreToPacketFlowDNSNameErrorResponses: UInt64 = 0
        var coreToPacketFlowDNSServerFailureResponses: UInt64 = 0
        var coreToPacketFlowDNSOtherErrorResponses: UInt64 = 0
        var packetFlowToCoreUDP443Packets: UInt64 = 0
        var coreToPacketFlowUDP443Packets: UInt64 = 0
        var packetFlowToCoreTCPSYNPackets: UInt64 = 0
        var coreToPacketFlowTCPSYNACKPackets: UInt64 = 0
        var packetFlowToCoreIPv4TCPSYNPackets: UInt64 = 0
        var packetFlowToCoreIPv6TCPSYNPackets: UInt64 = 0
        var coreToPacketFlowIPv4TCPSYNACKPackets: UInt64 = 0
        var coreToPacketFlowIPv6TCPSYNACKPackets: UInt64 = 0
        var coreToPacketFlowTCPRSTPackets: UInt64 = 0
        var coreToPacketFlowICMPErrors: UInt64 = 0
        var packetFlowToCoreTCPDataPackets: UInt64 = 0
        var coreToPacketFlowTCPDataPackets: UInt64 = 0
        var packetFlowToCoreIPv4TCPDataPackets: UInt64 = 0
        var packetFlowToCoreIPv6TCPDataPackets: UInt64 = 0
        var coreToPacketFlowIPv4TCPDataPackets: UInt64 = 0
        var coreToPacketFlowIPv6TCPDataPackets: UInt64 = 0
        /// Total `writeLogs` deliveries observed; distinguishes "core logged
        /// nothing matching" from "the log stream never arrived at all".
        var coreLogEventsReceived: UInt64 = 0
        /// Deliveries at error level or above (sing-box panic/fatal/error).
        var coreErrorLogEventsReceived: UInt64 = 0
        var coreDiagnosticCode: String?
        var lastRequestAt: ContinuousClock.Instant?
    }

    private let lock = NSLock()
    private var state = State()
    private let minimumRequestInterval: Duration = .milliseconds(200)

    func beginSession() {
        lock.withLock {
            state.status = .preparing
            state.sessionID = UUID()
            state.uploadedBytes = 0
            state.downloadedBytes = 0
            state.packetFlowReadCallbacks = 0
            state.packetFlowReadPackets = 0
            state.packetFlowToCorePackets = 0
            state.packetFlowToCoreBytes = 0
            state.coreToPacketFlowPackets = 0
            state.coreToPacketFlowBytes = 0
            state.packetFlowToCoreDNSQueries = 0
            state.coreToPacketFlowDNSResponses = 0
            state.coreToPacketFlowDNSSuccessResponses = 0
            state.coreToPacketFlowDNSEmptyResponses = 0
            state.coreToPacketFlowDNSNameErrorResponses = 0
            state.coreToPacketFlowDNSServerFailureResponses = 0
            state.coreToPacketFlowDNSOtherErrorResponses = 0
            state.packetFlowToCoreUDP443Packets = 0
            state.coreToPacketFlowUDP443Packets = 0
            state.packetFlowToCoreTCPSYNPackets = 0
            state.coreToPacketFlowTCPSYNACKPackets = 0
            state.packetFlowToCoreIPv4TCPSYNPackets = 0
            state.packetFlowToCoreIPv6TCPSYNPackets = 0
            state.coreToPacketFlowIPv4TCPSYNACKPackets = 0
            state.coreToPacketFlowIPv6TCPSYNACKPackets = 0
            state.coreToPacketFlowTCPRSTPackets = 0
            state.coreToPacketFlowICMPErrors = 0
            state.packetFlowToCoreTCPDataPackets = 0
            state.coreToPacketFlowTCPDataPackets = 0
            state.packetFlowToCoreIPv4TCPDataPackets = 0
            state.packetFlowToCoreIPv6TCPDataPackets = 0
            state.coreToPacketFlowIPv4TCPDataPackets = 0
            state.coreToPacketFlowIPv6TCPDataPackets = 0
            state.coreLogEventsReceived = 0
            state.coreErrorLogEventsReceived = 0
            state.coreDiagnosticCode = nil
            state.lastRequestAt = nil
        }
    }

    func setStatus(_ status: ProviderRuntimeStatus) {
        lock.withLock { state.status = status }
    }

    func updateTraffic(uploadedBytes: UInt64, downloadedBytes: UInt64) {
        lock.withLock {
            state.uploadedBytes = max(state.uploadedBytes, uploadedBytes)
            state.downloadedBytes = max(state.downloadedBytes, downloadedBytes)
        }
    }

    func updateDataPlane(
        packetFlowReadCallbacks: UInt64,
        packetFlowReadPackets: UInt64,
        packetFlowToCorePackets: UInt64,
        packetFlowToCoreBytes: UInt64,
        coreToPacketFlowPackets: UInt64,
        coreToPacketFlowBytes: UInt64,
        packetFlowToCoreDNSQueries: UInt64,
        coreToPacketFlowDNSResponses: UInt64,
        coreToPacketFlowDNSSuccessResponses: UInt64 = 0,
        coreToPacketFlowDNSEmptyResponses: UInt64 = 0,
        coreToPacketFlowDNSNameErrorResponses: UInt64 = 0,
        coreToPacketFlowDNSServerFailureResponses: UInt64 = 0,
        coreToPacketFlowDNSOtherErrorResponses: UInt64 = 0,
        packetFlowToCoreUDP443Packets: UInt64,
        coreToPacketFlowUDP443Packets: UInt64,
        packetFlowToCoreTCPSYNPackets: UInt64,
        coreToPacketFlowTCPSYNACKPackets: UInt64,
        packetFlowToCoreIPv4TCPSYNPackets: UInt64 = 0,
        packetFlowToCoreIPv6TCPSYNPackets: UInt64 = 0,
        coreToPacketFlowIPv4TCPSYNACKPackets: UInt64 = 0,
        coreToPacketFlowIPv6TCPSYNACKPackets: UInt64 = 0,
        coreToPacketFlowTCPRSTPackets: UInt64,
        coreToPacketFlowICMPErrors: UInt64,
        packetFlowToCoreTCPDataPackets: UInt64 = 0,
        coreToPacketFlowTCPDataPackets: UInt64 = 0,
        packetFlowToCoreIPv4TCPDataPackets: UInt64 = 0,
        packetFlowToCoreIPv6TCPDataPackets: UInt64 = 0,
        coreToPacketFlowIPv4TCPDataPackets: UInt64 = 0,
        coreToPacketFlowIPv6TCPDataPackets: UInt64 = 0
    ) {
        lock.withLock {
            state.packetFlowReadCallbacks = packetFlowReadCallbacks
            state.packetFlowReadPackets = packetFlowReadPackets
            state.packetFlowToCorePackets = packetFlowToCorePackets
            state.packetFlowToCoreBytes = packetFlowToCoreBytes
            state.coreToPacketFlowPackets = coreToPacketFlowPackets
            state.coreToPacketFlowBytes = coreToPacketFlowBytes
            state.packetFlowToCoreDNSQueries = packetFlowToCoreDNSQueries
            state.coreToPacketFlowDNSResponses = coreToPacketFlowDNSResponses
            state.coreToPacketFlowDNSSuccessResponses =
                coreToPacketFlowDNSSuccessResponses
            state.coreToPacketFlowDNSEmptyResponses =
                coreToPacketFlowDNSEmptyResponses
            state.coreToPacketFlowDNSNameErrorResponses =
                coreToPacketFlowDNSNameErrorResponses
            state.coreToPacketFlowDNSServerFailureResponses =
                coreToPacketFlowDNSServerFailureResponses
            state.coreToPacketFlowDNSOtherErrorResponses =
                coreToPacketFlowDNSOtherErrorResponses
            state.packetFlowToCoreUDP443Packets = packetFlowToCoreUDP443Packets
            state.coreToPacketFlowUDP443Packets = coreToPacketFlowUDP443Packets
            state.packetFlowToCoreTCPSYNPackets = packetFlowToCoreTCPSYNPackets
            state.coreToPacketFlowTCPSYNACKPackets = coreToPacketFlowTCPSYNACKPackets
            state.packetFlowToCoreIPv4TCPSYNPackets =
                packetFlowToCoreIPv4TCPSYNPackets
            state.packetFlowToCoreIPv6TCPSYNPackets =
                packetFlowToCoreIPv6TCPSYNPackets
            state.coreToPacketFlowIPv4TCPSYNACKPackets =
                coreToPacketFlowIPv4TCPSYNACKPackets
            state.coreToPacketFlowIPv6TCPSYNACKPackets =
                coreToPacketFlowIPv6TCPSYNACKPackets
            state.coreToPacketFlowTCPRSTPackets = coreToPacketFlowTCPRSTPackets
            state.coreToPacketFlowICMPErrors = coreToPacketFlowICMPErrors
            state.packetFlowToCoreTCPDataPackets = packetFlowToCoreTCPDataPackets
            state.coreToPacketFlowTCPDataPackets = coreToPacketFlowTCPDataPackets
            state.packetFlowToCoreIPv4TCPDataPackets =
                packetFlowToCoreIPv4TCPDataPackets
            state.packetFlowToCoreIPv6TCPDataPackets =
                packetFlowToCoreIPv6TCPDataPackets
            state.coreToPacketFlowIPv4TCPDataPackets =
                coreToPacketFlowIPv4TCPDataPackets
            state.coreToPacketFlowIPv6TCPDataPackets =
                coreToPacketFlowIPv6TCPDataPackets
        }
    }

    func recordCoreLogEvent(isError: Bool) {
        lock.withLock {
            state.coreLogEventsReceived += 1
            if isError { state.coreErrorLogEventsReceived += 1 }
        }
    }

    func recordCoreDiagnosticCode(_ code: String) {
        lock.withLock {
            guard CoreLogDiagnosticClassifier.priority(of: code)
                    >= CoreLogDiagnosticClassifier.priority(of: state.coreDiagnosticCode)
            else { return }
            state.coreDiagnosticCode = code
        }
    }

    func response(to data: Data) -> Data? {
        let request: ProviderMessageRequest
        do {
            request = try ProviderMessageCodec.decodeRequest(data)
        } catch {
            return nil
        }

        let response: ProviderMessageResponse = lock.withLock {
            let now = ContinuousClock.now
            if let lastRequestAt = state.lastRequestAt,
               now - lastRequestAt < minimumRequestInterval {
                return ProviderMessageResponse(
                    requestID: request.requestID,
                    errorCode: "provider.rate_limited"
                )
            }
            state.lastRequestAt = now
            switch request.kind {
            case .status:
                return ProviderMessageResponse(requestID: request.requestID, status: state.status)
            case .traffic:
                return ProviderMessageResponse(
                    requestID: request.requestID,
                    traffic: ProviderTrafficSnapshot.userVisible(
                        sessionID: state.sessionID,
                        coreUploadedBytes: state.uploadedBytes,
                        coreDownloadedBytes: state.downloadedBytes,
                        packetFlowUploadedBytes: state.packetFlowToCoreBytes,
                        packetFlowDownloadedBytes: state.coreToPacketFlowBytes
                    )
                )
            case .dataPlane:
                return ProviderMessageResponse(
                    requestID: request.requestID,
                    dataPlane: ProviderDataPlaneSnapshot(
                        sessionID: state.sessionID,
                        packetFlowReadCallbacks: state.packetFlowReadCallbacks,
                        packetFlowReadPackets: state.packetFlowReadPackets,
                        packetFlowToCorePackets: state.packetFlowToCorePackets,
                        packetFlowToCoreBytes: state.packetFlowToCoreBytes,
                        coreToPacketFlowPackets: state.coreToPacketFlowPackets,
                        coreToPacketFlowBytes: state.coreToPacketFlowBytes,
                        packetFlowToCoreDNSQueries: state.packetFlowToCoreDNSQueries,
                        coreToPacketFlowDNSResponses: state.coreToPacketFlowDNSResponses,
                        coreToPacketFlowDNSSuccessResponses:
                            state.coreToPacketFlowDNSSuccessResponses,
                        coreToPacketFlowDNSEmptyResponses:
                            state.coreToPacketFlowDNSEmptyResponses,
                        coreToPacketFlowDNSNameErrorResponses:
                            state.coreToPacketFlowDNSNameErrorResponses,
                        coreToPacketFlowDNSServerFailureResponses:
                            state.coreToPacketFlowDNSServerFailureResponses,
                        coreToPacketFlowDNSOtherErrorResponses:
                            state.coreToPacketFlowDNSOtherErrorResponses,
                        packetFlowToCoreUDP443Packets: state.packetFlowToCoreUDP443Packets,
                        coreToPacketFlowUDP443Packets: state.coreToPacketFlowUDP443Packets,
                        packetFlowToCoreTCPSYNPackets: state.packetFlowToCoreTCPSYNPackets,
                        coreToPacketFlowTCPSYNACKPackets: state.coreToPacketFlowTCPSYNACKPackets,
                        packetFlowToCoreIPv4TCPSYNPackets:
                            state.packetFlowToCoreIPv4TCPSYNPackets,
                        packetFlowToCoreIPv6TCPSYNPackets:
                            state.packetFlowToCoreIPv6TCPSYNPackets,
                        coreToPacketFlowIPv4TCPSYNACKPackets:
                            state.coreToPacketFlowIPv4TCPSYNACKPackets,
                        coreToPacketFlowIPv6TCPSYNACKPackets:
                            state.coreToPacketFlowIPv6TCPSYNACKPackets,
                        coreToPacketFlowTCPRSTPackets: state.coreToPacketFlowTCPRSTPackets,
                        coreToPacketFlowICMPErrors: state.coreToPacketFlowICMPErrors,
                        packetFlowToCoreTCPDataPackets: state.packetFlowToCoreTCPDataPackets,
                        coreToPacketFlowTCPDataPackets: state.coreToPacketFlowTCPDataPackets,
                        packetFlowToCoreIPv4TCPDataPackets:
                            state.packetFlowToCoreIPv4TCPDataPackets,
                        packetFlowToCoreIPv6TCPDataPackets:
                            state.packetFlowToCoreIPv6TCPDataPackets,
                        coreToPacketFlowIPv4TCPDataPackets:
                            state.coreToPacketFlowIPv4TCPDataPackets,
                        coreToPacketFlowIPv6TCPDataPackets:
                            state.coreToPacketFlowIPv6TCPDataPackets,
                        coreLogEventsReceived: state.coreLogEventsReceived,
                        coreErrorLogEventsReceived: state.coreErrorLogEventsReceived,
                        coreDiagnosticCode: state.coreDiagnosticCode
                    )
                )
            case .coreProbe:
                // Core-specific providers handle this asynchronous request.
                // The shared fallback fails closed instead of claiming that
                // ordinary PacketFlow chatter verified proxy egress.
                return ProviderMessageResponse(
                    requestID: request.requestID,
                    errorCode: "probe.core_url_test_unsupported"
                )
            case .selectNode, .selectedNode, .reloadConfiguration,
                 .finalizeConfigurationReload:
                // The sing-box provider intercepts selector and catalog
                // messages. Shared fallbacks fail closed without changing state.
                return ProviderMessageResponse(
                    requestID: request.requestID,
                    errorCode: "provider.node_selection_unsupported"
                )
            case .entryLatency:
                return ProviderMessageResponse(
                    requestID: request.requestID,
                    errorCode: ProviderEntryLatencyCode.physicalPathUnavailable
                )
            }
        }
        return try? ProviderMessageCodec.encode(response)
    }
}
