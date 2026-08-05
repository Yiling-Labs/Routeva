import SwiftUI

/// Thick Agent shell — tools / Cloud AI consent later (ADR 0003 / 0025).
struct AgentPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                FieldBackground()
                VStack(spacing: 12) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(RoutevaTheme.mint.opacity(0.9))
                    Text("Agent")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(RoutevaTheme.textPrimary)
                    Text("Natural language + tool allowlist.\nDiagnostic Engine stays the judge.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(RoutevaTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(RoutevaTheme.textPrimary)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
}
