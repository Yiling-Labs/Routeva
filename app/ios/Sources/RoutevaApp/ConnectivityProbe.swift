import Darwin
import Foundation
import Network
import Security
import SharedKit

enum ConnectivityProbeError: Error, Equatable, Sendable {
    case invalidResponse
    case unexpectedBody
    case responseTooLarge
    /// The forced-tunnel HTTPS probe could not complete a TCP/TLS/HTTP
    /// exchange even with the tunnel source address bound.
    case tunnelTransportFailed
    /// Every resolved address of both probe endpoints collides with a node
    /// excluded route (CDN-fronted node sharing anycast IPs): a bound tunnel
    /// connection to those addresses is unroutable by construction.
    case endpointRouteExcluded
}

struct ConnectivityProbe: Sendable {
    struct Endpoint: Sendable {
        let url: URL
        let expectedBody: String
    }

    static let expectedBody = "routeva-probe-v1"
    static let endpoints = [
        Endpoint(
            url: URL(string: "https://routeva.yilinglabs.com/probe.txt")!,
            expectedBody: expectedBody
        ),
        Endpoint(
            url: URL(string: "https://raw.githubusercontent.com/Yiling-Labs/Routeva/main/website/public/probe.txt")!,
            expectedBody: expectedBody
        ),
    ]

    /// The fixed IPv4 address of the sing-box TUN inbound
    /// (`CoreConfigurationCompiler` tun `address[0]`). Binding this source
    /// address makes the kernel deterministically route the connection into
    /// the tunnel, independent of default-path choices such as Happy
    /// Eyeballs preferring a physical IPv6 route.
    static let tunnelSourceIPv4 = "172.19.0.1"

    static func stableErrorCode(for error: Error) -> String {
        switch error as? ConnectivityProbeError {
        case .invalidResponse: "probe.invalid_response"
        case .unexpectedBody: "probe.body_mismatch"
        case .responseTooLarge: "probe.response_too_large"
        case .tunnelTransportFailed: "probe.tunnel_transport_failed"
        case .endpointRouteExcluded: "probe.endpoint_route_excluded"
        case nil: "probe.transport_failed"
        }
    }

    /// The probe always binds the tunnel source address: the container app's
    /// default path is free to bypass the VPN (Happy Eyeballs may prefer a
    /// physical IPv6 route, and excluded routes for the node endpoint can
    /// collide with CDN-fronted probe endpoints), so only a source-address
    /// binding measures the tunnel and proxy chain deterministically.
    ///
    /// `excludedRouteAddresses` are the node's direct routes: a probe address
    /// colliding with one is unroutable for a tunnel-bound connection, so
    /// colliding candidates are filtered out before connecting.
    func run(excludedRouteAddresses: [String] = []) async throws {
        // setTunnelNetworkSettings returning does not mean the routes are
        // installed yet; a bound source address fails instantly
        // (EADDRNOTAVAIL) while the utun route is still being programmed.
        try? await Task.sleep(for: .milliseconds(400))
        try await runForcedTunnel(excludedRouteAddresses: excludedRouteAddresses)
    }

    private func runForcedTunnel(excludedRouteAddresses: [String]) async throws {
        var sawFullCollision = false
        for attempt in 0..<2 {
            let started = ContinuousClock.now
            var lastError: Error = ConnectivityProbeError.tunnelTransportFailed
            for endpoint in Self.endpoints {
                do {
                    try await runForcedTunnel(
                        endpoint,
                        excludedRouteAddresses: excludedRouteAddresses
                    )
                    return
                } catch ConnectivityProbeError.endpointRouteExcluded {
                    sawFullCollision = true
                    lastError = ConnectivityProbeError.endpointRouteExcluded
                } catch {
                    lastError = error
                }
            }
            // A round that fails within seconds points at the tunnel route
            // not being installed yet rather than a dead proxy chain; give
            // the system one more grace period before concluding. A full
            // exclusion collision is deterministic, so retrying is pointless.
            guard attempt == 0, !sawFullCollision,
                  ContinuousClock.now - started < .seconds(4) else {
                throw lastError
            }
            try? await Task.sleep(for: .milliseconds(600))
        }
        throw sawFullCollision
            ? ConnectivityProbeError.endpointRouteExcluded
            : ConnectivityProbeError.tunnelTransportFailed
    }

    private func runForcedTunnel(
        _ endpoint: Endpoint,
        excludedRouteAddresses: [String]
    ) async throws {
        guard let host = endpoint.url.host else {
            throw ConnectivityProbeError.tunnelTransportFailed
        }
        // Resolve through the system resolver (unbound source address) so the
        // DNS exchange itself enters the tunnel as a measurable milestone; an
        // NWConnection with a bound local endpoint may never run a lookup.
        let addresses = try await Self.resolveIPv4Addresses(host: host)
        guard !addresses.isEmpty else { throw ConnectivityProbeError.tunnelTransportFailed }
        let usable = addresses.filter {
            !DirectRouteAddressValidator.containsExcludedMatch(
                excludedRoutes: excludedRouteAddresses,
                resolvedAddresses: [$0]
            )
        }
        guard !usable.isEmpty else { throw ConnectivityProbeError.endpointRouteExcluded }
        var lastError: Error = ConnectivityProbeError.tunnelTransportFailed
        for address in usable.prefix(2) {
            do {
                let body = try await TunnelHTTP.get(
                    address: address,
                    serverName: host,
                    path: endpoint.url.path.isEmpty ? "/" : endpoint.url.path,
                    tunnelSourceAddress: Self.tunnelSourceIPv4,
                    maximumResponseBytes: 8_192,
                    timeout: .seconds(8)
                )
                guard body.count <= 64 else { throw ConnectivityProbeError.responseTooLarge }
                guard String(decoding: body, as: UTF8.self)
                    .trimmingCharacters(in: .whitespacesAndNewlines) == endpoint.expectedBody
                else { throw ConnectivityProbeError.unexpectedBody }
                return
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    /// System-resolver A lookup for the probe host. Runs inside the container
    /// app without any binding; the resulting queries follow the tunnel's
    /// default route like any other app DNS traffic.
    private static func resolveIPv4Addresses(host: String) async throws -> [String] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var hints = addrinfo()
                hints.ai_family = AF_INET
                hints.ai_socktype = SOCK_STREAM
                var list: UnsafeMutablePointer<addrinfo>?
                let status = getaddrinfo(host, "443", &hints, &list)
                defer { freeaddrinfo(list) }
                guard status == 0, let list else {
                    continuation.resume(throwing: ConnectivityProbeError.tunnelTransportFailed)
                    return
                }
                var addresses: [String] = []
                var cursor: UnsafeMutablePointer<addrinfo>? = list
                while let info = cursor {
                    if info.pointee.ai_family == AF_INET,
                       let socketAddress = info.pointee.ai_addr {
                        var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                        var copy = socketAddress.withMemoryRebound(
                            to: sockaddr_in.self,
                            capacity: 1
                        ) { $0.pointee }
                        if inet_ntop(AF_INET, &copy.sin_addr, &buffer, socklen_t(INET_ADDRSTRLEN)) != nil {
                            addresses.append(String(
                                decoding: buffer.prefix(while: { $0 != 0 }).map(UInt8.init(bitPattern:)),
                                as: UTF8.self
                            ))
                        }
                    }
                    cursor = info.pointee.ai_next
                }
                continuation.resume(returning: addresses)
            }
        }
    }
}

/// Minimal HTTPS GET over `NWConnection` with the tunnel source address
/// bound, forcing the connection into the Packet Tunnel. Uses HTTP/1.0
/// semantics (no chunked transfer coding) and validates only the 2xx status
/// line; the returned body is the close-delimited remainder. The peer is a
/// pre-resolved IP literal; TLS SNI and hostname verification keep using the
/// original host name.
private enum TunnelHTTP {
    static func get(
        address: String,
        serverName: String,
        path: String,
        tunnelSourceAddress: String,
        maximumResponseBytes: Int,
        timeout: Duration
    ) async throws -> Data {
        try await withThrowingTaskGroup(of: Data.self) { group in
            group.addTask {
                try await performGet(
                    address: address,
                    serverName: serverName,
                    path: path,
                    tunnelSourceAddress: tunnelSourceAddress,
                    maximumResponseBytes: maximumResponseBytes
                )
            }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw ConnectivityProbeError.tunnelTransportFailed
            }
            do {
                guard let result = try await group.next() else {
                    throw ConnectivityProbeError.tunnelTransportFailed
                }
                group.cancelAll()
                return result
            } catch {
                group.cancelAll()
                throw error
            }
        }
    }

    private static func performGet(
        address: String,
        serverName: String,
        path: String,
        tunnelSourceAddress: String,
        maximumResponseBytes: Int
    ) async throws -> Data {
        let tlsOptions = NWProtocolTLS.Options()
        sec_protocol_options_set_tls_server_name(
            tlsOptions.securityProtocolOptions,
            serverName
        )
        let parameters = NWParameters(tls: tlsOptions, tcp: NWProtocolTCP.Options())
        // requiredLocalEndpoint binds the source address directly (available
        // since iOS 12); the iOS 26 `localEndpoint(_:)` builder returns a new
        // parameters value, so discarding its result silently dropped the
        // binding and every previous "forced tunnel" probe actually ran
        // unbound on the default path.
        parameters.requiredLocalEndpoint = .hostPort(
            host: NWEndpoint.Host(tunnelSourceAddress),
            port: .any
        )
        let connection = NWConnection(
            host: NWEndpoint.Host(address),
            port: 443,
            using: parameters
        )
        let box = ExchangeBox(maximumResponseBytes: maximumResponseBytes)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                box.attach(continuation)
                connection.stateUpdateHandler = { state in
                    switch state {
                    case .ready:
                        let request = Data(
                            "GET \(path) HTTP/1.0\r\nHost: \(serverName)\r\nAccept: text/plain\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n".utf8
                        )
                        connection.send(
                            content: request,
                            completion: .contentProcessed { error in
                                if let error {
                                    #if DEBUG
                                    print("Routeva probe send failed for \(serverName): \(error)")
                                    #endif
                                    box.finish(.failure(ConnectivityProbeError.tunnelTransportFailed))
                                }
                            }
                        )
                        receiveNext(on: connection, box: box)
                    case .failed(let error):
                        #if DEBUG
                        print("Routeva probe connection failed for \(serverName) via \(address): \(error)")
                        #endif
                        box.finish(.failure(ConnectivityProbeError.tunnelTransportFailed))
                    case .waiting(let error):
                        #if DEBUG
                        print("Routeva probe connection waiting for \(serverName) via \(address): \(error)")
                        #endif
                        break
                    default:
                        // .preparing: the surrounding timeout bounds it.
                        break
                    }
                }
                connection.start(queue: DispatchQueue(label: "com.yilinglabs.routeva.probe.tunnel"))
            }
        } onCancel: {
            connection.cancel()
            box.finish(.failure(CancellationError()))
        }
    }

    private static func receiveNext(on connection: NWConnection, box: ExchangeBox) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16_384) { content, _, isComplete, error in
            if let error {
                #if DEBUG
                print("Routeva probe receive failed: \(error)")
                #endif
                box.finish(.failure(ConnectivityProbeError.tunnelTransportFailed))
                return
            }
            if let content {
                guard box.append(content) else {
                    box.finish(.failure(ConnectivityProbeError.invalidResponse))
                    return
                }
            }
            if isComplete {
                box.finish(parseResponse(box.received))
                return
            }
            receiveNext(on: connection, box: box)
        }
    }

    private static func parseResponse(_ data: Data) -> Result<Data, Error> {
        let separator = Data([13, 10, 13, 10])
        guard let headerRange = data.range(of: separator) else {
            return .failure(ConnectivityProbeError.invalidResponse)
        }
        let header = data[..<headerRange.lowerBound]
        guard let lineEnd = header.firstIndex(of: 13) else {
            return .failure(ConnectivityProbeError.invalidResponse)
        }
        let statusLine = String(decoding: header[..<lineEnd], as: UTF8.self)
        let parts = statusLine.split(separator: " ")
        guard parts.count >= 2, let status = Int(parts[1]) else {
            return .failure(ConnectivityProbeError.invalidResponse)
        }
        guard (200...299).contains(status) else {
            return .failure(ConnectivityProbeError.invalidResponse)
        }
        return .success(Data(data[headerRange.upperBound...]))
    }

    /// Serializes the continuation resume and accumulates the response. All
    /// callbacks run on the connection's serial queue; the lock additionally
    /// protects the cancellation handler running on another thread.
    private final class ExchangeBox: @unchecked Sendable {
        private let lock = NSLock()
        private var continuation: CheckedContinuation<Data, Error>?
        private var resumed = false
        private var storage = Data()
        private let maximumResponseBytes: Int

        init(maximumResponseBytes: Int) {
            self.maximumResponseBytes = maximumResponseBytes
        }

        var received: Data { lock.withLock { storage } }

        func attach(_ continuation: CheckedContinuation<Data, Error>) {
            lock.withLock { self.continuation = continuation }
        }

        /// Appends a chunk; returns false when the response exceeds the
        /// transport ceiling (not the application body limit).
        func append(_ chunk: Data) -> Bool {
            lock.withLock {
                guard storage.count + chunk.count <= maximumResponseBytes else { return false }
                storage.append(chunk)
                return true
            }
        }

        func finish(_ result: Result<Data, Error>) {
            let continuation: CheckedContinuation<Data, Error>? = lock.withLock {
                guard !resumed else { return nil }
                resumed = true
                defer { self.continuation = nil }
                return self.continuation
            }
            continuation?.resume(with: result)
        }
    }
}
