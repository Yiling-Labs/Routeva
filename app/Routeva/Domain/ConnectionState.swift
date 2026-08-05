import Foundation

/// Home connect state machine (ADR 0018). Green field only on `.connected` (probe success later).
enum ConnectionState: Equatable {
    case idle
    case connecting
    /// Tunnel + Connectivity Probe success (ADR 0007). UI may show green field.
    case connected(since: Date)
    case cantConnect
}
