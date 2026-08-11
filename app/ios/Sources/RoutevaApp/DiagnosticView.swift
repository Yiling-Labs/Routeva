import SwiftUI

struct DiagnosticSheetView: View {
    let diagnosticCase: DiagnosticCase
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var model: RoutevaAppModel

    var body: some View {
        RoutevaField {
            ZStack {
                diagnosticUnderlay
                Color.black.opacity(0.48).ignoresSafeArea()

                if model.repairState == .running {
                    RepairProgressView(cancel: model.cancelRepair)
                } else {
                    VStack {
                        Spacer()
                        DiagnosticCard(
                            content: content,
                            primaryAction: primaryAction,
                            dismissAction: dismiss.callAsFunction
                        )
                        .padding(.horizontal, 12)
                        .padding(.bottom, 12)
                    }
                }
            }
        }
    }

    private var diagnosticUnderlay: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(RoutevaTheme.muted)
            Text("Can’t connect")
                .font(.system(size: 30, weight: .bold))
            Spacer()
        }
        .opacity(0.45)
    }

    private var content: DiagnosticContent {
        switch diagnosticCase {
        case .clientFixable:
            DiagnosticContent(
                badge: "App can fix",
                confidence: "High confidence",
                why: "The VPN tunnel came up, but the connectivity check failed — so we don’t call this Connected.",
                impact: "Apps that need the proxy may stall or time out until this is fixed.",
                next: "We can try a safe repair: switch DNS preset, then re-check. You’ll give your OK first; we snapshot and can roll back.",
                primaryTitle: "Approve and repair",
                primaryIsMint: true,
                showsNotNow: true
            )
        case .provider:
            DiagnosticContent(
                badge: "Provider",
                confidence: "High confidence",
                why: "Your subscription looks expired or rejected by the provider — this isn’t something the app can repair alone.",
                impact: "Connecting will keep failing until the subscription is renewed or replaced.",
                next: "Open your provider’s site or app to renew, then paste a fresh link in Subscriptions.",
                primaryTitle: "Got it",
                primaryIsMint: false,
                showsNotNow: false
            )
        case .environment:
            DiagnosticContent(
                badge: "Your network",
                confidence: "Medium confidence",
                why: "This Wi‑Fi may require a sign-in page, or it blocks the connection type your nodes use.",
                impact: "Routeva can’t fix the network itself. Another network or node type may work.",
                next: "Try cellular or a different Wi‑Fi, then run the check again.",
                primaryTitle: "Try again",
                primaryIsMint: false,
                showsNotNow: true
            )
        case .unknown:
            DiagnosticContent(
                badge: "Not sure",
                confidence: "Low confidence",
                why: "We ran our usual checks and still can’t pin this down with high confidence.",
                impact: "Guessing a fix would be dishonest — we won’t invent a reason or repeat the same failed checks.",
                next: "Close this result, or export a redacted report from About if you want to share it with support.",
                primaryTitle: "Close",
                primaryIsMint: false,
                showsNotNow: false
            )
        }
    }

    private func primaryAction() {
        switch diagnosticCase {
        case .clientFixable:
            model.approveAndRepair()
        case .provider, .unknown:
            dismiss()
        case .environment:
            dismiss()
        }
    }
}

private struct DiagnosticContent {
    let badge: String
    let confidence: String
    let why: String
    let impact: String
    let next: String
    let primaryTitle: String
    let primaryIsMint: Bool
    let showsNotNow: Bool
}

private struct DiagnosticCard: View {
    let content: DiagnosticContent
    let primaryAction: () -> Void
    let dismissAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(.white.opacity(0.20))
                .frame(width: 36, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 14)

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("What we found")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(RoutevaTheme.muted)
                    Text("Can’t connect")
                        .font(.system(size: 22, weight: .bold))
                        .tracking(-0.5)
                }
                Spacer()
                Text(content.badge)
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(RoutevaTheme.mint.opacity(content.primaryIsMint ? 0.16 : 0.08), in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 0.7))
            }

            Text("\(content.confidence) · Same checks as the rest of the app")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(RoutevaTheme.muted)
                .padding(.top, 8)

            DiagnosticSection(title: "Why", text: content.why)
            DiagnosticSection(title: "Impact", text: content.impact)
            DiagnosticSection(title: "Next", text: content.next)

            if content.primaryIsMint {
                RoutevaPrimaryButton(title: content.primaryTitle, action: primaryAction)
                    .padding(.top, 18)
            } else {
                RoutevaSecondaryButton(title: content.primaryTitle, action: primaryAction)
                    .padding(.top, 18)
            }

            if content.showsNotNow {
                Button("Not now", action: dismissAction)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(RoutevaTheme.muted)
                    .frame(maxWidth: .infinity, minHeight: 42)
                    .buttonStyle(RoutevaPressStyle())
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 18)
        .background {
            LinearGradient(
                colors: [
                    Color(red: 58 / 255, green: 64 / 255, blue: 72 / 255),
                    Color(red: 28 / 255, green: 34 / 255, blue: 40 / 255),
                    Color(red: 18 / 255, green: 22 / 255, blue: 27 / 255),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.12), lineWidth: 0.8))
        .shadow(color: .black.opacity(0.50), radius: 30, y: -10)
        .accessibilityElement(children: .contain)
    }
}

private struct DiagnosticSection: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(0.7)
                .foregroundStyle(RoutevaTheme.quiet)
            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(RoutevaTheme.secondary)
                .lineSpacing(3)
        }
        .padding(.top, 14)
    }
}

private struct RepairProgressView: View {
    let cancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(RoutevaTheme.mint)
                .scaleEffect(1.45)
                .frame(width: 44, height: 44)
            Text("Repairing…")
                .font(.system(size: 18, weight: .bold))
            Text("Snapshot saved · trying DNS Compatibility · re-checking")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(RoutevaTheme.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
            RoutevaSecondaryButton(title: "Cancel", action: cancel)
                .padding(.top, 4)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity)
        .background {
            LinearGradient(
                colors: [
                    Color(red: 58 / 255, green: 64 / 255, blue: 72 / 255),
                    Color(red: 18 / 255, green: 22 / 255, blue: 27 / 255),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.12), lineWidth: 0.8))
        .shadow(color: .black.opacity(0.45), radius: 28, y: 18)
        .padding(.horizontal, 16)
    }
}
