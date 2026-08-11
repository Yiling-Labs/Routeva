import Darwin
import Foundation
import SharedKit
import dnssd

struct DomainRouteResolver: Sendable {
    func resolve(domains: [String]) async -> [String] {
        let addressSets = await resolveAddressSets(domains: domains)
        return Array(Set(addressSets.values.flatMap { $0 })).sorted()
    }

    func resolveAddressSets(domains: [String]) async -> [String: [String]] {
        await withTaskGroup(
            of: (String, [String]).self,
            returning: [String: [String]].self
        ) { group in
            for domain in Set(domains) {
                group.addTask {
                    (
                        domain,
                        await DNSServiceAddressQuery(
                            protocols: UInt32(kDNSServiceProtocol_IPv4
                                | kDNSServiceProtocol_IPv6),
                            maximumAddressCount: 8
                        ).resolve(domain)
                    )
                }
            }
            var results: [String: [String]] = [:]
            for await (domain, addresses) in group {
                results[domain] = addresses
            }
            return results
        }
    }

    func resolveIPv4AddressSets(domains: [String]) async -> [ProviderTunnelProbeAddressSet] {
        await withTaskGroup(
            of: ProviderTunnelProbeAddressSet.self,
            returning: [ProviderTunnelProbeAddressSet].self
        ) { group in
            for domain in Set(domains) {
                group.addTask {
                    ProviderTunnelProbeAddressSet(
                        host: domain,
                        ipv4Addresses: await DNSServiceAddressQuery(
                            protocols: UInt32(kDNSServiceProtocol_IPv4),
                            maximumAddressCount: 2
                        ).resolve(domain)
                    )
                }
            }
            var results: [ProviderTunnelProbeAddressSet] = []
            for await result in group where !result.ipv4Addresses.isEmpty {
                results.append(result)
            }
            return results.sorted { $0.host < $1.host }
        }
    }
}

private final class DNSServiceAddressQuery: @unchecked Sendable {
    private let queue = DispatchQueue(
        label: "com.yilinglabs.routeva.preflight-dns.\(UUID().uuidString)"
    )
    private let protocols: UInt32
    private let maximumAddressCount: Int
    private let timeout: TimeInterval
    private var serviceRef: DNSServiceRef?
    private var continuation: CheckedContinuation<[String], Never>?
    private var addresses: Set<String> = []

    init(
        protocols: UInt32,
        maximumAddressCount: Int,
        timeout: TimeInterval = 2.5
    ) {
        self.protocols = protocols
        self.maximumAddressCount = maximumAddressCount
        self.timeout = timeout
    }

    func resolve(_ host: String) async -> [String] {
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                queue.async { [self] in start(host: host, continuation: continuation) }
            }
        } onCancel: {
            self.queue.async { [self] in finish() }
        }
    }

    private func start(
        host: String,
        continuation: CheckedContinuation<[String], Never>
    ) {
        guard self.continuation == nil else {
            continuation.resume(returning: [])
            return
        }
        self.continuation = continuation
        var reference: DNSServiceRef?
        let result = host.withCString { hostname in
            DNSServiceGetAddrInfo(
                &reference,
                kDNSServiceFlagsTimeout,
                UInt32(kDNSServiceInterfaceIndexAny),
                protocols,
                hostname,
                routevaDNSServiceAddressCallback,
                Unmanaged.passUnretained(self).toOpaque()
            )
        }
        guard result == kDNSServiceErr_NoError, let reference else {
            finish()
            return
        }
        serviceRef = reference
        guard DNSServiceSetDispatchQueue(reference, queue) == kDNSServiceErr_NoError else {
            finish()
            return
        }
        queue.asyncAfter(deadline: .now() + timeout) { [self] in finish() }
    }

    fileprivate func receive(
        flags: DNSServiceFlags,
        errorCode: DNSServiceErrorType,
        address: UnsafePointer<sockaddr>?
    ) {
        guard errorCode == kDNSServiceErr_NoError, let address else {
            queue.async { [self] in finish() }
            return
        }
        if flags & kDNSServiceFlagsAdd != 0,
           let value = Self.numericAddress(address) {
            addresses.insert(value)
        }
        if addresses.count >= maximumAddressCount
            || flags & kDNSServiceFlagsMoreComing == 0 {
            // Return from the DNS-SD callback before deallocating its service.
            queue.async { [self] in finish() }
        }
    }

    private func finish() {
        guard let continuation else { return }
        self.continuation = nil
        if let serviceRef {
            self.serviceRef = nil
            DNSServiceRefDeallocate(serviceRef)
        }
        continuation.resume(returning: Array(addresses.sorted().prefix(maximumAddressCount)))
    }

    private static func numericAddress(_ address: UnsafePointer<sockaddr>) -> String? {
        guard address.pointee.sa_family == AF_INET
                || address.pointee.sa_family == AF_INET6
        else { return nil }
        var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let length: socklen_t = address.pointee.sa_family == AF_INET
            ? socklen_t(MemoryLayout<sockaddr_in>.size)
            : socklen_t(MemoryLayout<sockaddr_in6>.size)
        guard getnameinfo(
            address,
            length,
            &host,
            socklen_t(host.count),
            nil,
            0,
            NI_NUMERICHOST
        ) == 0 else { return nil }
        let end = host.firstIndex(of: 0) ?? host.endIndex
        return String(
            decoding: host[..<end].map { UInt8(bitPattern: $0) },
            as: UTF8.self
        )
    }
}

private func routevaDNSServiceAddressCallback(
    _ serviceRef: DNSServiceRef?,
    _ flags: DNSServiceFlags,
    _ interfaceIndex: UInt32,
    _ errorCode: DNSServiceErrorType,
    _ hostname: UnsafePointer<CChar>?,
    _ address: UnsafePointer<sockaddr>?,
    _ ttl: UInt32,
    _ context: UnsafeMutableRawPointer?
) {
    guard let context else { return }
    Unmanaged<DNSServiceAddressQuery>
        .fromOpaque(context)
        .takeUnretainedValue()
        .receive(flags: flags, errorCode: errorCode, address: address)
}
