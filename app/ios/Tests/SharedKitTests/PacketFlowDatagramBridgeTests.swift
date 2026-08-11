import Darwin
import Foundation
@testable import PacketTunnelBridgeKit
import XCTest

final class PacketFlowDatagramBridgeTests: XCTestCase {
    func testFramesAndUnframesIPv4AndIPv6() throws {
        let ipv4 = packet(version: 4, count: 20)
        let ipv6 = packet(version: 6, count: 40)

        let framed4 = try PacketFlowDatagramBridge.frame(
            packet: ipv4,
            protocolFamily: NSNumber(value: AF_INET)
        )
        let framed6 = try PacketFlowDatagramBridge.frame(
            packet: ipv6,
            protocolFamily: NSNumber(value: AF_INET6)
        )

        XCTAssertEqual(Array(framed4.prefix(4)), [0, 0, 0, UInt8(AF_INET)])
        XCTAssertEqual(Array(framed6.prefix(4)), [0, 0, 0, UInt8(AF_INET6)])
        XCTAssertEqual(try PacketFlowDatagramBridge.unframe(framed4).packet, ipv4)
        XCTAssertEqual(try PacketFlowDatagramBridge.unframe(framed6).packet, ipv6)
    }

    func testRejectsMismatchedFamilyAndMalformedHeader() throws {
        XCTAssertThrowsError(try PacketFlowDatagramBridge.frame(
            packet: packet(version: 6, count: 40),
            protocolFamily: NSNumber(value: AF_INET)
        ))
        XCTAssertThrowsError(try PacketFlowDatagramBridge.unframe(Data([0, 0, 0, 99, 0x45])))
    }

    func testClassifiesPrivacySafeIPv4ProtocolMilestones() {
        XCTAssertEqual(
            PacketFlowDatagramBridge.trafficKind(packet: ipv4Packet(
                protocolNumber: UInt8(IPPROTO_UDP),
                transport: udpHeader(sourcePort: 50_000, destinationPort: 53)
            )),
            .dnsQuery
        )
        XCTAssertEqual(
            PacketFlowDatagramBridge.trafficKind(packet: ipv4Packet(
                protocolNumber: UInt8(IPPROTO_UDP),
                transport: udpHeader(sourcePort: 53, destinationPort: 50_000)
            )),
            .dnsResponse
        )
        XCTAssertEqual(
            PacketFlowDatagramBridge.trafficKind(packet: ipv4Packet(
                protocolNumber: UInt8(IPPROTO_UDP),
                transport: udpHeader(sourcePort: 50_000, destinationPort: 443)
            )),
            .udp443Outbound
        )
        XCTAssertEqual(
            PacketFlowDatagramBridge.trafficKind(packet: ipv4Packet(
                protocolNumber: UInt8(IPPROTO_UDP),
                transport: udpHeader(sourcePort: 443, destinationPort: 50_000)
            )),
            .udp443Inbound
        )
        XCTAssertEqual(
            PacketFlowDatagramBridge.trafficKind(packet: ipv4Packet(
                protocolNumber: UInt8(IPPROTO_TCP),
                transport: tcpHeader(flags: UInt8(TH_SYN))
            )),
            .tcpSYN
        )
        XCTAssertEqual(
            PacketFlowDatagramBridge.trafficKind(packet: ipv4Packet(
                protocolNumber: UInt8(IPPROTO_TCP),
                transport: tcpHeader(flags: UInt8(TH_SYN | TH_ACK))
            )),
            .tcpSYNACK
        )
        XCTAssertEqual(
            PacketFlowDatagramBridge.trafficKind(packet: ipv4Packet(
                protocolNumber: UInt8(IPPROTO_TCP),
                transport: tcpHeader(flags: UInt8(TH_RST))
            )),
            .tcpReset
        )
        XCTAssertEqual(
            PacketFlowDatagramBridge.trafficKind(packet: ipv4Packet(
                protocolNumber: UInt8(IPPROTO_ICMP),
                transport: [3, 0, 0, 0]
            )),
            .icmpError
        )
    }

    func testClassifiesPrivacySafeDNSResponseOutcomes() {
        func response(_ code: UInt8, answers: UInt16) -> Data {
            ipv4Packet(
                protocolNumber: UInt8(IPPROTO_UDP),
                transport: dnsResponseTransport(responseCode: code, answerCount: answers)
            )
        }

        XCTAssertEqual(
            PacketFlowDatagramBridge.dnsResponseDisposition(packet: response(0, answers: 2)),
            .success
        )
        XCTAssertEqual(
            PacketFlowDatagramBridge.dnsResponseDisposition(packet: response(0, answers: 0)),
            .empty
        )
        XCTAssertEqual(
            PacketFlowDatagramBridge.dnsResponseDisposition(packet: response(3, answers: 0)),
            .nameError
        )
        XCTAssertEqual(
            PacketFlowDatagramBridge.dnsResponseDisposition(packet: response(2, answers: 0)),
            .serverFailure
        )
        XCTAssertEqual(
            PacketFlowDatagramBridge.dnsResponseDisposition(packet: response(5, answers: 0)),
            .otherError
        )
    }

    func testClassifiesTCPDataByPayloadLength() {
        // ACK-only packet (no payload) is not a data packet.
        var ackOnly = [UInt8](repeating: 0, count: 20)
        ackOnly[0] = 0x45
        ackOnly[3] = 40 // totalLength = 20 IPv4 + 20 TCP
        ackOnly[9] = UInt8(IPPROTO_TCP)
        ackOnly.append(contentsOf: tcpHeader(flags: UInt8(TH_ACK)))
        XCTAssertEqual(
            PacketFlowDatagramBridge.trafficKind(packet: Data(ackOnly)),
            .other
        )

        // ACK + PSH with payload counts as data.
        var withData = [UInt8](repeating: 0, count: 20)
        withData[0] = 0x45
        withData[3] = 45 // totalLength = 20 IPv4 + 20 TCP + 5 payload
        withData[9] = UInt8(IPPROTO_TCP)
        withData.append(contentsOf: tcpHeader(flags: UInt8(TH_ACK | 0x08)))
        withData.append(contentsOf: [UInt8](repeating: 0xAA, count: 5))
        XCTAssertEqual(
            PacketFlowDatagramBridge.trafficKind(packet: Data(withData)),
            .tcpData
        )

        // IPv6: payloadLength covers the TCP segment; data beyond the header counts.
        var v6 = [UInt8](repeating: 0, count: 40)
        v6[0] = 0x60
        v6[5] = 25 // payloadLength = 20 TCP + 5 payload
        v6[6] = UInt8(IPPROTO_TCP)
        v6.append(contentsOf: tcpHeader(flags: UInt8(TH_ACK | 0x08)))
        v6.append(contentsOf: [UInt8](repeating: 0xBB, count: 5))
        XCTAssertEqual(
            PacketFlowDatagramBridge.trafficKind(packet: Data(v6)),
            .tcpData
        )

        // SYN with payload must still classify as SYN (flag wins).
        var synWithData = [UInt8](repeating: 0, count: 20)
        synWithData[0] = 0x45
        synWithData[3] = 45
        synWithData[9] = UInt8(IPPROTO_TCP)
        synWithData.append(contentsOf: tcpHeader(flags: UInt8(TH_SYN)))
        synWithData.append(contentsOf: [UInt8](repeating: 0xCC, count: 5))
        XCTAssertEqual(
            PacketFlowDatagramBridge.trafficKind(packet: Data(synWithData)),
            .tcpSYN
        )
    }

    func testClassifiesIPv6TCPWithExtensionHeader() {
        var extensionHeader = [UInt8](repeating: 0, count: 8)
        extensionHeader[0] = UInt8(IPPROTO_TCP)
        extensionHeader.append(contentsOf: tcpHeader(flags: UInt8(TH_SYN | TH_ACK)))
        XCTAssertEqual(
            PacketFlowDatagramBridge.trafficKind(packet: ipv6Packet(
                nextHeader: 60,
                transport: extensionHeader
            )),
            .tcpSYNACK
        )
    }

    func testPacketFlowPacketsReachCoreInOrder() throws {
        let fake = FakePacketFlowIO()
        let traffic = BridgeTrafficRecorder()
        let bridge = try PacketFlowDatagramBridge(
            packetIO: fake,
            onTraffic: { traffic.record($0) },
            onFailure: { _ in }
        )
        bridge.start()

        let ipv4 = packet(version: 4, count: 20)
        let ipv6 = packet(version: 6, count: 40)
        fake.emit(
            packets: [ipv4, ipv6],
            protocols: [NSNumber(value: AF_INET), NSNumber(value: AF_INET6)]
        )

        XCTAssertEqual(try receiveDatagram(from: bridge.coreFileDescriptor), try PacketFlowDatagramBridge.frame(
            packet: ipv4,
            protocolFamily: NSNumber(value: AF_INET)
        ))
        XCTAssertEqual(try receiveDatagram(from: bridge.coreFileDescriptor), try PacketFlowDatagramBridge.frame(
            packet: ipv6,
            protocolFamily: NSNumber(value: AF_INET6)
        ))
        XCTAssertEqual(traffic.snapshot?.packetFlowToCorePackets, 2)
        XCTAssertEqual(traffic.snapshot?.packetFlowToCoreBytes, 60)
        XCTAssertEqual(traffic.snapshot?.packetFlowReadCallbacks, 1)
        XCTAssertEqual(traffic.snapshot?.packetFlowReadPackets, 2)
        XCTAssertEqual(traffic.snapshot?.coreToPacketFlowPackets, 0)
        bridge.stop()
    }

    func testCorePacketsReachPacketFlowInOrder() throws {
        let fake = FakePacketFlowIO()
        let traffic = BridgeTrafficRecorder()
        let wrotePackets = expectation(description: "PacketFlow received packets")
        fake.onWrite = { wrotePackets.fulfill() }
        let bridge = try PacketFlowDatagramBridge(
            packetIO: fake,
            onTraffic: { traffic.record($0) },
            onFailure: { _ in }
        )
        bridge.start()

        let ipv4 = packet(version: 4, count: 20)
        let ipv6 = packet(version: 6, count: 40)
        try sendDatagram(
            try PacketFlowDatagramBridge.frame(
                packet: ipv4,
                protocolFamily: NSNumber(value: AF_INET)
            ),
            to: bridge.coreFileDescriptor
        )
        try sendDatagram(
            try PacketFlowDatagramBridge.frame(
                packet: ipv6,
                protocolFamily: NSNumber(value: AF_INET6)
            ),
            to: bridge.coreFileDescriptor
        )

        wait(for: [wrotePackets], timeout: 1)
        XCTAssertEqual(fake.writtenPackets, [ipv4, ipv6])
        XCTAssertEqual(fake.writtenProtocols.map(\.int32Value), [AF_INET, AF_INET6])
        XCTAssertEqual(traffic.snapshot?.packetFlowToCorePackets, 0)
        XCTAssertEqual(traffic.snapshot?.coreToPacketFlowPackets, 2)
        XCTAssertEqual(traffic.snapshot?.coreToPacketFlowBytes, 60)
        bridge.stop()
    }

    func testFullMTUPacketReachesCoreWithoutDatagramTruncation() throws {
        let fake = FakePacketFlowIO()
        let failed = expectation(description: "Bridge must remain open")
        failed.isInverted = true
        let bridge = try PacketFlowDatagramBridge(packetIO: fake) { _ in
            failed.fulfill()
        }
        bridge.start()

        let packet = packet(
            version: 4,
            count: PacketFlowDatagramBridge.recommendedMTU
        )
        fake.emit(
            packets: [packet],
            protocols: [NSNumber(value: AF_INET)]
        )

        XCTAssertEqual(
            try receiveDatagram(from: bridge.coreFileDescriptor),
            try PacketFlowDatagramBridge.frame(
                packet: packet,
                protocolFamily: NSNumber(value: AF_INET)
            )
        )
        wait(for: [failed], timeout: 0.1)
        bridge.stop()
    }

    func testFullMTUPacketReachesPacketFlowWithoutDatagramTruncation() throws {
        let fake = FakePacketFlowIO()
        let wrotePacket = expectation(description: "PacketFlow received full-MTU packet")
        let failed = expectation(description: "Bridge must remain open")
        failed.isInverted = true
        fake.onWrite = { wrotePacket.fulfill() }
        let bridge = try PacketFlowDatagramBridge(packetIO: fake) { _ in
            failed.fulfill()
        }
        bridge.start()

        let packet = packet(
            version: 4,
            count: PacketFlowDatagramBridge.recommendedMTU
        )
        try sendDatagram(
            try PacketFlowDatagramBridge.frame(
                packet: packet,
                protocolFamily: NSNumber(value: AF_INET)
            ),
            to: bridge.coreFileDescriptor
        )

        wait(for: [wrotePacket], timeout: 1)
        XCTAssertEqual(fake.writtenPackets, [packet])
        wait(for: [failed], timeout: 0.1)
        bridge.stop()
    }

    func testFullMTUBurstSurvivesDarwinDatagramBackpressure() throws {
        let fake = FakePacketFlowIO()
        let failed = expectation(description: "Bridge must not treat queue pressure as closure")
        failed.isInverted = true
        let bridge = try PacketFlowDatagramBridge(packetIO: fake) { _ in
            failed.fulfill()
        }
        bridge.start()

        let packet = packet(
            version: 4,
            count: PacketFlowDatagramBridge.recommendedMTU
        )
        let packetCount = 128
        fake.emit(
            packets: Array(repeating: packet, count: packetCount),
            protocols: Array(repeating: NSNumber(value: AF_INET), count: packetCount)
        )

        for _ in 0..<packetCount {
            let frame = try receiveDatagram(from: bridge.coreFileDescriptor)
            XCTAssertEqual(frame.count, PacketFlowDatagramBridge.recommendedMTU + 4)
            XCTAssertEqual(frame[3], UInt8(AF_INET))
        }
        wait(for: [failed], timeout: 0.1)
        bridge.stop()
    }

    func testBackpressureOverflowFailsClosed() throws {
        let fake = FakePacketFlowIO()
        let failed = expectation(description: "Bridge failed")
        let bridge = try PacketFlowDatagramBridge(
            packetIO: fake,
            mtu: 64,
            highWaterMark: 8,
            hardLimit: 16
        ) { error in
            XCTAssertEqual(error, .backpressureOverflow)
            failed.fulfill()
        }
        bridge.start()
        fake.emit(
            packets: [packet(version: 4, count: 20)],
            protocols: [NSNumber(value: AF_INET)]
        )
        wait(for: [failed], timeout: 1)
    }

    func testPacketFlowWriteFailureIsReported() throws {
        let fake = FakePacketFlowIO()
        fake.writeResult = false
        let failed = expectation(description: "Bridge failed")
        let bridge = try PacketFlowDatagramBridge(packetIO: fake) { error in
            XCTAssertEqual(error, .packetFlowWriteFailed)
            failed.fulfill()
        }
        bridge.start()
        try sendDatagram(
            try PacketFlowDatagramBridge.frame(
                packet: packet(version: 4, count: 20),
                protocolFamily: NSNumber(value: AF_INET)
            ),
            to: bridge.coreFileDescriptor
        )
        wait(for: [failed], timeout: 1)
    }

    func testStopIsIdempotentAndClosesDescriptors() throws {
        let bridge = try PacketFlowDatagramBridge(
            packetIO: FakePacketFlowIO(),
            onFailure: { _ in }
        )
        let descriptor = bridge.coreFileDescriptor
        XCTAssertFalse(bridge.isRunning)
        bridge.start()
        XCTAssertTrue(bridge.isRunning)
        bridge.stop()
        bridge.stop()
        XCTAssertFalse(bridge.isRunning)

        errno = 0
        XCTAssertEqual(fcntl(descriptor, F_GETFD), -1)
        XCTAssertEqual(errno, EBADF)
    }

    private func packet(version: UInt8, count: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        bytes[0] = version << 4
        return Data(bytes)
    }

    private func ipv4Packet(protocolNumber: UInt8, transport: [UInt8]) -> Data {
        var bytes = [UInt8](repeating: 0, count: 20)
        bytes[0] = 0x45
        bytes[9] = protocolNumber
        bytes.append(contentsOf: transport)
        return Data(bytes)
    }

    private func ipv6Packet(nextHeader: UInt8, transport: [UInt8]) -> Data {
        var bytes = [UInt8](repeating: 0, count: 40)
        bytes[0] = 0x60
        bytes[6] = nextHeader
        bytes.append(contentsOf: transport)
        return Data(bytes)
    }

    private func udpHeader(sourcePort: UInt16, destinationPort: UInt16) -> [UInt8] {
        [
            UInt8(sourcePort >> 8), UInt8(truncatingIfNeeded: sourcePort),
            UInt8(destinationPort >> 8), UInt8(truncatingIfNeeded: destinationPort),
            0, 8, 0, 0,
        ]
    }

    private func dnsResponseTransport(
        responseCode: UInt8,
        answerCount: UInt16
    ) -> [UInt8] {
        var udp = udpHeader(sourcePort: 53, destinationPort: 50_000)
        udp[5] = 20
        return udp + [
            0x00, 0x01,
            0x80, responseCode & 0x0F,
            0x00, 0x01,
            UInt8(answerCount >> 8), UInt8(truncatingIfNeeded: answerCount),
            0x00, 0x00,
            0x00, 0x00,
        ]
    }

    private func tcpHeader(flags: UInt8) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 20)
        bytes[12] = 0x50
        bytes[13] = flags
        return bytes
    }

    private func sendDatagram(_ data: Data, to descriptor: Int32) throws {
        let sent = data.withUnsafeBytes { bytes in
            Darwin.send(descriptor, bytes.baseAddress, bytes.count, 0)
        }
        guard sent == data.count else { throw POSIXError(.EIO) }
    }

    private func receiveDatagram(from descriptor: Int32) throws -> Data {
        var pollDescriptor = pollfd(fd: descriptor, events: Int16(POLLIN), revents: 0)
        guard Darwin.poll(&pollDescriptor, 1, 1_000) == 1 else { throw POSIXError(.ETIMEDOUT) }
        var bytes = [UInt8](repeating: 0, count: 4_100)
        let count = Darwin.recv(descriptor, &bytes, bytes.count, 0)
        guard count > 0 else { throw POSIXError(.EIO) }
        return Data(bytes.prefix(count))
    }
}

private final class BridgeTrafficRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storedSnapshot: PacketFlowDatagramBridgeTrafficSnapshot?

    var snapshot: PacketFlowDatagramBridgeTrafficSnapshot? {
        lock.withLock { storedSnapshot }
    }

    func record(_ snapshot: PacketFlowDatagramBridgeTrafficSnapshot) {
        lock.withLock { storedSnapshot = snapshot }
    }
}

private final class FakePacketFlowIO: PacketFlowIO, @unchecked Sendable {
    private let lock = NSLock()
    private var readCompletion: (@Sendable ([Data], [NSNumber]) -> Void)?
    private var writes: [(Data, NSNumber)] = []

    var onWrite: (@Sendable () -> Void)?
    var writeResult = true

    var writtenPackets: [Data] {
        lock.withLock { writes.map(\.0) }
    }

    var writtenProtocols: [NSNumber] {
        lock.withLock { writes.map(\.1) }
    }

    func readPackets(
        completionHandler: @escaping @Sendable ([Data], [NSNumber]) -> Void
    ) {
        lock.withLock { readCompletion = completionHandler }
    }

    func writePackets(_ packets: [Data], withProtocols protocols: [NSNumber]) -> Bool {
        lock.withLock {
            writes.append(contentsOf: zip(packets, protocols))
        }
        onWrite?()
        return writeResult
    }

    func emit(packets: [Data], protocols: [NSNumber]) {
        let completion = lock.withLock { () -> (@Sendable ([Data], [NSNumber]) -> Void)? in
            defer { readCompletion = nil }
            return readCompletion
        }
        completion?(packets, protocols)
    }
}
