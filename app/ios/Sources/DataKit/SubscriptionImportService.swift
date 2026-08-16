import Foundation
import SharedKit

public enum SubscriptionImportSource: Sendable, Equatable {
    case clipboard
    case qrCode
    case file(displayName: String?)
    case remoteURL(URL)

    var kind: String {
        switch self {
        case .clipboard: "clipboard"
        case .qrCode: "qr"
        case .file: "file"
        case .remoteURL: "remote-url"
        }
    }

    var suggestedName: String? {
        switch self {
        case let .file(displayName): displayName
        case let .remoteURL(url): url.host
        case .clipboard, .qrCode: nil
        }
    }

    func keychainDescriptor() throws -> Data {
        let value: [String: String]
        switch self {
        case let .remoteURL(url): value = ["kind": kind, "url": url.absoluteString]
        default: value = ["kind": kind]
        }
        return try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
    }
}

public struct SubscriptionImportResult: Sendable, Equatable {
    public let subscriptionID: UUID
    public let displayName: String
    public let nodeCount: Int
    public let skippedNodeCount: Int

    public init(subscriptionID: UUID, displayName: String, nodeCount: Int, skippedNodeCount: Int) {
        self.subscriptionID = subscriptionID
        self.displayName = displayName
        self.nodeCount = nodeCount
        self.skippedNodeCount = skippedNodeCount
    }
}

public actor SubscriptionImportService {
    private static let maximumRemoteRuleProviderCount = 32
    private static let maximumResolvedRuleProviderBytes = 8 * 1_024 * 1_024

    private let database: RoutevaDatabase
    private let secrets: any SecretStoring
    private let parser: SubscriptionParser
    private let encoder: JSONEncoder
    private let payloadLoader: any SubscriptionPayloadLoading

    public init(
        database: RoutevaDatabase,
        secrets: any SecretStoring,
        parser: SubscriptionParser = SubscriptionParser(),
        payloadLoader: any SubscriptionPayloadLoading = SubscriptionPayloadLoader()
    ) {
        self.database = database
        self.secrets = secrets
        self.parser = parser
        self.payloadLoader = payloadLoader
        encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
    }

    public func importPayload(
        _ payload: Data,
        source: SubscriptionImportSource,
        displayName: String? = nil,
        usage: SubscriptionUsage? = nil,
        makeActive: Bool
    ) async throws -> SubscriptionImportResult {
        let parsed = try parser.parse(payload, suggestedName: displayName ?? source.suggestedName)
        let resolvedRoutePolicy = try await resolveRuleProviders(in: parsed.routePolicy)
        let subscriptionID = UUID()
        let sourceReference = "subscription-source-\(UUID().uuidString)"
        var writtenReferences: [String] = []

        do {
            try await secrets.set(try source.keychainDescriptor(), for: sourceReference)
            writtenReferences.append(sourceReference)

            var nodes: [NodeRecord] = []
            nodes.reserveCapacity(parsed.nodes.count)
            for (index, node) in parsed.nodes.enumerated() {
                let country = NodeCountryResolver.resolve(displayName: node.displayName)
                let credentialReference = "node-credential-\(UUID().uuidString)"
                try await secrets.set(try encoder.encode(node.credential), for: credentialReference)
                writtenReferences.append(credentialReference)
                nodes.append(NodeRecord(
                    id: UUID(),
                    subscriptionID: subscriptionID,
                    sortIndex: index,
                    displayName: node.displayName,
                    countryCode: country?.countryCode,
                    protocolKind: node.protocolKind,
                    transport: node.transport,
                    security: node.security,
                    requiresUDP: node.requiresUDP,
                    endpointHost: node.endpointHost,
                    endpointPort: node.endpointPort,
                    credentialReference: credentialReference
                ))
            }

            let candidate = SubscriptionCandidate(
                subscription: SubscriptionRecord(
                    id: subscriptionID,
                    displayName: parsed.suggestedName,
                    sourceKind: source.kind,
                    sourceSecretReference: sourceReference,
                    isActive: false,
                    expiresAt: usage?.expiresAt,
                    usedBytes: usage?.usedBytes,
                    totalBytes: usage?.totalBytes,
                    routePolicyJSON: try resolvedRoutePolicy.map(encoder.encode)
                ),
                nodes: nodes
            )
            try await database.replaceSubscriptionAtomically(candidate, makeActive: makeActive)
            return SubscriptionImportResult(
                subscriptionID: subscriptionID,
                displayName: parsed.suggestedName,
                nodeCount: nodes.count,
                skippedNodeCount: parsed.skippedNodeCount
            )
        } catch {
            for reference in writtenReferences.reversed() {
                try? await secrets.remove(reference: reference)
            }
            throw error
        }
    }

    public func refreshSubscription(id: UUID) async throws -> SubscriptionImportResult {
        guard var subscription = try await database.subscription(id: id) else {
            throw RoutevaDatabaseError.subscriptionNotFound
        }
        let descriptorData = try await secrets.data(for: subscription.sourceSecretReference)
        guard let descriptor = try JSONSerialization.jsonObject(with: descriptorData) as? [String: String],
              descriptor["kind"] == "remote-url",
              let rawURL = descriptor["url"],
              let url = URL(string: rawURL),
              url.scheme?.lowercased() == "https"
        else { throw SubscriptionRefreshError.remoteSourceUnavailable }

        let resolved = try await payloadLoader.remotePayload(from: url)
        let parsed = try parser.parse(resolved.data, suggestedName: subscription.displayName)
        let resolvedRoutePolicy = try await resolveRuleProviders(in: parsed.routePolicy)
        let oldNodes = try await database.nodes(subscriptionID: id)
        let oldPreferredName = subscription.preferredNodeID.flatMap { preferredID in
            oldNodes.first(where: { $0.id == preferredID })?.displayName
        }
        var writtenReferences: [String] = []

        do {
            var nodes: [NodeRecord] = []
            for (index, node) in parsed.nodes.enumerated() {
                let country = NodeCountryResolver.resolve(displayName: node.displayName)
                let credentialReference = "node-credential-\(UUID().uuidString)"
                try await secrets.set(try encoder.encode(node.credential), for: credentialReference)
                writtenReferences.append(credentialReference)
                nodes.append(NodeRecord(
                    id: UUID(),
                    subscriptionID: id,
                    sortIndex: index,
                    displayName: node.displayName,
                    countryCode: country?.countryCode,
                    protocolKind: node.protocolKind,
                    transport: node.transport,
                    security: node.security,
                    requiresUDP: node.requiresUDP,
                    endpointHost: node.endpointHost,
                    endpointPort: node.endpointPort,
                    credentialReference: credentialReference
                ))
            }

            subscription.updatedAt = .now
            subscription.lastRefreshAt = .now
            subscription.routePolicyJSON = try resolvedRoutePolicy.map(encoder.encode)
            if let usage = resolved.usage {
                subscription.usedBytes = usage.usedBytes
                subscription.totalBytes = usage.totalBytes
                subscription.expiresAt = usage.expiresAt
            }
            subscription.preferredNodeID = oldPreferredName.flatMap { name in
                nodes.first(where: { $0.displayName == name })?.id
            }
            try await database.replaceSubscriptionAtomically(
                SubscriptionCandidate(subscription: subscription, nodes: nodes),
                makeActive: subscription.isActive
            )
            for oldNode in oldNodes { try? await secrets.remove(reference: oldNode.credentialReference) }
            return SubscriptionImportResult(
                subscriptionID: id,
                displayName: subscription.displayName,
                nodeCount: nodes.count,
                skippedNodeCount: parsed.skippedNodeCount
            )
        } catch {
            for reference in writtenReferences.reversed() { try? await secrets.remove(reference: reference) }
            throw error
        }
    }

    private func resolveRuleProviders(
        in policy: ProviderRoutePolicy?
    ) async throws -> ProviderRoutePolicy? {
        guard let policy else { return nil }
        guard policy.ruleSets.count <= Self.maximumRemoteRuleProviderCount else {
            throw SubscriptionParserError.unsupportedRouteRule("too_many_rule_providers")
        }

        var aggregateBytes = 0
        var resolvedRuleSets: [ProviderRuleSet] = []
        resolvedRuleSets.reserveCapacity(policy.ruleSets.count)
        for ruleSet in policy.ruleSets {
            switch ruleSet.source {
            case .inline:
                resolvedRuleSets.append(ruleSet)
            case let .remoteHTTPS(rawURL, format):
                guard let url = URL(string: rawURL),
                      url.scheme?.lowercased() == "https"
                else { throw SubscriptionParserError.insecureRuleProviderURL }
                let payload = try await payloadLoader.remotePayload(from: url).data
                guard aggregateBytes <= Self.maximumResolvedRuleProviderBytes - payload.count else {
                    throw SubscriptionParserError.payloadTooLarge
                }
                aggregateBytes += payload.count
                let matches = try parser.parseRuleProviderPayload(
                    payload,
                    behavior: ruleSet.behavior,
                    format: format
                )
                resolvedRuleSets.append(ProviderRuleSet(
                    tag: ruleSet.tag,
                    behavior: ruleSet.behavior,
                    source: .inline(matches)
                ))
            }
        }
        return ProviderRoutePolicy(
            rules: policy.rules,
            defaultAction: policy.defaultAction,
            ruleSets: resolvedRuleSets
        )
    }
}

public enum SubscriptionRefreshError: Error, Equatable, Sendable {
    case remoteSourceUnavailable
}

public struct ResolvedSubscriptionPayload: Sendable {
    public let data: Data
    public let source: SubscriptionImportSource
    public let usage: SubscriptionUsage?

    public init(data: Data, source: SubscriptionImportSource, usage: SubscriptionUsage? = nil) {
        self.data = data
        self.source = source
        self.usage = usage
    }
}

/// Provider-reported quota metadata from the standard `subscription-userinfo`
/// response header. Credentials and raw response headers are never persisted.
public struct SubscriptionUsage: Sendable, Equatable {
    public let usedBytes: Int64
    public let totalBytes: Int64
    public let expiresAt: Date?

    public init(usedBytes: Int64, totalBytes: Int64, expiresAt: Date?) {
        self.usedBytes = usedBytes
        self.totalBytes = totalBytes
        self.expiresAt = expiresAt
    }

    static func parse(header: String?) -> Self? {
        guard let header else { return nil }
        let values = header.split(separator: ";").reduce(into: [String: String]()) { values, field in
                let parts = field.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: true)
                guard parts.count == 2 else { return }
                values[parts[0].trimmingCharacters(in: .whitespaces).lowercased()] =
                    parts[1].trimmingCharacters(in: .whitespaces)
            }
        guard let upload = values["upload"].flatMap(Int64.init),
              let download = values["download"].flatMap(Int64.init),
              let total = values["total"].flatMap(Int64.init),
              upload >= 0, download >= 0, total > 0,
              upload <= Int64.max - download
        else { return nil }

        let expiresAt = values["expire"].flatMap(TimeInterval.init).flatMap { timestamp in
            timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : nil
        }
        return Self(usedBytes: min(upload + download, total), totalBytes: total, expiresAt: expiresAt)
    }
}

public enum SubscriptionPayloadLoaderError: Error, Equatable, Sendable {
    case insecureRemoteURL
    case invalidResponse
    case responseTooLarge
}

public protocol SubscriptionPayloadLoading: Sendable {
    func remotePayload(from url: URL) async throws -> ResolvedSubscriptionPayload
}

public struct SubscriptionPayloadLoader: SubscriptionPayloadLoading, Sendable {
    typealias DataLoader = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    private let dataLoader: DataLoader

    public init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        let session = URLSession(configuration: configuration)
        dataLoader = { request in try await session.data(for: request) }
    }

    init(dataLoader: @escaping DataLoader) {
        self.dataLoader = dataLoader
    }

    public func resolveClipboardText(_ text: String) async throws -> ResolvedSubscriptionPayload {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if Self.isExplicitProxyNodeURI(trimmed) {
            return ResolvedSubscriptionPayload(data: Data(trimmed.utf8), source: .clipboard)
        }
        if let url = Self.remoteHTTPSURL(fromClipboard: trimmed) {
            return try await remotePayload(from: url)
        }
        if Self.containsInsecureRemoteURL(trimmed) {
            throw SubscriptionPayloadLoaderError.insecureRemoteURL
        }
        return ResolvedSubscriptionPayload(data: Data(trimmed.utf8), source: .clipboard)
    }

    /// Picks the first fetchable HTTPS subscription URL out of a paste.
    /// Accepts a bare link, surrounding quotes, mixed title+URL text, and
    /// one-click install schemes (`clash://install-config?url=`).
    public static func remoteHTTPSURL(fromClipboard text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'“”‘’"))
        if let url = httpsURL(trimmed) { return url }
        if let url = oneClickInstallURL(trimmed) { return url }
        // A pasted node list / Clash document can embed `https://` inside
        // query values (notably `ech=cover+https://dns…`). Those are not
        // subscription URLs.
        let lowered = trimmed.lowercased()
        let proxySchemes = [
            "ss://", "vmess://", "vless://", "trojan://", "hysteria2://", "hy2://",
            "anytls://", "socks://", "socks5://", "tuic://",
        ]
        if proxySchemes.contains(where: { lowered.contains($0) }) { return nil }
        if lowered.contains("proxies:") { return nil }
        guard let match = trimmed.range(
            of: #"https://[^\s<>\"'`]+"#,
            options: .regularExpression
        ) else { return nil }
        var candidate = String(trimmed[match])
        while let last = candidate.last, ".,);]}".contains(last) {
            candidate.removeLast()
        }
        return httpsURL(candidate)
    }

    public func remotePayload(from url: URL) async throws -> ResolvedSubscriptionPayload {
        guard url.scheme?.lowercased() == "https" else {
            throw SubscriptionPayloadLoaderError.insecureRemoteURL
        }
        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: 20
        )
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        let productUserAgent = Self.subscriptionUserAgent(version: Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String)
        // 机场按 UA 关键字分流。默认同时带上 Clash Meta / Stash / Shadowrocket，
        // 避免 Routeva 被当成未知客户端而返回空 body。
        request.setValue(productUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(
            "application/json, text/yaml;q=0.9, application/yaml;q=0.9, text/plain;q=0.8, */*;q=0.5",
            forHTTPHeaderField: "Accept"
        )
        var (data, http) = try await validatedResponse(for: request)
        if data.isEmpty {
            request.setValue(
                Self.compatibilitySubscriptionUserAgent,
                forHTTPHeaderField: "User-Agent"
            )
            (data, http) = try await validatedResponse(for: request)
        }
        guard !data.isEmpty else { throw SubscriptionPayloadLoaderError.invalidResponse }
        return ResolvedSubscriptionPayload(
            data: data,
            source: .remoteURL(url),
            usage: SubscriptionUsage.parse(header: http.value(forHTTPHeaderField: "subscription-userinfo"))
        )
    }

    private static func containsInsecureRemoteURL(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'“”‘’"))
        if let url = URL(string: trimmed), url.scheme?.lowercased() == "http" {
            return true
        }
        guard let components = URLComponents(string: trimmed),
              let encoded = components.queryItems?.first(where: {
                  $0.name.lowercased() == "url"
              })?.value,
              let nested = URL(string: encoded)
        else { return false }
        return nested.scheme?.lowercased() == "http"
    }

    private static func isExplicitProxyNodeURI(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'“”‘’"))
        guard let components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              components.host != nil
        else { return false }
        if ["anytls", "socks", "socks5", "tuic"].contains(scheme) { return true }
        guard ["http", "https"].contains(scheme), components.port != nil else {
            return false
        }

        // Subscription delivery URLs commonly use an explicit non-443 port
        // plus a token in the path/query. Treating every such HTTPS URL as a
        // proxy endpoint prevents the subscription from ever being fetched.
        let hasSubscriptionPath = !components.path.isEmpty && components.path != "/"
        guard !hasSubscriptionPath, components.query == nil else { return false }

        // Plain HTTP is never accepted as a remote subscription, so the
        // authority-only form remains an explicit proxy. HTTPS is ambiguous;
        // require userinfo or a display-name fragment as an explicit signal.
        if scheme == "http" { return true }
        return components.user != nil
            || components.password != nil
            || components.fragment != nil
    }

    /// 订阅拉取 UA：Routeva 身份 + 机场常见客户端关键字。
    /// 不含单独的 `clash`：部分面板先匹配 clash 再匹配 meta，会下发空 `proxies: []`。
    static let compatibilitySubscriptionUserAgent = "ClashMeta clash.meta Stash Shadowrocket"

    static func subscriptionUserAgent(version: String?) -> String {
        let normalized = version?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .filter { $0.isASCII && ($0.isLetter || $0.isNumber || ".-_".contains($0)) }
        let safeVersion = normalized.flatMap { $0.isEmpty ? nil : $0 } ?? "1.0"
        return "Routeva/\(safeVersion) \(compatibilitySubscriptionUserAgent)"
    }

    private func validatedResponse(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await dataLoader(request)
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode),
              http.url?.scheme?.lowercased() == "https"
        else { throw SubscriptionPayloadLoaderError.invalidResponse }
        guard data.count <= SubscriptionParser.maximumPayloadBytes else {
            throw SubscriptionPayloadLoaderError.responseTooLarge
        }
        return (data, http)
    }

    private static func httpsURL(_ raw: String) -> URL? {
        guard let url = URL(string: raw),
              url.scheme?.lowercased() == "https",
              url.host != nil
        else { return nil }
        return url
    }

    private static func oneClickInstallURL(_ text: String) -> URL? {
        guard let components = URLComponents(string: text),
              let scheme = components.scheme?.lowercased(),
              ["clash", "clashmeta", "stash", "surge"].contains(scheme),
              let encoded = components.queryItems?.first(where: {
                  $0.name.lowercased() == "url"
              })?.value
        else { return nil }
        return httpsURL(encoded)
    }
}
