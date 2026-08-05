import SwiftUI

/// Tokens aligned with design/hi-fi visual-system (Field Black, soft glass, mint CTA).
enum RoutevaTheme {
    static let fieldTop = Color(red: 0.18, green: 0.20, blue: 0.23)
    static let fieldMid = Color(red: 0.09, green: 0.11, blue: 0.13)
    static let fieldBottom = Color(red: 0.04, green: 0.055, blue: 0.067)

    static let fieldGreenTop = Color(red: 0.30, green: 0.48, blue: 0.42)
    static let fieldGreenBottom = Color(red: 0.12, green: 0.25, blue: 0.22)

    static let textPrimary = Color.white.opacity(0.96)
    static let textSecondary = Color.white.opacity(0.52)
    static let textMuted = Color.white.opacity(0.58)
    static let textQuiet = Color.white.opacity(0.38)

    static let mint = Color(red: 0.50, green: 0.85, blue: 0.69)
    static let ctaTop = Color(red: 0.56, green: 0.91, blue: 0.75)
    static let ctaMid = Color(red: 0.29, green: 0.73, blue: 0.54)
    static let ctaBottom = Color(red: 0.18, green: 0.60, blue: 0.42)
    static let ctaLabel = Color(red: 0.04, green: 0.12, blue: 0.09)

    static var fieldGradient: LinearGradient {
        LinearGradient(
            colors: [fieldTop, fieldMid, fieldBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var fieldGreenGradient: LinearGradient {
        LinearGradient(
            colors: [fieldGreenTop, fieldGreenBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var ctaGradient: LinearGradient {
        LinearGradient(
            colors: [ctaTop, ctaMid, ctaBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct FieldBackground: View {
    var green: Bool = false
    var body: some View {
        (green ? RoutevaTheme.fieldGreenGradient : RoutevaTheme.fieldGradient)
            .ignoresSafeArea()
    }
}

struct GlassOrbButton: View {
    let systemName: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.82))
                .frame(width: 40, height: 40)
                .background {
                    Circle()
                        .fill(.ultraThinMaterial.opacity(0.35))
                        .overlay {
                            Circle()
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

struct PrimaryButton: View {
    let title: String
    var busy: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if busy {
                    ProgressView()
                        .tint(RoutevaTheme.ctaLabel)
                }
                Text(title)
                    .font(.system(size: 16, weight: .heavy))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .foregroundStyle(RoutevaTheme.ctaLabel)
            .background(RoutevaTheme.ctaGradient)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color(red: 0.2, green: 0.75, blue: 0.5).opacity(0.32), radius: 16, y: 8)
        }
        .buttonStyle(.plain)
        .disabled(busy)
        .opacity(busy ? 0.72 : 1)
    }
}

struct GhostButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .foregroundStyle(Color.white.opacity(0.86))
                .background(Color.white.opacity(0.06))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
