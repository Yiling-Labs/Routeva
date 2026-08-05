import SwiftUI

/// Settings root skeleton — Connection policy first (ADR 0021+). Deep-link Subscriptions.
struct SettingsView: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var showSubscriptions = false

    var body: some View {
        NavigationStack {
            ZStack {
                FieldBackground()
                List {
                    Section("Connection") {
                        row("Routing mode", trailing: "Auto")
                        row("DNS", trailing: "Automatic")
                        row("Overrides", trailing: nil)
                    }
                    Section("History") {
                        row("Activity", trailing: nil)
                        row("Snapshots", trailing: nil)
                    }
                    Section("App") {
                        Button {
                            showSubscriptions = true
                        } label: {
                            HStack {
                                Text("Subscriptions")
                                    .foregroundStyle(RoutevaTheme.textPrimary)
                                Spacer()
                                Text(app.activeSubscription?.displayName ?? "None")
                                    .foregroundStyle(RoutevaTheme.textSecondary)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(RoutevaTheme.textQuiet)
                            }
                        }
                        row("Privacy", trailing: nil)
                        row("About", trailing: nil)
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(RoutevaTheme.textPrimary)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showSubscriptions) {
            SubscriptionsView()
                .environmentObject(app)
        }
    }

    private func row(_ title: String, trailing: String?) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(RoutevaTheme.textPrimary)
            Spacer()
            if let trailing {
                Text(trailing)
                    .foregroundStyle(RoutevaTheme.textSecondary)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(RoutevaTheme.textQuiet)
        }
    }
}
