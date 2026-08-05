import Foundation

/// Silent naming on import (ADR 0033). No forced naming step.
enum SubscriptionDisplayName {
    /// Priority: config name → metadata/filename → host weak name → neutral default.
    static func resolve(
        configName: String?,
        metadataOrFileName: String?,
        sourceURL: URL?,
        existingNames: [String]
    ) -> String {
        let candidates: [String?] = [
            configName?.trimmingCharacters(in: .whitespacesAndNewlines),
            metadataOrFileName?.trimmingCharacters(in: .whitespacesAndNewlines),
            weakName(from: sourceURL),
        ]
        if let pick = candidates.compactMap({ $0 }).first(where: { !$0.isEmpty }) {
            return uniquify(pick, existing: existingNames)
        }
        return uniquify("Subscription", existing: existingNames)
    }

    private static func weakName(from url: URL?) -> String? {
        guard let host = url?.host, !host.isEmpty else { return nil }
        let stripped = host
            .replacingOccurrences(of: "www.", with: "")
            .split(separator: ".")
            .first
            .map(String.init)
        guard let stripped, stripped.count >= 2 else { return host }
        return stripped.prefix(1).uppercased() + stripped.dropFirst()
    }

    private static func uniquify(_ base: String, existing: [String]) -> String {
        let set = Set(existing)
        if !set.contains(base) { return base }
        var n = 2
        while set.contains("\(base) \(n)") { n += 1 }
        return "\(base) \(n)"
    }
}
