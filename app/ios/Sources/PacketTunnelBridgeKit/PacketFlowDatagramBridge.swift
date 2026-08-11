import Darwin
import Foundation
import NetworkExtension

public enum PacketFlowDatagramBridgeError: Error, Equatable, Sendable {
    case creationFailed
    case invalidPacket
    case datagramTooLarge
    case backpressureOverflow
    case packetFlowWriteFailed
    case unexpectedlyClosed

    public var stableDiagnosticCode: String {
        switch self {
        case .creationFailed:
            "provider.packet_bridge_creation_failed"
        case .invalidPacket:
            "provider.packet_bridge_invalid_packet"
        case .datagramTooLarge:
            "provider.packet_bridge_datagram_too_large"
        case .backpressureOverflow:
            "provider.packet_bridge_backpressure_overflow"
        case .packetFlowWriteFailed:
            "provider.packet_bridge_write_failed"
        case .unexpectedlyClosed:
            "provider.packet_bridge_closed"
        }
    }
}

public struct PacketFlowDatagramBridgeTrafficSnapshot: Equatable, Sendable {
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
}

enum PacketFlowTrafficKind: Equatable {
    case dnsQuery
    case dnsResponse
    case udp443Outbound
    case udp443Inbound
    case tcpSYN
    case tcpSYNACK
    case tcpReset
    case tcpData
    case icmpError
    case other
}

enum PacketFlowDNSResponseDisposition: Equatable {
    case success
    case empty
    case nameError
    case serverFailure
    case otherError
}

protocol PacketFlowIO: AnyObject {
    func readPackets(
        completionHandler: @escaping @Sendable ([Data], [NSNumber]) -> Void
    )
    func writePackets(_ packets: [Data], withProtocols protocols: [NSNumber]) -> Bool
}

private final class NetworkExtensionPacketFlowIO: PacketFlowIO, @unchecked Sendable {
    private let packetFlow: NEPacketTunnelFlow

    init(packetFlow: NEPacketTunnelFlow) {
        self.packetFlow = packetFlow
    }

    func readPackets(
        completionHandler: @escaping @Sendable ([Data], [NSNumber]) -> Void
    ) {
        packetFlow.readPackets(completionHandler: completionHandler)
    }

    func writePackets(_ packets: [Data], withProtocols protocols: [NSNumber]) -> Bool {
        packetFlow.writePackets(packets, withProtocols: protocols)
    }
}

/// Bridges Apple's public packet-based Network Extension API to a datagram
/// file descriptor owned by Routeva. The core-facing datagrams use Darwin's
/// four-byte address-family prefix followed by one complete IP packet.
public final class PacketFlowDatagramBridge: @unchecked Sendable {
    public static let recommendedMTU = 4_064

    private static let packetHeaderSize = 4
    /// Darwin AF_UNIX datagram socketpairs default to a send buffer smaller
    /// than Routeva's 4,064-byte TUN MTU. A full IP packet plus the four-byte
    /// family prefix otherwise fails with EMSGSIZE and tears down the bridge.
    private static let minimumSocketBufferSize = 256 * 1_024
    private static let defaultHighWaterMark = 4 * 1_024 * 1_024
    private static let defaultHardLimit = 8 * 1_024 * 1_024

    private let packetIO: any PacketFlowIO
    private let queue: DispatchQueue
    private let queueKey = DispatchSpecificKey<UInt8>()
    private let flowFileDescriptor: Int32
    public let coreFileDescriptor: Int32
    private let maximumPacketSize: Int
    private let highWaterMark: Int
    private let hardLimit: Int
    private let onTraffic: @Sendable (PacketFlowDatagramBridgeTrafficSnapshot) -> Void
    private let onFailure: @Sendable (PacketFlowDatagramBridgeError) -> Void

    private var readSource: DispatchSourceRead?
    private var writeSource: DispatchSourceWrite?
    private var writeSourceSuspended = false
    private var pendingFrames: [Data] = []
    private var pendingFrameIndex = 0
    private var pendingBytes = 0
    private var packetFlowReadPending = false
    private var packetFlowReadCallbacks: UInt64 = 0
    private var packetFlowReadPackets: UInt64 = 0
    private var packetFlowToCorePackets: UInt64 = 0
    private var packetFlowToCoreBytes: UInt64 = 0
    private var coreToPacketFlowPackets: UInt64 = 0
    private var coreToPacketFlowBytes: UInt64 = 0
    private var packetFlowToCoreDNSQueries: UInt64 = 0
    private var coreToPacketFlowDNSResponses: UInt64 = 0
    private var coreToPacketFlowDNSSuccessResponses: UInt64 = 0
    private var coreToPacketFlowDNSEmptyResponses: UInt64 = 0
    private var coreToPacketFlowDNSNameErrorResponses: UInt64 = 0
    private var coreToPacketFlowDNSServerFailureResponses: UInt64 = 0
    private var coreToPacketFlowDNSOtherErrorResponses: UInt64 = 0
    private var packetFlowToCoreUDP443Packets: UInt64 = 0
    private var coreToPacketFlowUDP443Packets: UInt64 = 0
    private var packetFlowToCoreTCPSYNPackets: UInt64 = 0
    private var coreToPacketFlowTCPSYNACKPackets: UInt64 = 0
    private var packetFlowToCoreIPv4TCPSYNPackets: UInt64 = 0
    private var packetFlowToCoreIPv6TCPSYNPackets: UInt64 = 0
    private var coreToPacketFlowIPv4TCPSYNACKPackets: UInt64 = 0
    private var coreToPacketFlowIPv6TCPSYNACKPackets: UInt64 = 0
    private var coreToPacketFlowTCPRSTPackets: UInt64 = 0
    private var coreToPacketFlowICMPErrors: UInt64 = 0
    private var packetFlowToCoreTCPDataPackets: UInt64 = 0
    private var coreToPacketFlowTCPDataPackets: UInt64 = 0
    private var packetFlowToCoreIPv4TCPDataPackets: UInt64 = 0
    private var packetFlowToCoreIPv6TCPDataPackets: UInt64 = 0
    private var coreToPacketFlowIPv4TCPDataPackets: UInt64 = 0
    private var coreToPacketFlowIPv6TCPDataPackets: UInt64 = 0
    private var running = false
    private var closed = false

    public convenience init(
        packetFlow: NEPacketTunnelFlow,
        mtu: Int = PacketFlowDatagramBridge.recommendedMTU,
        onTraffic: @escaping @Sendable (PacketFlowDatagramBridgeTrafficSnapshot) -> Void = { _ in },
        onFailure: @escaping @Sendable (PacketFlowDatagramBridgeError) -> Void
    ) throws {
        try self.init(
            packetIO: NetworkExtensionPacketFlowIO(packetFlow: packetFlow),
            mtu: mtu,
            highWaterMark: Self.defaultHighWaterMark,
            hardLimit: Self.defaultHardLimit,
            onTraffic: onTraffic,
            onFailure: onFailure
        )
    }

    init(
        packetIO: any PacketFlowIO,
        mtu: Int = PacketFlowDatagramBridge.recommendedMTU,
        highWaterMark: Int = PacketFlowDatagramBridge.defaultHighWaterMark,
        hardLimit: Int = PacketFlowDatagramBridge.defaultHardLimit,
        onTraffic: @escaping @Sendable (PacketFlowDatagramBridgeTrafficSnapshot) -> Void = { _ in },
        onFailure: @escaping @Sendable (PacketFlowDatagramBridgeError) -> Void
    ) throws {
        guard mtu > 0, highWaterMark > 0, hardLimit >= highWaterMark else {
            throw PacketFlowDatagramBridgeError.creationFailed
        }

        var descriptors = [Int32](repeating: -1, count: 2)
        guard socketpair(AF_UNIX, SOCK_DGRAM, 0, &descriptors) == 0 else {
            throw PacketFlowDatagramBridgeError.creationFailed
        }

        do {
            let maximumDatagramSize = mtu + Self.packetHeaderSize
            try Self.configure(descriptors[0], maximumDatagramSize: maximumDatagramSize)
            try Self.configure(descriptors[1], maximumDatagramSize: maximumDatagramSize)
        } catch {
            Darwin.close(descriptors[0])
            Darwin.close(descriptors[1])
            throw PacketFlowDatagramBridgeError.creationFailed
        }

        self.packetIO = packetIO
        flowFileDescriptor = descriptors[0]
        coreFileDescriptor = descriptors[1]
        maximumPacketSize = mtu
        self.highWaterMark = highWaterMark
        self.hardLimit = hardLimit
        self.onTraffic = onTraffic
        self.onFailure = onFailure
        queue = DispatchQueue(label: "com.yilinglabs.routeva.packet-flow-bridge")
        queue.setSpecific(key: queueKey, value: 1)
    }

    deinit {
        stop()
    }

    public func start() {
        performOnQueueSync {
            guard !self.running, !self.closed else { return }
            self.running = true
            self.installDispatchSources()
            self.requestPacketFlowReadIfNeeded()
        }
    }

    public func stop() {
        performOnQueueSync {
            self.shutdown(reporting: nil)
        }
    }

    public var isRunning: Bool {
        performOnQueueSync { running && !closed }
    }

    static func frame(packet: Data, protocolFamily: NSNumber) throws -> Data {
        let family = protocolFamily.int32Value
        guard !packet.isEmpty,
              family == AF_INET || family == AF_INET6,
              Self.packetVersion(packet) == (family == AF_INET ? 4 : 6)
        else {
            throw PacketFlowDatagramBridgeError.invalidPacket
        }

        var framed = Data([0, 0, 0, UInt8(truncatingIfNeeded: family)])
        framed.append(packet)
        return framed
    }

    static func unframe(_ datagram: Data) throws -> (packet: Data, protocolFamily: NSNumber) {
        guard datagram.count > packetHeaderSize,
              datagram[0] == 0,
              datagram[1] == 0,
              datagram[2] == 0
        else {
            throw PacketFlowDatagramBridgeError.invalidPacket
        }

        let family = Int32(datagram[3])
        guard family == AF_INET || family == AF_INET6 else {
            throw PacketFlowDatagramBridgeError.invalidPacket
        }
        let packet = datagram.dropFirst(packetHeaderSize)
        guard Self.packetVersion(packet) == (family == AF_INET ? 4 : 6) else {
            throw PacketFlowDatagramBridgeError.invalidPacket
        }
        return (Data(packet), NSNumber(value: family))
    }

    private static func configure(_ descriptor: Int32, maximumDatagramSize: Int) throws {
        guard fcntl(descriptor, F_SETFD, FD_CLOEXEC) != -1 else { throw POSIXError(.EBADF) }
        let flags = fcntl(descriptor, F_GETFL)
        guard flags != -1,
              fcntl(descriptor, F_SETFL, flags | O_NONBLOCK) != -1
        else { throw POSIXError(.EBADF) }
        var noSignal: Int32 = 1
        guard setsockopt(
            descriptor,
            SOL_SOCKET,
            SO_NOSIGPIPE,
            &noSignal,
            socklen_t(MemoryLayout<Int32>.size)
        ) == 0 else { throw POSIXError(.EINVAL) }

        var requestedBufferSize = Int32(max(
            Self.minimumSocketBufferSize,
            maximumDatagramSize * 8
        ))
        for option in [SO_SNDBUF, SO_RCVBUF] {
            guard setsockopt(
                descriptor,
                SOL_SOCKET,
                option,
                &requestedBufferSize,
                socklen_t(MemoryLayout<Int32>.size)
            ) == 0 else { throw POSIXError(.ENOBUFS) }

            var actualBufferSize: Int32 = 0
            var actualBufferSizeLength = socklen_t(MemoryLayout<Int32>.size)
            guard getsockopt(
                descriptor,
                SOL_SOCKET,
                option,
                &actualBufferSize,
                &actualBufferSizeLength
            ) == 0,
                  actualBufferSize >= maximumDatagramSize
            else { throw POSIXError(.ENOBUFS) }
        }
    }

    private static func packetVersion<T: DataProtocol>(_ packet: T) -> UInt8? {
        guard let first = packet.first else { return nil }
        return first >> 4
    }

    static func trafficKind(packet: Data) -> PacketFlowTrafficKind {
        guard let transport = transportHeader(in: packet) else { return .other }
        switch transport.protocolNumber {
        case UInt8(IPPROTO_UDP):
            guard packet.count >= transport.offset + 8 else { return .other }
            let sourcePort = uint16(packet, at: transport.offset)
            let destinationPort = uint16(packet, at: transport.offset + 2)
            if destinationPort == 53 { return .dnsQuery }
            if sourcePort == 53 { return .dnsResponse }
            if destinationPort == 443 { return .udp443Outbound }
            if sourcePort == 443 { return .udp443Inbound }
            return .other
        case UInt8(IPPROTO_TCP):
            guard packet.count >= transport.offset + 20 else { return .other }
            let flags = packet[transport.offset + 13]
            if flags & UInt8(TH_RST) != 0 { return .tcpReset }
            if flags & UInt8(TH_SYN) != 0, flags & UInt8(TH_ACK) != 0 { return .tcpSYNACK }
            if flags & UInt8(TH_SYN) != 0 { return .tcpSYN }
            return tcpPayloadLength(packet: packet, transport: transport) > 0 ? .tcpData : .other
        case UInt8(IPPROTO_ICMP):
            guard transport.ipVersion == 4, packet.count > transport.offset else { return .other }
            return packet[transport.offset] == 3 || packet[transport.offset] == 11
                ? .icmpError : .other
        case UInt8(IPPROTO_ICMPV6):
            guard transport.ipVersion == 6, packet.count > transport.offset else { return .other }
            return packet[transport.offset] == 1 || packet[transport.offset] == 3
                ? .icmpError : .other
        default:
            return .other
        }
    }

    static func dnsResponseDisposition(packet: Data) -> PacketFlowDNSResponseDisposition {
        guard let transport = transportHeader(in: packet),
              transport.protocolNumber == UInt8(IPPROTO_UDP),
              packet.count >= transport.offset + 8,
              uint16(packet, at: transport.offset) == 53
        else { return .otherError }

        let dnsOffset = transport.offset + 8
        guard packet.count >= dnsOffset + 12,
              packet[dnsOffset + 2] & 0x80 != 0
        else { return .otherError }

        let responseCode = packet[dnsOffset + 3] & 0x0F
        let answerCount = uint16(packet, at: dnsOffset + 6)
        switch responseCode {
        case 0:
            return answerCount > 0 ? .success : .empty
        case 2:
            return .serverFailure
        case 3:
            return .nameError
        default:
            return .otherError
        }
    }

    private static func transportHeader(in packet: Data) -> (
        ipVersion: UInt8,
        protocolNumber: UInt8,
        offset: Int
    )? {
        guard let version = packetVersion(packet) else { return nil }
        if version == 4 {
            guard packet.count >= 20 else { return nil }
            let headerLength = Int(packet[0] & 0x0F) * 4
            guard headerLength >= 20, packet.count >= headerLength else { return nil }
            let fragmentOffset = (UInt16(packet[6] & 0x1F) << 8) | UInt16(packet[7])
            guard fragmentOffset == 0 else { return nil }
            return (4, packet[9], headerLength)
        }
        guard version == 6, packet.count >= 40 else { return nil }
        var nextHeader = packet[6]
        var offset = 40
        for _ in 0..<8 {
            switch nextHeader {
            case 0, 43, 60:
                guard packet.count >= offset + 2 else { return nil }
                let length = (Int(packet[offset + 1]) + 1) * 8
                guard length >= 8, packet.count >= offset + length else { return nil }
                nextHeader = packet[offset]
                offset += length
            case 44:
                guard packet.count >= offset + 8 else { return nil }
                let fragmentOffset = (UInt16(packet[offset + 2]) << 8)
                    | UInt16(packet[offset + 3] & 0xF8)
                guard fragmentOffset == 0 else { return nil }
                nextHeader = packet[offset]
                offset += 8
            case 51:
                guard packet.count >= offset + 2 else { return nil }
                let length = (Int(packet[offset + 1]) + 2) * 4
                guard length >= 8, packet.count >= offset + length else { return nil }
                nextHeader = packet[offset]
                offset += length
            default:
                return (6, nextHeader, offset)
            }
        }
        return nil
    }

    private static func uint16(_ packet: Data, at offset: Int) -> UInt16 {
        (UInt16(packet[offset]) << 8) | UInt16(packet[offset + 1])
    }

    /// Payload bytes after the TCP header, derived from IP-level lengths so
    /// IPv6 extension headers are accounted for by the transport offset.
    private static func tcpPayloadLength(
        packet: Data,
        transport: (ipVersion: UInt8, protocolNumber: UInt8, offset: Int)
    ) -> Int {
        let tcpHeaderLength = Int(packet[transport.offset + 12] >> 4) * 4
        guard tcpHeaderLength >= 20,
              packet.count >= transport.offset + tcpHeaderLength
        else { return 0 }
        let ipPayloadLength: Int
        if transport.ipVersion == 4 {
            ipPayloadLength = Int(uint16(packet, at: 2)) - transport.offset
        } else {
            ipPayloadLength = Int(uint16(packet, at: 4)) - (transport.offset - 40)
        }
        return max(0, ipPayloadLength - tcpHeaderLength)
    }

    private func installDispatchSources() {
        let readSource = DispatchSource.makeReadSource(
            fileDescriptor: flowFileDescriptor,
            queue: queue
        )
        readSource.setEventHandler { [weak self] in
            self?.drainCorePackets()
        }
        self.readSource = readSource
        readSource.activate()

        let writeSource = DispatchSource.makeWriteSource(
            fileDescriptor: flowFileDescriptor,
            queue: queue
        )
        writeSource.setEventHandler { [weak self] in
            self?.drainPendingFrames()
        }
        self.writeSource = writeSource
        writeSource.activate()
        writeSource.suspend()
        writeSourceSuspended = true
    }

    private func requestPacketFlowReadIfNeeded() {
        guard running,
              !packetFlowReadPending,
              pendingBytes < highWaterMark
        else { return }

        packetFlowReadPending = true
        packetIO.readPackets { [weak self] packets, protocols in
            guard let self else { return }
            self.queue.async {
                self.packetFlowReadPending = false
                guard self.running else { return }
                self.packetFlowReadCallbacks += 1
                self.packetFlowReadPackets += UInt64(packets.count)
                self.reportTraffic()
                guard packets.count == protocols.count else {
                    self.fail(.invalidPacket)
                    return
                }
                do {
                    for (packet, family) in zip(packets, protocols) {
                        guard packet.count <= self.maximumPacketSize else {
                            throw PacketFlowDatagramBridgeError.invalidPacket
                        }
                        let frame = try Self.frame(packet: packet, protocolFamily: family)
                        try self.enqueue(frame)
                    }
                } catch let error as PacketFlowDatagramBridgeError {
                    self.fail(error)
                    return
                } catch {
                    self.fail(.unexpectedlyClosed)
                    return
                }
                self.drainPendingFrames()
                self.requestPacketFlowReadIfNeeded()
            }
        }
    }

    private func enqueue(_ frame: Data) throws {
        guard pendingBytes + frame.count <= hardLimit else {
            throw PacketFlowDatagramBridgeError.backpressureOverflow
        }
        pendingFrames.append(frame)
        pendingBytes += frame.count
        resumeWriteSourceIfNeeded()
    }

    private func drainPendingFrames() {
        guard running else { return }
        while pendingFrameIndex < pendingFrames.count {
            let frame = pendingFrames[pendingFrameIndex]
            let sent = frame.withUnsafeBytes { bytes in
                Darwin.send(
                    flowFileDescriptor,
                    bytes.baseAddress,
                    bytes.count,
                    MSG_DONTWAIT
                )
            }
            if sent == frame.count {
                pendingBytes -= frame.count
                pendingFrameIndex += 1
                packetFlowToCorePackets += 1
                packetFlowToCoreBytes += UInt64(frame.count - Self.packetHeaderSize)
                let packet = Data(frame.dropFirst(Self.packetHeaderSize))
                switch Self.trafficKind(packet: packet) {
                case .dnsQuery:
                    packetFlowToCoreDNSQueries += 1
                case .udp443Outbound:
                    packetFlowToCoreUDP443Packets += 1
                case .tcpSYN:
                    packetFlowToCoreTCPSYNPackets += 1
                    switch Self.packetVersion(packet) {
                    case 4: packetFlowToCoreIPv4TCPSYNPackets += 1
                    case 6: packetFlowToCoreIPv6TCPSYNPackets += 1
                    default: break
                    }
                case .tcpData:
                    packetFlowToCoreTCPDataPackets += 1
                    switch Self.packetVersion(packet) {
                    case 4: packetFlowToCoreIPv4TCPDataPackets += 1
                    case 6: packetFlowToCoreIPv6TCPDataPackets += 1
                    default: break
                    }
                default:
                    break
                }
                reportTraffic()
                continue
            }
            if sent == -1 {
                switch errno {
                case EINTR:
                    continue
                case EAGAIN, EWOULDBLOCK, ENOBUFS:
                    // AF_UNIX datagram sockets report a full peer queue as
                    // ENOBUFS on Darwin. Preserve this frame and wait for the
                    // write source instead of tearing down a healthy tunnel.
                    return
                case EMSGSIZE:
                    fail(.datagramTooLarge)
                    return
                default:
                    break
                }
            }
            fail(.unexpectedlyClosed)
            return
        }

        pendingFrames.removeAll(keepingCapacity: true)
        pendingFrameIndex = 0
        suspendWriteSourceIfNeeded()
        requestPacketFlowReadIfNeeded()
    }

    private func drainCorePackets() {
        guard running else { return }
        var packets: [Data] = []
        var protocols: [NSNumber] = []
        var buffer = [UInt8](repeating: 0, count: maximumPacketSize + Self.packetHeaderSize)

        while packets.count < 64 {
            let received = Darwin.recv(
                flowFileDescriptor,
                &buffer,
                buffer.count,
                MSG_DONTWAIT
            )
            if received > 0 {
                do {
                    let result = try Self.unframe(Data(buffer.prefix(received)))
                    packets.append(result.packet)
                    protocols.append(result.protocolFamily)
                } catch let error as PacketFlowDatagramBridgeError {
                    fail(error)
                    return
                } catch {
                    fail(.invalidPacket)
                    return
                }
                continue
            }
            if received == -1 {
                switch errno {
                case EINTR:
                    continue
                case EAGAIN, EWOULDBLOCK:
                    break
                default:
                    fail(.unexpectedlyClosed)
                    return
                }
                break
            }
            if received == 0 {
                // SOCK_DGRAM preserves message boundaries; zero denotes an
                // invalid zero-length datagram, not stream-style EOF.
                fail(.invalidPacket)
                return
            }
        }

        guard !packets.isEmpty else { return }
        guard packetIO.writePackets(packets, withProtocols: protocols) else {
            fail(.packetFlowWriteFailed)
            return
        }
        coreToPacketFlowPackets += UInt64(packets.count)
        coreToPacketFlowBytes += UInt64(packets.reduce(0) { $0 + $1.count })
        for packet in packets {
            switch Self.trafficKind(packet: packet) {
            case .dnsResponse:
                coreToPacketFlowDNSResponses += 1
                switch Self.dnsResponseDisposition(packet: packet) {
                case .success:
                    coreToPacketFlowDNSSuccessResponses += 1
                case .empty:
                    coreToPacketFlowDNSEmptyResponses += 1
                case .nameError:
                    coreToPacketFlowDNSNameErrorResponses += 1
                case .serverFailure:
                    coreToPacketFlowDNSServerFailureResponses += 1
                case .otherError:
                    coreToPacketFlowDNSOtherErrorResponses += 1
                }
            case .udp443Inbound:
                coreToPacketFlowUDP443Packets += 1
            case .tcpSYNACK:
                coreToPacketFlowTCPSYNACKPackets += 1
                switch Self.packetVersion(packet) {
                case 4: coreToPacketFlowIPv4TCPSYNACKPackets += 1
                case 6: coreToPacketFlowIPv6TCPSYNACKPackets += 1
                default: break
                }
            case .tcpReset:
                coreToPacketFlowTCPRSTPackets += 1
            case .tcpData:
                coreToPacketFlowTCPDataPackets += 1
                switch Self.packetVersion(packet) {
                case 4: coreToPacketFlowIPv4TCPDataPackets += 1
                case 6: coreToPacketFlowIPv6TCPDataPackets += 1
                default: break
                }
            case .icmpError:
                coreToPacketFlowICMPErrors += 1
            default:
                break
            }
        }
        reportTraffic()
        if packets.count == 64 {
            queue.async { [weak self] in self?.drainCorePackets() }
        }
    }

    private func resumeWriteSourceIfNeeded() {
        guard writeSourceSuspended, let writeSource else { return }
        writeSourceSuspended = false
        writeSource.resume()
    }

    private func suspendWriteSourceIfNeeded() {
        guard !writeSourceSuspended, let writeSource else { return }
        writeSourceSuspended = true
        writeSource.suspend()
    }

    private func fail(_ error: PacketFlowDatagramBridgeError) {
        guard running else { return }
        shutdown(reporting: error)
    }

    private func reportTraffic() {
        onTraffic(PacketFlowDatagramBridgeTrafficSnapshot(
            packetFlowReadCallbacks: packetFlowReadCallbacks,
            packetFlowReadPackets: packetFlowReadPackets,
            packetFlowToCorePackets: packetFlowToCorePackets,
            packetFlowToCoreBytes: packetFlowToCoreBytes,
            coreToPacketFlowPackets: coreToPacketFlowPackets,
            coreToPacketFlowBytes: coreToPacketFlowBytes,
            packetFlowToCoreDNSQueries: packetFlowToCoreDNSQueries,
            coreToPacketFlowDNSResponses: coreToPacketFlowDNSResponses,
            coreToPacketFlowDNSSuccessResponses: coreToPacketFlowDNSSuccessResponses,
            coreToPacketFlowDNSEmptyResponses: coreToPacketFlowDNSEmptyResponses,
            coreToPacketFlowDNSNameErrorResponses: coreToPacketFlowDNSNameErrorResponses,
            coreToPacketFlowDNSServerFailureResponses: coreToPacketFlowDNSServerFailureResponses,
            coreToPacketFlowDNSOtherErrorResponses: coreToPacketFlowDNSOtherErrorResponses,
            packetFlowToCoreUDP443Packets: packetFlowToCoreUDP443Packets,
            coreToPacketFlowUDP443Packets: coreToPacketFlowUDP443Packets,
            packetFlowToCoreTCPSYNPackets: packetFlowToCoreTCPSYNPackets,
            coreToPacketFlowTCPSYNACKPackets: coreToPacketFlowTCPSYNACKPackets,
            packetFlowToCoreIPv4TCPSYNPackets: packetFlowToCoreIPv4TCPSYNPackets,
            packetFlowToCoreIPv6TCPSYNPackets: packetFlowToCoreIPv6TCPSYNPackets,
            coreToPacketFlowIPv4TCPSYNACKPackets: coreToPacketFlowIPv4TCPSYNACKPackets,
            coreToPacketFlowIPv6TCPSYNACKPackets: coreToPacketFlowIPv6TCPSYNACKPackets,
            coreToPacketFlowTCPRSTPackets: coreToPacketFlowTCPRSTPackets,
            coreToPacketFlowICMPErrors: coreToPacketFlowICMPErrors,
            packetFlowToCoreTCPDataPackets: packetFlowToCoreTCPDataPackets,
            coreToPacketFlowTCPDataPackets: coreToPacketFlowTCPDataPackets,
            packetFlowToCoreIPv4TCPDataPackets: packetFlowToCoreIPv4TCPDataPackets,
            packetFlowToCoreIPv6TCPDataPackets: packetFlowToCoreIPv6TCPDataPackets,
            coreToPacketFlowIPv4TCPDataPackets: coreToPacketFlowIPv4TCPDataPackets,
            coreToPacketFlowIPv6TCPDataPackets: coreToPacketFlowIPv6TCPDataPackets
        ))
    }

    private func shutdown(reporting error: PacketFlowDatagramBridgeError?) {
        guard !closed else { return }
        running = false
        closed = true

        readSource?.cancel()
        readSource = nil
        if writeSourceSuspended {
            writeSource?.resume()
            writeSourceSuspended = false
        }
        writeSource?.cancel()
        writeSource = nil

        Darwin.close(flowFileDescriptor)
        Darwin.close(coreFileDescriptor)
        pendingFrames.removeAll()
        pendingBytes = 0

        if let error {
            let handler = onFailure
            DispatchQueue.global(qos: .utility).async {
                handler(error)
            }
        }
    }

    private func performOnQueueSync<T>(_ body: () -> T) -> T {
        if DispatchQueue.getSpecific(key: queueKey) != nil {
            body()
        } else {
            queue.sync(execute: body)
        }
    }
}
