import Foundation

public struct CoreHealth: Equatable, Sendable {
    public let isAvailable: Bool
    public let consecutiveFailures: Int
    public let lastSuccessfulConnection: Date?

    public init(
        isAvailable: Bool,
        consecutiveFailures: Int = 0,
        lastSuccessfulConnection: Date? = nil
    ) {
        self.isAvailable = isAvailable
        self.consecutiveFailures = max(0, consecutiveFailures)
        self.lastSuccessfulConnection = lastSuccessfulConnection
    }
}

public struct CoreSelectionDecision: Equatable, Sendable {
    public enum Reason: Equatable, Sendable {
        case manuallyPinned
        case onlyCompatibleCore
        case protocolPreference
        case healthierCore
    }

    public let selected: CoreIdentifier
    public let orderedCandidates: [CoreIdentifier]
    public let reason: Reason

    public init(
        selected: CoreIdentifier,
        orderedCandidates: [CoreIdentifier],
        reason: Reason
    ) {
        self.selected = selected
        self.orderedCandidates = orderedCandidates
        self.reason = reason
    }
}

public enum CoreSelectionError: Error, Equatable, Sendable {
    case pinnedCoreUnavailable(CoreIdentifier)
    case pinnedCoreUnsupported(CoreIdentifier)
    case noCompatibleCore
}

public struct CoreSelector: Sendable {
    public init() {}

    public func select(
        manifest: RuntimeManifest,
        health: [CoreIdentifier: CoreHealth],
        excluding: Set<CoreIdentifier> = []
    ) throws -> CoreSelectionDecision {
        if let pinned = manifest.corePolicy.pinnedCore {
            guard !excluding.contains(pinned), health[pinned]?.isAvailable == true else {
                throw CoreSelectionError.pinnedCoreUnavailable(pinned)
            }
            guard pinned.declaredCapabilities.supports(manifest.profile) else {
                throw CoreSelectionError.pinnedCoreUnsupported(pinned)
            }
            return CoreSelectionDecision(
                selected: pinned,
                orderedCandidates: [pinned],
                reason: .manuallyPinned
            )
        }

        let preference = protocolPreference(for: manifest.profile.protocolKind)
        let compatible = preference.filter { core in
            !excluding.contains(core)
                && health[core]?.isAvailable == true
                && core.declaredCapabilities.supports(manifest.profile)
        }
        guard !compatible.isEmpty else {
            throw CoreSelectionError.noCompatibleCore
        }

        let ordered = compatible.sorted { lhs, rhs in
            score(lhs, preference: preference, health: health) > score(rhs, preference: preference, health: health)
        }
        let selected = ordered[0]
        let reason: CoreSelectionDecision.Reason
        if ordered.count == 1 {
            reason = .onlyCompatibleCore
        } else if (health[selected]?.consecutiveFailures ?? 0) != (health[ordered[1]]?.consecutiveFailures ?? 0) {
            reason = .healthierCore
        } else {
            reason = .protocolPreference
        }
        return CoreSelectionDecision(selected: selected, orderedCandidates: ordered, reason: reason)
    }

    private func protocolPreference(for protocolKind: ProxyProtocol) -> [CoreIdentifier] {
        [.singBox]
    }

    private func score(
        _ core: CoreIdentifier,
        preference: [CoreIdentifier],
        health: [CoreIdentifier: CoreHealth]
    ) -> Int {
        let preferenceIndex = preference.firstIndex(of: core) ?? preference.count
        let preferenceScore = (preference.count - preferenceIndex) * 10
        let failurePenalty = (health[core]?.consecutiveFailures ?? 0) * 100
        let successBonus = health[core]?.lastSuccessfulConnection == nil ? 0 : 1
        return preferenceScore + successBonus - failurePenalty
    }
}
