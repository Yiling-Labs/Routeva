import SwiftUI

/// Paste-first import shell (ADR 0019). Real clipboard/QR parse later.
struct AddSubscriptionView: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var parsing = false
    @State private var failed = false

    var body: some View {
        NavigationStack {
            ZStack {
                FieldBackground()
                VStack(alignment: .leading, spacing: 0) {
                    if failed {
                        failBlock
                    } else {
                        Text("Add subscription")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(RoutevaTheme.textPrimary)
                            .padding(.top, 8)

                        Text("Get a subscription link or QR from your provider, then paste or scan it here.")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(RoutevaTheme.textSecondary)
                            .padding(.top, 12)
                    }

                    PrimaryButton(title: failed ? "Paste again" : "Paste from Clipboard") {
                        runImport(source: "clipboard://paste")
                    }
                    .padding(.top, failed ? 32 : 48)

                    HStack(spacing: 10) {
                        GhostButton(title: "Scan QR") {
                            runImport(source: "qr://scan")
                        }
                        GhostButton(title: "Import file") {
                            runImport(source: "file://demo.yaml")
                        }
                    }
                    .padding(.top, 12)

                    Spacer()

                    Text(failed ? "Nothing on this device was changed." : "We don’t sell or recommend providers.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(RoutevaTheme.textMuted)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
                .padding(.top, 8)

                if parsing {
                    parsingOverlay
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(RoutevaTheme.textPrimary)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var failBlock: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 28))
                .foregroundStyle(Color.orange.opacity(0.85))
            Text("Couldn’t add this")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(RoutevaTheme.textPrimary)
            Text("Copy a fresh link or QR from your provider, then try again.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(RoutevaTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
    }

    private var parsingOverlay: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .tint(RoutevaTheme.mint)
                    .scaleEffect(1.2)
                Text("Reading clipboard…")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(RoutevaTheme.textPrimary)
                Text("Checking your subscription")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(RoutevaTheme.textSecondary)
            }
            .padding(28)
            .frame(maxWidth: 300)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(red: 0.12, green: 0.14, blue: 0.16).opacity(0.98))
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.updatesFrequently)
        }
    }

    private func runImport(source: String) {
        failed = false
        parsing = true
        Task {
            try? await Task.sleep(nanoseconds: 900_000_000)
            await MainActor.run {
                parsing = false
                // Shell: always succeed. Wire real parse failure later.
                app.addSubscriptionStub(from: source.contains("http") ? source : "https://sub.example.com/v1")
                dismiss()
            }
        }
    }
}
