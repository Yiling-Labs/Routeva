import Darwin
import DataKit
import Foundation
import Network
import NetworkExtension
import Security
import SharedKit

final class PacketTunnelProvider: NEPacketTunnelProvider, @unchecked Sendable {
    private let configurationLoader: any RuntimeConfigurationLoading = KeychainRuntimeConfigurationLoader()
    private let runtime = SingBoxRuntime()
    private let runtimeState = ProviderRuntimeStateStore()
    private let startupDiagnostics = ProviderStartupDiagnosticStore()
    private let nodeDatabase = try? RoutevaDatabase.openAppGroupDatabase()
    private var platform: SingBoxPlatformInterface?

    override func startTunnel(
        options: [String: NSObject]? = nil,
        completionHandler: @escaping @Sendable (Error?) -> Void
    ) {
        let manifestID: UUID?
        do {
            manifestID = try ProviderStartOption.decodeManifestID(from: options)
        } catch {
            startupDiagnostics.record(
                core: .singBox,
                stage: .receivedRequest,
                stableErrorCode: stableProviderStartupErrorCode(error)
            )
            completionHandler(error)
            return
        }
        startupDiagnostics.record(core: .singBox, stage: .receivedRequest)
        Task { [configurationLoader, runtime, runtimeState, startupDiagnostics, weak self, manifestID] in
            do {
                guard let self else { throw PacketTunnelRuntimeError.tunnelFileDescriptorUnavailable }
                runtimeState.beginSession()
                startupDiagnostics.record(core: .singBox, stage: .loadingConfiguration)
                let configuration = try await configurationLoader.load(manifestID: manifestID, for: .singBox)
                if let pinned = configuration.manifest.corePolicy.pinnedCore, pinned != .singBox {
                    throw PacketTunnelRuntimeError.selectedCoreMismatch(expected: .singBox, actual: pinned)
                }
                let platform = SingBoxPlatformInterface(
                    tunnel: self,
                    runtimeState: runtimeState,
                    directRouteAddresses: configuration.manifest.directRouteAddresses,
                    onBridgeStarting: {
                        startupDiagnostics.record(core: .singBox, stage: .startingPacketBridge)
                    },
                    onBridgeFailure: { [weak self] error in
                        runtimeState.setStatus(.failed)
                        let stage = startupDiagnostics.snapshot()?.stage ?? .startingPacketBridge
                        startupDiagnostics.record(
                            core: .singBox,
                            stage: stage,
                            stableErrorCode: stableProviderStartupErrorCode(error)
                        )
                        self?.cancelTunnelWithError(error)
                    }
                )
                self.platform = platform
                runtimeState.setStatus(.starting)
                startupDiagnostics.record(core: .singBox, stage: .startingCore)
                try runtime.start(
                    json: configuration.json,
                    platform: platform,
                    initialNodeID: configuration.manifest.profile.id,
                    availableNodeIDs: Set(configuration.manifest.profiles.map(\.id)),
                    onFailure: { stage, stableCode in
                        startupDiagnostics.record(
                            core: .singBox,
                            stage: stage,
                            stableErrorCode: stableCode
                        )
                    },
                    onStage: { stage in
                        startupDiagnostics.record(core: .singBox, stage: stage)
                    }
                )
                runtimeState.setStatus(.running)
                startupDiagnostics.record(core: .singBox, stage: .running)
                completionHandler(nil)
            } catch {
                runtime.stop()
                self?.platform?.stopPacketBridge()
                self?.platform = nil
                runtimeState.setStatus(.failed)
                let stage = startupDiagnostics.snapshot()?.stage ?? .receivedRequest
                startupDiagnostics.record(
                    core: .singBox,
                    stage: stage,
                    stableErrorCode: stableProviderStartupErrorCode(error)
                )
                completionHandler(error)
            }
        }
    }

    override func stopTunnel(
        with reason: NEProviderStopReason,
        completionHandler: @escaping @Sendable () -> Void
    ) {
        let stopStartedAt = ProcessInfo.processInfo.systemUptime
        startupDiagnostics.record(core: .singBox, stage: .stopping)
        runtimeState.setStatus(.stopping)
        // Detach PacketFlow first so the tunnel stops carrying traffic as
        // soon as NetworkExtension delivers the stop request. Libbox cleanup
        // may take longer, but it must not extend the live data-plane window.
        platform?.stopPacketBridge()
        let dataPlaneStoppedAt = ProcessInfo.processInfo.systemUptime
        runtime.stop()
        platform = nil
        runtimeState.setStatus(.idle)
        #if DEBUG
        let cleanupFinishedAt = ProcessInfo.processInfo.systemUptime
        print(String(
            format: "Routeva VPN provider stop timing: dataPlane=%.3fs cleanup=%.3fs",
            dataPlaneStoppedAt - stopStartedAt,
            cleanupFinishedAt - dataPlaneStoppedAt
        ))
        #endif
        completionHandler()
    }

    override func handleAppMessage(
        _ messageData: Data,
        completionHandler: ((Data?) -> Void)? = nil
    ) {
        guard let completionHandler else { return }
        guard let request = try? ProviderMessageCodec.decodeRequest(messageData) else {
            completionHandler(nil)
            return
        }
        guard [
            .coreProbe,
            .selectNode,
            .selectedNode,
            .reloadConfiguration,
            .finalizeConfigurationReload,
            .entryLatency,
        ].contains(request.kind) else {
            completionHandler(runtimeState.response(to: messageData))
            return
        }

        let completion = ProviderMessageCompletion(completionHandler)
        Task { [configurationLoader, runtime, runtimeState, request, completion, weak self] in
            let response: ProviderMessageResponse
            var catastrophicError: SingBoxNodeSelectionError?
            do {
                if request.kind == .finalizeConfigurationReload {
                    guard let expectedNodeID = request.nodeID,
                          let accept = request.acceptConfigurationReload
                    else {
                        throw SingBoxNodeSelectionError.configurationReloadRejected
                    }
                    response = ProviderMessageResponse(
                        requestID: request.requestID,
                        selectedNodeID: try runtime.finalizeConfigurationReload(
                            expectedNodeID: expectedNodeID,
                            accept: accept
                        )
                    )
                } else if request.kind == .reloadConfiguration {
                    guard let manifestID = request.manifestID else {
                        throw SingBoxNodeSelectionError.configurationReloadRejected
                    }
                    let configuration = try await configurationLoader.load(
                        manifestID: manifestID,
                        for: .singBox
                    )
                    if let pinned = configuration.manifest.corePolicy.pinnedCore,
                       pinned != .singBox {
                        throw PacketTunnelRuntimeError.selectedCoreMismatch(
                            expected: .singBox,
                            actual: pinned
                        )
                    }
                    response = ProviderMessageResponse(
                        requestID: request.requestID,
                        selectedNodeID: try runtime.reloadConfiguration(
                            json: configuration.json,
                            initialNodeID: configuration.manifest.profile.id,
                            availableNodeIDs: Set(configuration.manifest.profiles.map(\.id)),
                            directRouteAddresses:
                                configuration.manifest.directRouteAddresses
                        )
                    )
                } else if request.kind == .selectNode {
                    guard let nodeID = request.nodeID else {
                        throw SingBoxNodeSelectionError.nodeNotInRuntimeCatalog
                    }
                    response = ProviderMessageResponse(
                        requestID: request.requestID,
                        selectedNodeID: try runtime.selectNode(nodeID)
                    )
                } else if request.kind == .selectedNode {
                    response = ProviderMessageResponse(
                        requestID: request.requestID,
                        selectedNodeID: try runtime.currentSelectedNode()
                    )
                } else if request.kind == .entryLatency {
                    guard let self else {
                        throw EntryLatencyProbeError.physicalPathUnavailable
                    }
                    guard let nodeIDs = request.entryLatencyNodeIDs, !nodeIDs.isEmpty else {
                        throw EntryLatencyProbeError.physicalPathUnavailable
                    }
                    response = ProviderMessageResponse(
                        requestID: request.requestID,
                        entryLatencies: try await self.measureEntryLatencies(nodeIDs: nodeIDs)
                    )
                } else if #available(iOS 18.0, *),
                          let addressSets = request.tunnelProbeAddressSets,
                          !addressSets.isEmpty {
                    guard let self else {
                        throw SingBoxTunnelInterfaceProbeError.interfaceUnavailable
                    }
                    // The virtual-interface exchange is authoritative: it
                    // traverses PacketFlow, gVisor, the selected proxy, TLS,
                    // and HTTP. Libbox URLTest uses the outbound dialer
                    // directly and may fail on its independent DNS path even
                    // while real tunneled traffic is healthy. Keep URLTest as
                    // best-effort telemetry without blocking Connected.
                    try await SingBoxTunnelInterfaceProbe.run(
                        provider: self,
                        addressSets: addressSets
                    )
                    Task.detached(priority: .utility) {
                        _ = try? runtime.probe()
                    }
                    response = ProviderMessageResponse(
                        requestID: request.requestID,
                        tunnelProbeSucceeded: true
                    )
                } else {
                    response = ProviderMessageResponse(
                        requestID: request.requestID,
                        coreProbe: try runtime.probe()
                    )
                }
            } catch let error as SingBoxCoreProbeError {
                response = ProviderMessageResponse(
                    requestID: request.requestID,
                    errorCode: error.stableCode
                )
            } catch let error as SingBoxNodeSelectionError {
                if error.requiresTunnelCancellation {
                    catastrophicError = error
                }
                response = ProviderMessageResponse(
                    requestID: request.requestID,
                    errorCode: error.stableCode
                )
            } catch let error as SingBoxTunnelInterfaceProbeError {
                response = ProviderMessageResponse(
                    requestID: request.requestID,
                    errorCode: error.stableCode
                )
            } catch let error as EntryLatencyProbeError {
                response = ProviderMessageResponse(
                    requestID: request.requestID,
                    errorCode: error.stableCode
                )
            } catch {
                response = ProviderMessageResponse(
                    requestID: request.requestID,
                    errorCode: [
                        .reloadConfiguration,
                        .finalizeConfigurationReload,
                    ].contains(request.kind)
                        ? stableProviderStartupErrorCode(error)
                        : SingBoxCoreProbeError.failed.stableCode
                )
            }
            completion.call(try? ProviderMessageCodec.encode(response))
            if let catastrophicError {
                runtimeState.setStatus(.failed)
                self?.cancelTunnelWithError(PacketTunnelRuntimeError.coreFailure(
                    catastrophicError.stableCode
                ))
            }
        }
    }

    private func measureEntryLatencies(
        nodeIDs: [UUID]
    ) async throws -> [ProviderEntryLatencySample] {
        guard let interface = await resolvePhysicalInterface() else {
            throw EntryLatencyProbeError.physicalPathUnavailable
        }
        guard let database = nodeDatabase else {
            throw EntryLatencyProbeError.physicalPathUnavailable
        }
        let limited = Array(nodeIDs.prefix(ProviderEntryLatencyCode.maximumBatchCount))
        return try await withThrowingTaskGroup(
            of: ProviderEntryLatencySample.self
        ) { group in
            for nodeID in limited {
                group.addTask {
                    guard let record = try? await database.node(id: nodeID) else {
                        return ProviderEntryLatencySample(nodeID: nodeID, milliseconds: nil)
                    }
                    guard record.protocolKind != .hysteria2 else {
                        return ProviderEntryLatencySample(nodeID: nodeID, milliseconds: nil)
                    }
                    let result = await NodeLatencyProbe.measure(
                        host: record.endpointHost,
                        port: record.endpointPort,
                        timeout: 2,
                        requiredInterface: interface
                    )
                    switch result {
                    case let .measured(milliseconds):
                        return ProviderEntryLatencySample(
                            nodeID: nodeID,
                            milliseconds: UInt32(clamping: milliseconds)
                        )
                    case .timeout:
                        return ProviderEntryLatencySample(nodeID: nodeID, milliseconds: nil)
                    case .pathUnavailable:
                        throw EntryLatencyProbeError.physicalPathUnavailable
                    }
                }
            }
            var samples: [ProviderEntryLatencySample] = []
            samples.reserveCapacity(limited.count)
            for try await sample in group {
                samples.append(sample)
            }
            return samples
        }
    }

    private func resolvePhysicalInterface() async -> NWInterface? {
        let excludedName: String?
        if #available(iOS 18.0, *) {
            excludedName = virtualInterface?.name
        } else {
            excludedName = nil
        }
        let monitor = NWPathMonitor()
        return await withCheckedContinuation { continuation in
            let box = PathOnce(continuation: continuation)
            monitor.pathUpdateHandler = { path in
                monitor.cancel()
                box.finish(
                    PhysicalNetworkInterface.preferred(
                        from: path,
                        excludingName: excludedName
                    )
                )
            }
            monitor.start(queue: DispatchQueue(label: "com.yilinglabs.routeva.entry-latency.path"))
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2) {
                monitor.cancel()
                box.finish(nil)
            }
        }
    }
}

private final class PathOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<NWInterface?, Never>?

    init(continuation: CheckedContinuation<NWInterface?, Never>) {
        self.continuation = continuation
    }

    func finish(_ value: NWInterface?) {
        lock.lock()
        guard let continuation else {
            lock.unlock()
            return
        }
        self.continuation = nil
        lock.unlock()
        continuation.resume(returning: value)
    }
}

private enum EntryLatencyProbeError: Error, Equatable, Sendable {
    case physicalPathUnavailable

    var stableCode: String {
        ProviderEntryLatencyCode.physicalPathUnavailable
    }
}

private enum SingBoxTunnelInterfaceProbeError: Error, Equatable, Sendable {
    case interfaceUnavailable
    case addressUnavailable
    case transportFailed
    case invalidResponse
    case unexpectedBody
    case responseTooLarge

    var stableCode: String {
        switch self {
        case .interfaceUnavailable: "probe.tunnel_interface_unavailable"
        case .addressUnavailable: "probe.tunnel_probe_address_unavailable"
        case .transportFailed: "probe.tunnel_http_failed"
        case .invalidResponse: "probe.tunnel_http_invalid_response"
        case .unexpectedBody: "probe.tunnel_http_body_mismatch"
        case .responseTooLarge: "probe.tunnel_http_response_too_large"
        }
    }
}

@available(iOS 18.0, *)
private enum SingBoxTunnelInterfaceProbe {
    private struct Endpoint: Sendable {
        let host: String
        let path: String
        let expectedStatusCode: Int
    }

    private enum AttemptResult: Sendable {
        case success
        case failure(SingBoxTunnelInterfaceProbeError)
        case timeout
    }

    // Do not couple the runtime Gate to Routeva's marketing-site deployment:
    // Pages may legitimately use an SPA fallback, which previously returned a
    // 200 HTML page for /probe.txt and made every healthy tunnel look broken.
    // Two independent 204 endpoints keep the Gate available even when one DNS
    // or CDN path is unavailable. Google is first to reduce collision risk
    // with Cloudflare-fronted proxy nodes; attempts run concurrently. Resolve
    // A records explicitly and keep SNI/Host on the original name: a proxy
    // node without IPv6 egress must not make a healthy IPv4 tunnel fail its
    // startup Gate before Network.framework gets around to family fallback.
    private static let endpoints = [
        Endpoint(host: "www.gstatic.com", path: "/generate_204", expectedStatusCode: 204),
        Endpoint(host: "cp.cloudflare.com", path: "/generate_204", expectedStatusCode: 204),
    ]
    private static let maximumResponseHeadBytes = 32 * 1_024

    static func run(
        provider: NEPacketTunnelProvider,
        addressSets: [ProviderTunnelProbeAddressSet]
    ) async throws {
        guard let interface = provider.virtualInterface else {
            throw SingBoxTunnelInterfaceProbeError.interfaceUnavailable
        }

        try await withThrowingTaskGroup(of: AttemptResult.self) { group in
            for endpoint in endpoints {
                group.addTask {
                    var mostSpecificError = SingBoxTunnelInterfaceProbeError.transportFailed
                    let addresses = validatedIPv4Addresses(
                        host: endpoint.host,
                        addressSets: addressSets
                    )
                    guard !addresses.isEmpty else {
                        return .failure(.addressUnavailable)
                    }
                    for address in addresses.prefix(2) {
                        do {
                            let statusCode = try await performGet(
                                endpoint: endpoint,
                                address: address,
                                requiredInterface: interface
                            )
                            guard statusCode == endpoint.expectedStatusCode else {
                                mostSpecificError = .invalidResponse
                                continue
                            }
                            return .success
                        } catch let error as SingBoxTunnelInterfaceProbeError {
                            if error != .transportFailed {
                                mostSpecificError = error
                            }
                        } catch {
                            continue
                        }
                    }
                    return .failure(mostSpecificError)
                }
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(12))
                return .timeout
            }

            var remainingAttempts = endpoints.count
            var mostSpecificError = SingBoxTunnelInterfaceProbeError.transportFailed
            while let result = try await group.next() {
                switch result {
                case .success:
                    group.cancelAll()
                    return
                case let .failure(error):
                    remainingAttempts -= 1
                    if error != .transportFailed {
                        mostSpecificError = error
                    }
                    if remainingAttempts == 0 {
                        group.cancelAll()
                        throw mostSpecificError
                    }
                case .timeout:
                    group.cancelAll()
                    throw SingBoxTunnelInterfaceProbeError.transportFailed
                }
            }
            throw SingBoxTunnelInterfaceProbeError.transportFailed
        }
    }

    private static func performGet(
        endpoint: Endpoint,
        address: String,
        requiredInterface: NWInterface
    ) async throws -> Int {
        let tlsOptions = NWProtocolTLS.Options()
        sec_protocol_options_set_tls_server_name(
            tlsOptions.securityProtocolOptions,
            endpoint.host
        )
        let parameters = NWParameters(tls: tlsOptions, tcp: NWProtocolTCP.Options())
        parameters.requiredInterface = requiredInterface
        let connection = NWConnection(
            host: NWEndpoint.Host(address),
            port: 443,
            using: parameters
        )
        let exchange = TunnelProbeExchange(
            maximumResponseHeadBytes: maximumResponseHeadBytes
        )

        return try await withTaskCancellationHandler {
            defer { connection.cancel() }
            return try await withCheckedThrowingContinuation { continuation in
                exchange.attach(continuation)
                connection.stateUpdateHandler = { state in
                    switch state {
                    case .ready:
                        let request = Data(
                            "GET \(endpoint.path) HTTP/1.0\r\n"
                                .appending("Host: \(endpoint.host)\r\n")
                                .appending("Accept: */*\r\n")
                                .appending("Accept-Encoding: identity\r\n")
                                .appending("Cache-Control: no-store\r\n")
                                .appending("Connection: close\r\n\r\n")
                                .utf8
                        )
                        connection.send(
                            content: request,
                            completion: .contentProcessed { error in
                                if error != nil {
                                    exchange.finish(.failure(
                                        SingBoxTunnelInterfaceProbeError.transportFailed
                                    ))
                                }
                            }
                        )
                        receiveNext(on: connection, exchange: exchange)
                    case .failed, .cancelled:
                        exchange.finish(.failure(
                            SingBoxTunnelInterfaceProbeError.transportFailed
                        ))
                    default:
                        break
                    }
                }
                connection.start(
                    queue: DispatchQueue(label: "com.yilinglabs.routeva.probe.virtual-interface")
                )
            }
        } onCancel: {
            connection.cancel()
            exchange.finish(.failure(CancellationError()))
        }
    }

    private static func validatedIPv4Addresses(
        host: String,
        addressSets: [ProviderTunnelProbeAddressSet]
    ) -> [String] {
        guard let addressSet = addressSets.first(where: {
            $0.host.caseInsensitiveCompare(host) == .orderedSame
        }) else { return [] }
        var result: [String] = []
        for address in addressSet.ipv4Addresses.prefix(4) {
            var binary = in_addr()
            guard inet_pton(AF_INET, address, &binary) == 1,
                  !result.contains(address)
            else { continue }
            result.append(address)
        }
        return result
    }

    private static func receiveNext(
        on connection: NWConnection,
        exchange: TunnelProbeExchange
    ) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16_384) {
            content,
            _,
            isComplete,
            error in
            if let content, !exchange.append(content) {
                exchange.finish(.failure(SingBoxTunnelInterfaceProbeError.responseTooLarge))
                return
            }

            // Parse the response head before looking at a simultaneous reset.
            // A valid 204 is complete at CRLFCRLF and has no message body; a
            // later RST/FIN is transport cleanup, not a failed connectivity Gate.
            switch ProviderHTTPResponseHeadParser.parse(exchange.received) {
            case let .complete(statusCode):
                exchange.finish(.success(statusCode))
                return
            case .invalid:
                exchange.finish(.failure(SingBoxTunnelInterfaceProbeError.invalidResponse))
                return
            case .incomplete:
                break
            }
            if error != nil {
                exchange.finish(.failure(SingBoxTunnelInterfaceProbeError.transportFailed))
                return
            }
            if isComplete {
                exchange.finish(.failure(SingBoxTunnelInterfaceProbeError.invalidResponse))
                return
            }
            receiveNext(on: connection, exchange: exchange)
        }
    }

    private final class TunnelProbeExchange: @unchecked Sendable {
        private let lock = NSLock()
        private let maximumResponseHeadBytes: Int
        private var continuation: CheckedContinuation<Int, Error>?
        private var resumed = false
        private var storage = Data()

        init(maximumResponseHeadBytes: Int) {
            self.maximumResponseHeadBytes = maximumResponseHeadBytes
        }

        var received: Data { lock.withLock { storage } }

        func attach(_ continuation: CheckedContinuation<Int, Error>) {
            lock.withLock { self.continuation = continuation }
        }

        func append(_ data: Data) -> Bool {
            lock.withLock {
                guard storage.count + data.count <= maximumResponseHeadBytes else { return false }
                storage.append(data)
                return true
            }
        }

        func finish(_ result: Result<Int, Error>) {
            let continuation: CheckedContinuation<Int, Error>? = lock.withLock {
                guard !resumed else { return nil }
                resumed = true
                defer { self.continuation = nil }
                return self.continuation
            }
            continuation?.resume(with: result)
        }
    }
}

private final class ProviderMessageCompletion: @unchecked Sendable {
    private let handler: (Data?) -> Void

    init(_ handler: @escaping (Data?) -> Void) {
        self.handler = handler
    }

    func call(_ data: Data?) {
        handler(data)
    }
}
