import SwiftUI

/// ADR 0019 — once, headline + one sub, Get started.
struct WelcomeView: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        ZStack {
            FieldBackground()
            VStack(alignment: .leading, spacing: 0) {
                Text("ROUTEVA")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(RoutevaTheme.textQuiet)
                    .padding(.top, 12)

                Spacer()

                VStack(alignment: .leading, spacing: 20) {
                    Text("Paste your subscription.\nWe handle the rest.")
                        .font(.system(size: 34, weight: .bold))
                        .tracking(-0.8)
                        .foregroundStyle(RoutevaTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Use a link you already have. We don’t sell or recommend providers.")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(RoutevaTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.bottom, 48)

                PrimaryButton(title: "Get started") {
                    app.completeWelcome()
                }
                .padding(.bottom, 12)
            }
            .padding(.horizontal, 28)
        }
    }
}
