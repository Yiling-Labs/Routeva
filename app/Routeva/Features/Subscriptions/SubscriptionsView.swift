import SwiftUI

/// Single list — Active highlighted, Update on active row, Add footer. No All page.
struct SubscriptionsView: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var refreshing = false
    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            ZStack {
                FieldBackground()
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(app.subscriptions) { sub in
                            SubscriptionRow(
                                sub: sub,
                                isActive: sub.id == app.activeSubscriptionID,
                                refreshing: refreshing && sub.id == app.activeSubscriptionID,
                                onSetActive: { app.setActive(sub.id) },
                                onUpdate: { refresh(sub.id) }
                            )
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 8)
                    .padding(.bottom, 100)
                }

                VStack {
                    Spacer()
                    PrimaryButton(title: "Add subscription") {
                        showAdd = true
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Subscriptions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(RoutevaTheme.textPrimary)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showAdd) {
            AddSubscriptionView()
                .environmentObject(app)
        }
    }

    private func refresh(_ id: UUID) {
        refreshing = true
        Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            await MainActor.run {
                app.refreshActiveStub()
                refreshing = false
            }
        }
    }
}

private struct SubscriptionRow: View {
    let sub: Subscription
    let isActive: Bool
    let refreshing: Bool
    let onSetActive: () -> Void
    let onUpdate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(sub.displayName)
                        .font(.system(size: isActive ? 20 : 17, weight: .bold))
                        .foregroundStyle(RoutevaTheme.textPrimary)
                    Text(metaLine)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(RoutevaTheme.textSecondary)
                    Text("Updated \(sub.lastUpdatedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(RoutevaTheme.textQuiet)
                }
                Spacer(minLength: 8)
                if isActive {
                    activeBadge
                } else {
                    Button("Set active", action: onSetActive)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.5))
                }
            }

            if isActive {
                if let used = sub.dataUsedGB, let total = sub.dataTotalGB, total > 0 {
                    traffic(used: used, total: total)
                }
                PrimaryButton(title: refreshing ? "Updating…" : "Update", busy: refreshing, action: onUpdate)
                    .padding(.top, 14)
            }
        }
        .padding(isActive ? EdgeInsets(top: 18, leading: 16, bottom: 16, trailing: 16) : EdgeInsets(top: 16, leading: 16, bottom: 14, trailing: 16))
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(isActive ? Color(red: 0.12, green: 0.18, blue: 0.16).opacity(0.95) : Color.white.opacity(0.06))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(isActive ? RoutevaTheme.mint.opacity(0.4) : Color.white.opacity(0.1), lineWidth: 1)
                }
        }
    }

    private var metaLine: String {
        var parts = ["\(sub.nodeCount) nodes"]
        if let exp = sub.expiresAt {
            parts.append(exp.formatted(date: .abbreviated, time: .omitted))
        }
        return parts.joined(separator: " · ")
    }

    private var activeBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(RoutevaTheme.mint)
                .frame(width: 6, height: 6)
            Text("ACTIVE")
                .font(.system(size: 12, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(RoutevaTheme.mint)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(RoutevaTheme.mint.opacity(0.16)))
        .overlay(Capsule().stroke(RoutevaTheme.mint.opacity(0.35), lineWidth: 1))
    }

    private func traffic(used: Double, total: Double) -> some View {
        let pct = min(1, used / total)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Data")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(RoutevaTheme.textSecondary)
                Spacer()
                Text(String(format: "%.1f / %.0f GB", used, total))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.88))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(RoutevaTheme.mint.opacity(0.85))
                        .frame(width: geo.size.width * pct)
                }
            }
            .frame(height: 7)
        }
        .padding(.top, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Data \(Int(pct * 100)) percent used")
    }
}
