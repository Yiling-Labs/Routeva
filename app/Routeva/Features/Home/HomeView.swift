import SwiftUI

/// Root canvas: empty vs idle + connect stub. ADR 0018 / 0020.
struct HomeView: View {
    @EnvironmentObject private var app: AppModel
    @State private var showAgent = false
    @State private var showSubscriptions = false
    @State private var showSettings = false
    @State private var showAdd = false

    private var isConnected: Bool {
        if case .connected = app.connection { return true }
        return false
    }

    var body: some View {
        ZStack {
            FieldBackground(green: isConnected)

            VStack(spacing: 0) {
                HomeChrome(
                    showSubscriptions: app.hasSubscription,
                    onAgent: { showAgent = true },
                    onSubscriptions: { showSubscriptions = true },
                    onSettings: { showSettings = true }
                )
                .padding(.horizontal, 22)
                .padding(.top, 8)

                if !app.hasSubscription {
                    HomeEmptyContent(onAdd: { showAdd = true })
                } else {
                    HomeIdleContent(
                        connection: app.connection,
                        activeName: app.activeSubscription?.displayName,
                        onConnect: { app.beginConnect() },
                        onDisconnect: { app.disconnect() }
                    )
                }
            }

            if let toast = app.toast {
                VStack {
                    ToastBanner(title: toast.title, subtitle: toast.subtitle)
                        .padding(.horizontal, 20)
                        .padding(.top, 62)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(20)
            }
        }
        .animation(.easeOut(duration: 0.32), value: app.toast?.id)
        .sheet(isPresented: $showAgent) {
            AgentPlaceholderView()
        }
        .sheet(isPresented: $showSubscriptions) {
            SubscriptionsView()
                .environmentObject(app)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(app)
        }
        .sheet(isPresented: $showAdd) {
            AddSubscriptionView()
                .environmentObject(app)
        }
    }
}

// MARK: - Chrome (ADR 0020)

private struct HomeChrome: View {
    let showSubscriptions: Bool
    let onAgent: () -> Void
    let onSubscriptions: () -> Void
    let onSettings: () -> Void

    var body: some View {
        HStack {
            HStack(spacing: 10) {
                GlassOrbButton(systemName: "bell.fill", accessibilityLabel: "Agent", action: onAgent)
                if showSubscriptions {
                    GlassOrbButton(systemName: "rectangle.stack.fill", accessibilityLabel: "Subscriptions", action: onSubscriptions)
                }
            }
            Spacer()
            GlassOrbButton(systemName: "gearshape.fill", accessibilityLabel: "Settings", action: onSettings)
        }
        .frame(height: 48)
    }
}

// MARK: - Empty

private struct HomeEmptyContent: View {
    let onAdd: () -> Void

    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(RoutevaTheme.mint)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Color.white.opacity(0.08)))
                    .overlay(Circle().stroke(Color.white.opacity(0.14), lineWidth: 1))

                Text("Add subscription")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(RoutevaTheme.textPrimary)

                Text("Paste a link you already have")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(RoutevaTheme.textSecondary)
            }
            Spacer()
            PrimaryButton(title: "Add subscription", action: onAdd)
                .padding(.horizontal, 28)
                .padding(.bottom, 36)
        }
    }
}

// MARK: - Idle / connect stub

private struct HomeIdleContent: View {
    let connection: ConnectionState
    let activeName: String?
    let onConnect: () -> Void
    let onDisconnect: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 48)

            // Cover flow / node label — placeholder until node model lands
            Text(activeName ?? "Subscription")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.88))
                .padding(.top, 24)

            Spacer()

            statusBlock

            Spacer()

            ConnectCapsuleView(
                connection: connection,
                onConnect: onConnect,
                onDisconnect: onDisconnect
            )
            .padding(.bottom, 14)

            Text(hint)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(RoutevaTheme.textMuted)
                .padding(.bottom, 36)
                .accessibilityHidden(hint.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    @ViewBuilder
    private var statusBlock: some View {
        switch connection {
        case .idle:
            Text("Not Connected")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(RoutevaTheme.textPrimary)
        case .connecting:
            Text("Connecting…")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(RoutevaTheme.textPrimary)
        case .connected(let since):
            VStack(spacing: 8) {
                Text(sessionLabel(since: since))
                    .font(.system(size: 40, weight: .light))
                    .monospacedDigit()
                    .foregroundStyle(RoutevaTheme.textPrimary)
                Text("Connected")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(RoutevaTheme.textSecondary)
            }
        case .cantConnect:
            Text("Can’t connect")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(RoutevaTheme.textPrimary)
        }
    }

    private var hint: String {
        switch connection {
        case .idle: return "Swipe down to connect"
        case .connecting: return " "
        case .connected: return "Swipe up to stop"
        case .cantConnect: return " "
        }
    }

    private func sessionLabel(since: Date) -> String {
        let s = Int(Date().timeIntervalSince(since))
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%02d:%02d", m, sec)
    }
}

// MARK: - Toast

private struct ToastBanner: View {
    let title: String
    let subtitle: String?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(RoutevaTheme.mint)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.green.opacity(0.2)))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(RoutevaTheme.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(RoutevaTheme.textSecondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 0.12, green: 0.14, blue: 0.16).opacity(0.96))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(RoutevaTheme.mint.opacity(0.35), lineWidth: 1)
                }
        }
        .allowsHitTesting(false)
    }
}
