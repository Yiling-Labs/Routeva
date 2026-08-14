import Foundation
import Network
import NetworkExtension
import PacketTunnelBridgeKit
import SharedKit

#if canImport(Libbox)
@preconcurrency import Libbox

final class SingBoxPlatformInterface: NSObject, LibboxPlatformInterfaceProtocol, LibboxCommandServerHandlerProtocol, LibboxCommandClientHandlerProtocol, @unchecked Sendable {
    private weak var tunnel: NEPacketTunnelProvider?
    private let runtimeState: ProviderRuntimeStateStore
    private let directRouteAddressesLock = NSLock()
    private var directRouteAddresses: [String]
    private let onBridgeStarting: @Sendable () -> Void
    private let onBridgeFailure: @Sendable (PacketTunnelRuntimeError) -> Void
    private var networkSettings: NEPacketTunnelNetworkSettings?
    private var pathMonitor: NWPathMonitor?
    private let packetBridgeLock = NSLock()
    private var packetBridge: PacketFlowDatagramBridge?
    private var packetBridgeID: UUID?
    private let coreURLTestTracker = CoreURLTestResultTracker()
    private let selectorSelectionTracker = SingBoxSelectorSelectionTracker()

    init(
        tunnel: NEPacketTunnelProvider,
        runtimeState: ProviderRuntimeStateStore,
        directRouteAddresses: [String],
        onBridgeStarting: @escaping @Sendable () -> Void,
        onBridgeFailure: @escaping @Sendable (PacketTunnelRuntimeError) -> Void
    ) {
        self.tunnel = tunnel
        self.runtimeState = runtimeState
        self.directRouteAddresses = DirectRouteAddressValidator.validated(directRouteAddresses)
        self.onBridgeStarting = onBridgeStarting
        self.onBridgeFailure = onBridgeFailure
    }

    func openTun(_ options: LibboxTunOptionsProtocol?, ret0_: UnsafeMutablePointer<Int32>?) throws {
        guard let tunnel, let options, let ret0_ else {
            throw PacketTunnelRuntimeError.tunnelFileDescriptorUnavailable
        }

        let settings = makeNetworkSettings(options)
        let completion = NetworkSettingsCompletion()
        tunnel.setTunnelNetworkSettings(settings) { error in
            completion.finish(error)
        }
        guard completion.wait(timeout: .now() + 15) else {
            throw PacketTunnelRuntimeError.networkSettingsTimedOut
        }
        if let error = completion.error {
            throw error
        }

        networkSettings = settings
        onBridgeStarting()
        do {
            stopPacketBridge()
            let bridgeID = UUID()
            let bridge = try PacketFlowDatagramBridge(
                packetFlow: tunnel.packetFlow,
                mtu: PacketFlowDatagramBridge.recommendedMTU,
                onTraffic: { [runtimeState] snapshot in
                    runtimeState.updateDataPlane(
                        packetFlowReadCallbacks: snapshot.packetFlowReadCallbacks,
                        packetFlowReadPackets: snapshot.packetFlowReadPackets,
                        packetFlowToCorePackets: snapshot.packetFlowToCorePackets,
                        packetFlowToCoreBytes: snapshot.packetFlowToCoreBytes,
                        coreToPacketFlowPackets: snapshot.coreToPacketFlowPackets,
                        coreToPacketFlowBytes: snapshot.coreToPacketFlowBytes,
                        packetFlowToCoreDNSQueries: snapshot.packetFlowToCoreDNSQueries,
                        coreToPacketFlowDNSResponses: snapshot.coreToPacketFlowDNSResponses,
                        coreToPacketFlowDNSSuccessResponses:
                            snapshot.coreToPacketFlowDNSSuccessResponses,
                        coreToPacketFlowDNSEmptyResponses:
                            snapshot.coreToPacketFlowDNSEmptyResponses,
                        coreToPacketFlowDNSNameErrorResponses:
                            snapshot.coreToPacketFlowDNSNameErrorResponses,
                        coreToPacketFlowDNSServerFailureResponses:
                            snapshot.coreToPacketFlowDNSServerFailureResponses,
                        coreToPacketFlowDNSOtherErrorResponses:
                            snapshot.coreToPacketFlowDNSOtherErrorResponses,
                        packetFlowToCoreUDP443Packets: snapshot.packetFlowToCoreUDP443Packets,
                        coreToPacketFlowUDP443Packets: snapshot.coreToPacketFlowUDP443Packets,
                        packetFlowToCoreTCPSYNPackets: snapshot.packetFlowToCoreTCPSYNPackets,
                        coreToPacketFlowTCPSYNACKPackets: snapshot.coreToPacketFlowTCPSYNACKPackets,
                        packetFlowToCoreIPv4TCPSYNPackets:
                            snapshot.packetFlowToCoreIPv4TCPSYNPackets,
                        packetFlowToCoreIPv6TCPSYNPackets:
                            snapshot.packetFlowToCoreIPv6TCPSYNPackets,
                        coreToPacketFlowIPv4TCPSYNACKPackets:
                            snapshot.coreToPacketFlowIPv4TCPSYNACKPackets,
                        coreToPacketFlowIPv6TCPSYNACKPackets:
                            snapshot.coreToPacketFlowIPv6TCPSYNACKPackets,
                        coreToPacketFlowTCPRSTPackets: snapshot.coreToPacketFlowTCPRSTPackets,
                        coreToPacketFlowICMPErrors: snapshot.coreToPacketFlowICMPErrors,
                        packetFlowToCoreTCPDataPackets: snapshot.packetFlowToCoreTCPDataPackets,
                        coreToPacketFlowTCPDataPackets: snapshot.coreToPacketFlowTCPDataPackets,
                        packetFlowToCoreIPv4TCPDataPackets:
                            snapshot.packetFlowToCoreIPv4TCPDataPackets,
                        packetFlowToCoreIPv6TCPDataPackets:
                            snapshot.packetFlowToCoreIPv6TCPDataPackets,
                        coreToPacketFlowIPv4TCPDataPackets:
                            snapshot.coreToPacketFlowIPv4TCPDataPackets,
                        coreToPacketFlowIPv6TCPDataPackets:
                            snapshot.coreToPacketFlowIPv6TCPDataPackets
                    )
                }
            ) { [weak self, onBridgeFailure] error in
                guard self?.isCurrentPacketBridge(bridgeID) == true else { return }
                onBridgeFailure(.packetBridgeFailure(error.stableDiagnosticCode))
            }
            packetBridgeLock.withLock {
                packetBridge = bridge
                packetBridgeID = bridgeID
            }
            ret0_.pointee = bridge.coreFileDescriptor
        } catch let error as PacketFlowDatagramBridgeError {
            throw PacketTunnelRuntimeError.packetBridgeFailure(error.stableDiagnosticCode)
        }
    }

    func usePlatformAutoDetectControl() -> Bool { false }
    func usePlatformPacketFlowBridge() -> Bool { true }

    func autoDetectControl(_ fd: Int32) throws {}

    func findConnectionOwner(
        _ ipProtocol: Int32,
        sourceAddress: String?,
        sourcePort: Int32,
        destinationAddress: String?,
        destinationPort: Int32
    ) throws -> LibboxConnectionOwner {
        throw PacketTunnelRuntimeError.coreFailure("Process lookup is unavailable in the iOS Packet Tunnel.")
    }

    func useProcFS() -> Bool { false }
    func underNetworkExtension() -> Bool { true }
    // Must mirror NETunnelProviderProtocol.includeAllNetworks. Routeva uses
    // explicit default routes plus host-sized physical-path exclusions rather
    // than Apple's stronger include-all capture mode.
    func includeAllNetworks() -> Bool { false }
    func localDNSTransport() -> LibboxLocalDNSTransportProtocol? { nil }
    func systemCertificates() -> LibboxStringIteratorProtocol? { nil }
    func readWIFIState() -> LibboxWIFIState? { nil }
    func send(_ notification: LibboxNotification?) throws {}

    func startDefaultInterfaceMonitor(_ listener: LibboxInterfaceUpdateListenerProtocol?) throws {
        guard let listener else { return }
        let monitor = NWPathMonitor()
        let readiness = PathMonitorReadiness()
        monitor.pathUpdateHandler = { [weak self] path in
            self?.updateDefaultInterface(listener, path: path)
            readiness.finish()
        }
        pathMonitor = monitor
        monitor.start(queue: DispatchQueue(label: "com.yilinglabs.routeva.sing-box.path"))
        guard readiness.wait(timeout: .now() + 5) else {
            monitor.cancel()
            pathMonitor = nil
            throw PacketTunnelRuntimeError.defaultInterfaceTimedOut
        }
    }

    func closeDefaultInterfaceMonitor(_ listener: LibboxInterfaceUpdateListenerProtocol?) throws {
        pathMonitor?.cancel()
        pathMonitor = nil
    }

    func getInterfaces() throws -> LibboxNetworkInterfaceIteratorProtocol {
        var interfaces: [LibboxNetworkInterface] = []
        if let availableInterfaces = pathMonitor?.currentPath.availableInterfaces {
            for pathInterface in availableInterfaces {
                let interface = LibboxNetworkInterface()
                interface.name = pathInterface.name
                interface.index = Int32(pathInterface.index)
                switch pathInterface.type {
                case .wifi:
                    interface.type = LibboxInterfaceTypeWIFI
                case .cellular:
                    interface.type = LibboxInterfaceTypeCellular
                case .wiredEthernet:
                    interface.type = LibboxInterfaceTypeEthernet
                default:
                    interface.type = LibboxInterfaceTypeOther
                }
                interfaces.append(interface)
            }
        }
        return NetworkInterfaceIterator(interfaces)
    }

    private func updateDefaultInterface(
        _ listener: LibboxInterfaceUpdateListenerProtocol,
        path: NWPath
    ) {
        guard path.status != .unsatisfied, let interface = path.availableInterfaces.first else {
            listener.updateDefaultInterface(
                "",
                interfaceIndex: -1,
                isExpensive: false,
                isConstrained: false
            )
            return
        }
        listener.updateDefaultInterface(
            interface.name,
            interfaceIndex: Int32(interface.index),
            isExpensive: path.isExpensive,
            isConstrained: path.isConstrained
        )
    }

    func clearDNSCache() {
        // Routeva does not hold a separate DNS cache in the provider process.
    }

    func serviceStop() throws {
        try LibboxNewStandaloneCommandClient()?.serviceClose()
    }

    func serviceReload() throws {
        try LibboxNewStandaloneCommandClient()?.serviceReload()
    }

    func stopPacketBridge() {
        let bridge: PacketFlowDatagramBridge? = packetBridgeLock.withLock {
            let current = packetBridge
            packetBridge = nil
            packetBridgeID = nil
            return current
        }
        bridge?.stop()
    }

    /// Updates the host-sized physical-network exclusions used by the next
    /// `openTun`. Libbox opens a new TUN as part of service reload, so changing
    /// this snapshot before `startOrReloadService` keeps new node endpoints
    /// from recursively entering the still-running Packet Tunnel.
    @discardableResult
    func updateDirectRouteAddresses(_ addresses: [String]) -> [String] {
        let validated = DirectRouteAddressValidator.validated(addresses)
        return directRouteAddressesLock.withLock {
            let previous = directRouteAddresses
            directRouteAddresses = validated
            return previous
        }
    }

    func startPacketBridge() throws {
        guard let bridge = packetBridgeLock.withLock({ packetBridge }) else {
            throw PacketTunnelRuntimeError.packetBridgeFailure(
                "provider.packet_bridge_creation_failed"
            )
        }
        bridge.start()
        guard bridge.isRunning else {
            throw PacketTunnelRuntimeError.packetBridgeFailure(
                "provider.packet_bridge_closed"
            )
        }
    }

    func isPacketBridgeRunning() -> Bool {
        packetBridgeLock.withLock { packetBridge }?.isRunning == true
    }

    private func isCurrentPacketBridge(_ id: UUID) -> Bool {
        packetBridgeLock.withLock { packetBridgeID == id }
    }

    func resetCoreURLTestResult() {
        coreURLTestTracker.reset()
    }

    func currentCoreURLTestLatency() -> UInt32? {
        coreURLTestTracker.currentLatencyMilliseconds()
    }

    func waitForCoreURLTestSuccess(timeout: TimeInterval) -> UInt32? {
        coreURLTestTracker.waitForSuccess(timeout: timeout)
    }

    func resetSelectorSelection() {
        selectorSelectionTracker.reset()
    }

    func currentSelectedNodeID() -> UUID? {
        selectorSelectionTracker.currentNodeID()
    }

    func waitForSelectedNode(_ nodeID: UUID, timeout: TimeInterval) -> Bool {
        selectorSelectionTracker.waitForSelection(nodeID, timeout: timeout)
    }

    func getSystemProxyStatus() throws -> LibboxSystemProxyStatus {
        let status = LibboxSystemProxyStatus()
        status.available = false
        status.enabled = false
        return status
    }

    func setSystemProxyEnabled(_ enabled: Bool) throws {
        // Routeva does not expose a second HTTP system proxy inside the VPN.
    }

    func writeDebugMessage(_ message: String?) {
        // Deliberately do not forward Core debug strings to unified logging.
    }

    func connected() {}
    func disconnected(_ message: String?) {}
    func setDefaultLogLevel(_ level: Int32) {}
    func clearLogs() {}
    func writeLogs(_ messageList: LibboxLogIteratorProtocol?) {
        guard let messageList else { return }
        while messageList.hasNext() {
            guard let entry = messageList.next() else { continue }
            // sing-box levels: panic 0, fatal 1, error 2 (mirrors the
            // classifier's threshold).
            runtimeState.recordCoreLogEvent(isError: entry.level <= 2)
            guard let code = CoreLogDiagnosticClassifier.stableCode(
                level: entry.level,
                message: entry.message
            ) else { continue }
            runtimeState.recordCoreDiagnosticCode(code)
        }
    }
    func writeGroups(_ message: LibboxOutboundGroupIteratorProtocol?) {
        guard let message else { return }
        while message.hasNext() {
            guard let group = message.next() else { continue }
            if group.tag == SingBoxNodeSelector.groupTag {
                selectorSelectionTracker.record(
                    selectedOutboundTag: group.selected
                )
            }
            guard group.tag == "routeva-probe", let items = group.getItems()
            else { continue }
            while items.hasNext() {
                guard let item = items.next(),
                      item.tag == SingBoxNodeSelector.groupTag
                else { continue }
                coreURLTestTracker.record(
                    testTime: item.urlTestTime,
                    latencyMilliseconds: item.urlTestDelay
                )
            }
        }
    }
    func initializeClashMode(_ modeList: LibboxStringIteratorProtocol?, currentMode: String?) {}
    func updateClashMode(_ newMode: String?) {}
    func write(_ events: LibboxConnectionEvents?) {}

    func writeStatus(_ message: LibboxStatusMessage?) {
        guard let message, message.trafficAvailable else { return }
        runtimeState.updateTraffic(
            uploadedBytes: UInt64(max(0, message.uplinkTotal)),
            downloadedBytes: UInt64(max(0, message.downlinkTotal))
        )
    }

    private func makeNetworkSettings(_ options: LibboxTunOptionsProtocol) -> NEPacketTunnelNetworkSettings {
        // gVisor terminates packets in-process; there is no remote tunnel
        // server. Use the same loopback endpoint as sing-box's Apple client so
        // NetworkExtension does not path-evaluate a synthetic Internet host.
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        settings.mtu = NSNumber(value: options.getMTU())
        let routeExclusionAddresses: [String] = directRouteAddressesLock.withLock {
            self.directRouteAddresses
        }

        let dnsAddress = (try? options.getDNSServerAddress().value) ?? ""
        if !dnsAddress.isEmpty {
            let dns = NEDNSSettings(servers: [dnsAddress])
            dns.matchDomains = [""]
            settings.dnsSettings = dns
        }

        let ipv4Addresses = routePrefixes(options.getInet4Address())
        if !ipv4Addresses.isEmpty {
            let ipv4 = NEIPv4Settings(
                addresses: ipv4Addresses.map { $0.address() },
                subnetMasks: ipv4Addresses.map { $0.mask() }
            )
            let included = ipv4Routes(options.getInet4RouteAddress())
            ipv4.includedRoutes = included.isEmpty && options.getAutoRoute() ? [NEIPv4Route.default()] : included
            ipv4.excludedRoutes = ipv4Routes(options.getInet4RouteExcludeAddress())
                + routeExclusionAddresses.compactMap { address in
                    guard address.contains(".") else { return nil }
                    return NEIPv4Route(destinationAddress: address, subnetMask: "255.255.255.255")
                }
            settings.ipv4Settings = ipv4
        }

        let ipv6Addresses = routePrefixes(options.getInet6Address())
        if !ipv6Addresses.isEmpty {
            let ipv6 = NEIPv6Settings(
                addresses: ipv6Addresses.map { $0.address() },
                networkPrefixLengths: ipv6Addresses.map { NSNumber(value: $0.prefix()) }
            )
            let included = ipv6Routes(options.getInet6RouteAddress())
            ipv6.includedRoutes = included.isEmpty && options.getAutoRoute() ? [NEIPv6Route.default()] : included
            ipv6.excludedRoutes = ipv6Routes(options.getInet6RouteExcludeAddress())
                + routeExclusionAddresses.compactMap { address in
                    guard address.contains(":") else { return nil }
                    return NEIPv6Route(destinationAddress: address, networkPrefixLength: 128)
                }
            settings.ipv6Settings = ipv6
        }
        return settings
    }

    private func routePrefixes(_ iterator: LibboxRoutePrefixIteratorProtocol?) -> [LibboxRoutePrefix] {
        guard let iterator else { return [] }
        var result: [LibboxRoutePrefix] = []
        while iterator.hasNext() {
            if let prefix = iterator.next() { result.append(prefix) }
        }
        return result
    }

    private func ipv4Routes(_ iterator: LibboxRoutePrefixIteratorProtocol?) -> [NEIPv4Route] {
        routePrefixes(iterator).map {
            NEIPv4Route(destinationAddress: $0.address(), subnetMask: $0.mask())
        }
    }

    private func ipv6Routes(_ iterator: LibboxRoutePrefixIteratorProtocol?) -> [NEIPv6Route] {
        routePrefixes(iterator).map {
            NEIPv6Route(destinationAddress: $0.address(), networkPrefixLength: NSNumber(value: $0.prefix()))
        }
    }
}

private final class NetworkInterfaceIterator: NSObject, LibboxNetworkInterfaceIteratorProtocol {
    private var iterator: IndexingIterator<[LibboxNetworkInterface]>
    private var nextValue: LibboxNetworkInterface?

    init(_ interfaces: [LibboxNetworkInterface]) {
        iterator = interfaces.makeIterator()
    }

    func hasNext() -> Bool {
        nextValue = iterator.next()
        return nextValue != nil
    }

    func next() -> LibboxNetworkInterface? { nextValue }
}

private final class NetworkSettingsCompletion: @unchecked Sendable {
    private let lock = NSLock()
    private let semaphore = DispatchSemaphore(value: 0)
    private var storedError: Error?

    var error: Error? {
        lock.withLock { storedError }
    }

    func finish(_ error: Error?) {
        lock.withLock { storedError = error }
        semaphore.signal()
    }

    func wait(timeout: DispatchTime) -> Bool {
        semaphore.wait(timeout: timeout) == .success
    }
}

private final class PathMonitorReadiness: @unchecked Sendable {
    private let lock = NSLock()
    private let semaphore = DispatchSemaphore(value: 0)
    private var finished = false

    func finish() {
        let shouldSignal = lock.withLock {
            guard !finished else { return false }
            finished = true
            return true
        }
        if shouldSignal { semaphore.signal() }
    }

    func wait(timeout: DispatchTime) -> Bool {
        semaphore.wait(timeout: timeout) == .success
    }
}
#else
#error("RoutevaPacketTunnelSingBox requires Libbox.xcframework")
#endif
