import Foundation
import Combine

/// App session state for Craft P0 shell. Persistence / VPN / probe come later.
@MainActor
final class AppModel: ObservableObject {
    /// ADR 0019: Welcome once.
    @Published var hasCompletedWelcome: Bool {
        didSet { UserDefaults.standard.set(hasCompletedWelcome, forKey: Keys.welcome) }
    }

    @Published private(set) var subscriptions: [Subscription] = []
    @Published var activeSubscriptionID: UUID?
    @Published var connection: ConnectionState = .idle

    /// In-memory toast for import success (2–3s).
    @Published var toast: ToastMessage?

    struct ToastMessage: Equatable, Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String?
    }

    private enum Keys {
        static let welcome = "routeva.hasCompletedWelcome"
    }

    init() {
        hasCompletedWelcome = UserDefaults.standard.bool(forKey: Keys.welcome)
    }

    var hasSubscription: Bool { !subscriptions.isEmpty }

    var activeSubscription: Subscription? {
        guard let activeSubscriptionID else { return subscriptions.first }
        return subscriptions.first { $0.id == activeSubscriptionID }
    }

    // MARK: - First-run

    func completeWelcome() {
        hasCompletedWelcome = true
    }

    // MARK: - Subscriptions (ADR 0020 single list, ADR 0033 naming)

    /// Stub import: real paste/QR parsing lands later. Always succeeds with demo data for shell.
    func addSubscriptionStub(from sourceHint: String?) {
        let url = sourceHint.flatMap { URL(string: $0) }
        let name = SubscriptionDisplayName.resolve(
            configName: nil,
            metadataOrFileName: nil,
            sourceURL: url,
            existingNames: subscriptions.map(\.displayName)
        )
        let sub = Subscription(
            displayName: name,
            nodeCount: Int.random(in: 8...48),
            expiresAt: Calendar.current.date(byAdding: .day, value: 30, to: Date()),
            dataUsedBytes: 20_000_000_000,
            dataTotalBytes: 100_000_000_000,
            lastUpdatedAt: Date(),
            sourceURLString: sourceHint
        )
        subscriptions.append(sub)
        if activeSubscriptionID == nil {
            activeSubscriptionID = sub.id
        }
        showToast(
            title: "Subscription added",
            subtitle: "\(sub.displayName) · \(sub.nodeCount) nodes"
        )
    }

    func setActive(_ id: UUID) {
        guard subscriptions.contains(where: { $0.id == id }) else { return }
        activeSubscriptionID = id
        // Switching Active is explicit; activity log later.
        if case .connected = connection {
            connection = .idle
        }
    }

    func refreshActiveStub() {
        guard let id = activeSubscriptionID,
              let idx = subscriptions.firstIndex(where: { $0.id == id }) else { return }
        subscriptions[idx].lastUpdatedAt = Date()
    }

    // MARK: - Connection gesture stubs (ADR 0018)

    func beginConnect() {
        guard hasSubscription else { return }
        connection = .connecting
        // Real path: VPN permission + tunnel + probe (ADR 0007).
        Task {
            try? await Task.sleep(nanoseconds: 900_000_000)
            await MainActor.run {
                if case .connecting = connection {
                    connection = .connected(since: Date())
                }
            }
        }
    }

    func disconnect() {
        connection = .idle
    }

    // MARK: - Toast

    private var toastTask: Task<Void, Never>?

    func showToast(title: String, subtitle: String?) {
        toastTask?.cancel()
        toast = ToastMessage(title: title, subtitle: subtitle)
        toastTask = Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            await MainActor.run {
                self.toast = nil
            }
        }
    }
}
