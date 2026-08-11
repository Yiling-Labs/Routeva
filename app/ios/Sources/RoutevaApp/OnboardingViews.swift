import SwiftUI

struct WelcomeView: View {
    let onContinue: () -> Void

    var body: some View {
        RoutevaField {
            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                VStack(alignment: .leading, spacing: 20) {
                    Text("Paste your subscription.\nWe handle the rest.")
                        .font(.system(size: 34, weight: .bold))
                        .tracking(-1.2)
                        .foregroundStyle(RoutevaTheme.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("No technical setup. Connects first—and explains itself when it doesn’t.")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(RoutevaTheme.secondary)
                        .lineSpacing(4)
                        .frame(maxWidth: 310, alignment: .leading)
                }
                .padding(.bottom, 92)

                Spacer()

                RoutevaPrimaryButton(title: "Get started", action: onContinue)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 18)
            .safeAreaPadding(.top, 6)
            .safeAreaPadding(.bottom, 12)
        }
    }
}

struct DataAndPrivacyView: View {
    let onContinue: () -> Void

    var body: some View {
        RoutevaField {
            VStack(alignment: .leading, spacing: 0) {
                Text("DATA & PRIVACY")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1.8)
                    .foregroundStyle(RoutevaTheme.quiet)
                    .padding(.top, 18)

                Spacer(minLength: 28)

                VStack(alignment: .leading, spacing: 18) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 25, weight: .medium))
                        .foregroundStyle(RoutevaTheme.mint)
                        .frame(width: 54, height: 54)
                        .routevaGlass(cornerRadius: 18)

                    Text("Your connection data stays under your control.")
                        .font(.system(size: 30, weight: .bold))
                        .tracking(-0.8)
                        .foregroundStyle(RoutevaTheme.primary)

                    VStack(spacing: 12) {
                        PrivacyPoint(
                            icon: "key.fill",
                            title: "Credentials stay on this device",
                            detail: "Subscription links and proxy credentials are never uploaded by Routeva."
                        )
                        PrivacyPoint(
                            icon: "icloud.fill",
                            title: "Only domain exceptions use iCloud",
                            detail: "Subscriptions, DNS settings, logs and connection snapshots do not sync."
                        )
                        PrivacyPoint(
                            icon: "waveform.path.ecg",
                            title: "No analytics or cloud help",
                            detail: "This Beta includes no telemetry, ads, third-party crash SDK or cloud assistant."
                        )
                    }
                }

                Spacer(minLength: 24)

                RoutevaPrimaryButton(title: "Continue", action: onContinue)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 18)
            .safeAreaPadding(.top, 6)
            .safeAreaPadding(.bottom, 12)
        }
    }
}

private struct PrivacyPoint: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(RoutevaTheme.mint)
                .frame(width: 30, height: 30)
                .background(RoutevaTheme.mint.opacity(0.11), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(RoutevaTheme.primary)
                Text(detail)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(RoutevaTheme.muted)
                    .lineSpacing(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .routevaGlass(cornerRadius: 18)
    }
}
