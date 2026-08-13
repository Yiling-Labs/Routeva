import SwiftUI

struct WelcomeView: View {
    let onContinue: () -> Void

    var body: some View {
        RoutevaField {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: -10) {
                    Text("Paste")
                    Text("Connect")
                    Text("Smart")
                }
                .font(.system(size: 56, weight: .bold))
                .tracking(-2.5)
                .foregroundStyle(RoutevaTheme.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(.bottom, 72)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)

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

    private static let privacyURL = URL(string: "https://routeva.yilinglabs.com/privacy/")!

    var body: some View {
        RoutevaField {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: -10) {
                    Text("On device")
                    Text("No tracking")
                }
                .font(.system(size: 56, weight: .bold))
                .tracking(-2.5)
                .foregroundStyle(RoutevaTheme.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(.bottom, 72)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)

                VStack(spacing: 4) {
                    Link("Privacy Policy", destination: Self.privacyURL)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(RoutevaTheme.muted)
                        .frame(maxWidth: .infinity, minHeight: 44)

                    RoutevaPrimaryButton(title: "Continue", action: onContinue)
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 18)
            .safeAreaPadding(.top, 6)
            .safeAreaPadding(.bottom, 12)
        }
    }
}
