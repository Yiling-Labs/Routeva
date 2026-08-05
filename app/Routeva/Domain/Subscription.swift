import Foundation

/// User-owned proxy import (link / QR / file / single URI). Product does not sell these.
/// See CONTEXT: Subscription, Active Subscription, Subscription Display Name (ADR 0033).
struct Subscription: Identifiable, Equatable, Hashable {
    let id: UUID
    /// UI display name — auto-derived on import; optional rename later.
    var displayName: String
    var nodeCount: Int
    /// Unix seconds; nil when provider does not report.
    var expiresAt: Date?
    /// Bytes used / total when known.
    var dataUsedBytes: Int64?
    var dataTotalBytes: Int64?
    var lastUpdatedAt: Date
    /// Source hint for refresh (not shown raw to user by default).
    var sourceURLString: String?

    init(
        id: UUID = UUID(),
        displayName: String,
        nodeCount: Int = 0,
        expiresAt: Date? = nil,
        dataUsedBytes: Int64? = nil,
        dataTotalBytes: Int64? = nil,
        lastUpdatedAt: Date = Date(),
        sourceURLString: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.nodeCount = nodeCount
        self.expiresAt = expiresAt
        self.dataUsedBytes = dataUsedBytes
        self.dataTotalBytes = dataTotalBytes
        self.lastUpdatedAt = lastUpdatedAt
        self.sourceURLString = sourceURLString
    }
}

extension Subscription {
    var dataUsedGB: Double? {
        guard let dataUsedBytes else { return nil }
        return Double(dataUsedBytes) / 1_073_741_824
    }

    var dataTotalGB: Double? {
        guard let dataTotalBytes else { return nil }
        return Double(dataTotalBytes) / 1_073_741_824
    }
}
