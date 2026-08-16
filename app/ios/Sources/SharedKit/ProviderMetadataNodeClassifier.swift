import Foundation

/// 识别机场插进节点列表的说明/额度横幅。
///
/// 这些行在协议上常常是合法代理（甚至复用真节点的证书），不能靠连通性判断。
/// 也不用展示名词表：词表会漏掉未见过的文案，也会误伤「香港-域名优化」这类真节点。
/// 只看结构——假主机、名字里的 URL/FQDN、`标签：额度或日期`、以及不像节点名的长说明句。
public enum ProviderMetadataNodeClassifier: Sendable {
    public static func isMetadata(displayName: String, host: String) -> Bool {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let endpoint = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return false }

        if isDummyHost(endpoint) { return true }
        if containsURLOrFQDN(name) { return true }
        if looksLikeLabeledMetric(name) { return true }
        if looksLikeBareMetricWithoutNodeIdentity(name) { return true }
        if looksLikeInstructionSentence(name) { return true }
        return false
    }

    private static func isDummyHost(_ host: String) -> Bool {
        let lowered = host.lowercased()
        if lowered == "localhost" || lowered.hasSuffix(".localhost") { return true }
        if lowered.contains("g00gle") { return true }
        if lowered == "::" || lowered == "::1" || lowered == "0:0:0:0:0:0:0:0" || lowered == "0:0:0:0:0:0:0:1" {
            return true
        }
        let parts = lowered.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4, parts.allSatisfy({ UInt8($0) != nil }) else { return false }
        return parts[0] == "0" || parts[0] == "127"
    }

    private static func containsURLOrFQDN(_ name: String) -> Bool {
        name.range(of: #"https?://[^\s]+"#, options: .regularExpression) != nil
            || name.range(of: #"(?i)(?<![A-Za-z0-9-])(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,24}(?![A-Za-z0-9-])"#, options: .regularExpression) != nil
    }

    /// `剩余流量：19.06%` / `Expire: 2026-09-14` / `重置：29 天`
    private static func looksLikeLabeledMetric(_ name: String) -> Bool {
        for separator in [":", "："] {
            guard let index = name.firstIndex(of: Character(separator)) else { continue }
            let value = name[name.index(after: index)...]
            if containsStructuredMetric(String(value)) { return true }
        }
        return false
    }

    /// 无冒号时：名字里出现日期/百分比/容量/时长，且没有地区/国旗/`[倍率]`。
    /// 不把数字本身当节点身份——额度文案几乎都带数字。
    private static func looksLikeBareMetricWithoutNodeIdentity(_ name: String) -> Bool {
        guard containsStructuredMetric(name) else { return false }
        if name.contains("[") { return false }
        if name.contains(where: isRegionalIndicatorFlag) { return false }
        return NodeCountryResolver.resolve(displayName: name) == nil
    }

    private static func looksLikeInstructionSentence(_ name: String) -> Bool {
        let cjkCount = name.unicodeScalars.filter(isCJKIdeograph).count
        guard cjkCount >= 14 else { return false }
        return !hasNodeIdentity(name)
    }

    private static func hasNodeIdentity(_ name: String) -> Bool {
        if name.contains("[") { return true }
        if name.unicodeScalars.contains(where: { $0.isASCII && 48...57 ~= $0.value }) { return true }
        if name.contains(where: isRegionalIndicatorFlag) { return true }
        return NodeCountryResolver.resolve(displayName: name) != nil
    }

    private static func containsStructuredMetric(_ text: String) -> Bool {
        let patterns = [
            #"\d{4}[-/.年]\d{1,2}[-/.月]\d{1,2}"#,
            #"\d+(?:\.\d+)?\s*%"#,
            #"(?i)\d+(?:\.\d+)?\s*(?:[KMGT]i?B)\b"#,
            #"(?i)\d+(?:\.\d+)?\s*(?:天|日|小时|小時|时|時|分钟|分鐘|秒|(?:days?|hours?|hrs?|mins?|seconds?)\b)"#,
        ]
        return patterns.contains { text.range(of: $0, options: .regularExpression) != nil }
    }

    private static func isCJKIdeograph(_ scalar: Unicode.Scalar) -> Bool {
        (0x4E00...0x9FFF).contains(scalar.value)
            || (0x3400...0x4DBF).contains(scalar.value)
            || (0xF900...0xFAFF).contains(scalar.value)
    }

    private static func isRegionalIndicatorFlag(_ character: Character) -> Bool {
        let scalars = Array(character.unicodeScalars)
        return scalars.count == 2 && scalars.allSatisfy { (0x1F1E6...0x1F1FF).contains($0.value) }
    }
}
