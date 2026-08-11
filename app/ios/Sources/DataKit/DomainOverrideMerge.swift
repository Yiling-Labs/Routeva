import Foundation

public struct DomainOverrideMerge: Sendable {
    public init() {}

    public func merge(
        local: [DomainOverrideRecord],
        remote: [DomainOverrideRecord]
    ) -> [DomainOverrideRecord] {
        var merged = Dictionary(local.map { ($0.domain, $0) }, uniquingKeysWith: newer)
        for candidate in remote {
            guard let existing = merged[candidate.domain] else {
                merged[candidate.domain] = candidate
                continue
            }
            if candidate.updatedAt > existing.updatedAt {
                merged[candidate.domain] = candidate
            }
            // Equal timestamps deliberately retain the local whole-record value.
        }
        return merged.values.sorted { lhs, rhs in
            lhs.domain.localizedStandardCompare(rhs.domain) == .orderedAscending
        }
    }

    private func newer(_ lhs: DomainOverrideRecord, _ rhs: DomainOverrideRecord) -> DomainOverrideRecord {
        lhs.updatedAt >= rhs.updatedAt ? lhs : rhs
    }
}
