import SwiftUI

struct GlassSurface: ViewModifier {
    var cornerRadius: CGFloat
    var highlighted = false

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(highlighted ? 0.13 : 0.10),
                                        .white.opacity(0.045),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        highlighted ? RoutevaTheme.mint.opacity(0.40) : .white.opacity(0.11),
                        lineWidth: 0.7
                    )
            }
            .shadow(color: .black.opacity(0.25), radius: 18, y: 10)
    }
}

extension View {
    func routevaGlass(cornerRadius: CGFloat = 20, highlighted: Bool = false) -> some View {
        modifier(GlassSurface(cornerRadius: cornerRadius, highlighted: highlighted))
    }

    func routevaToast(cornerRadius: CGFloat = 16, highlighted: Bool = false) -> some View {
        modifier(RoutevaToastSurface(cornerRadius: cornerRadius, highlighted: highlighted))
    }
}

struct RoutevaSheetBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 53 / 255, green: 59 / 255, blue: 66 / 255),
                Color(red: 26 / 255, green: 31 / 255, blue: 37 / 255),
                Color(red: 16 / 255, green: 20 / 255, blue: 24 / 255),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct RoutevaToastSurface: ViewModifier {
    let cornerRadius: CGFloat
    let highlighted: Bool

    func body(content: Content) -> some View {
        content
            .background(RoutevaSheetBackground())
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(highlighted ? RoutevaTheme.mint.opacity(0.30) : .white.opacity(0.14), lineWidth: 0.8)
            }
            .shadow(color: .black.opacity(0.40), radius: 18, y: 10)
    }
}

struct GlassOrb: View {
    let systemName: String
    let accessibilityLabel: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(RoutevaTheme.icon)
                .frame(width: 40, height: 40)
                .contentShape(Circle())
        }
        .buttonStyle(RoutevaPressStyle())
        .background(.ultraThinMaterial, in: Circle())
        .overlay(Circle().stroke(.white.opacity(0.11), lineWidth: 0.7))
        .shadow(color: .black.opacity(0.30), radius: 12, y: 7)
        .accessibilityLabel(Text(LocalizedStringKey(accessibilityLabel)))
    }
}

struct RoutevaPrimaryButton: View {
    let title: String
    var systemName: String?
    var isEnabled = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemName {
                    Image(systemName: systemName)
                }
                Text(LocalizedStringKey(title))
            }
            .font(.system(size: 16, weight: .heavy))
            .foregroundStyle(isEnabled ? Color(red: 10 / 255, green: 31 / 255, blue: 24 / 255) : RoutevaTheme.quiet)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isEnabled ? AnyShapeStyle(RoutevaTheme.mintButton) : AnyShapeStyle(.white.opacity(0.12)))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: isEnabled ? RoutevaTheme.mint.opacity(0.28) : .clear, radius: 18, y: 10)
        }
        .buttonStyle(RoutevaPressStyle())
        .disabled(!isEnabled)
    }
}

struct RoutevaSecondaryButton: View {
    let title: String
    var systemName: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemName { Image(systemName: systemName) }
                Text(LocalizedStringKey(title))
            }
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(RoutevaTheme.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .routevaGlass(cornerRadius: 18)
        }
        .buttonStyle(RoutevaPressStyle())
    }
}

struct RoutevaPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(reduceMotion ? nil : .routevaEase.speed(2), value: configuration.isPressed)
    }
}

struct RoutevaNavigationHeader: View {
    let title: String
    let backSystemName: String
    let backLabel: String
    var backAction: () -> Void

    var body: some View {
        HStack {
            GlassOrb(systemName: backSystemName, accessibilityLabel: backLabel, action: backAction)
            Spacer()
            Text(LocalizedStringKey(title))
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(RoutevaTheme.primary)
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        .frame(height: 48)
    }
}

struct RoutevaSectionLabel: View {
    let title: String

    var body: some View {
        Text(LocalizedStringKey(title.uppercased()))
            .font(.system(size: 12, weight: .semibold))
            .tracking(0.8)
            .foregroundStyle(RoutevaTheme.quiet)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
    }
}
