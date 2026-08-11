import SwiftUI

enum RoutevaTheme {
    static let primary = Color.white.opacity(0.96)
    static let secondary = Color.white.opacity(0.55)
    static let muted = Color.white.opacity(0.58)
    static let quiet = Color.white.opacity(0.38)
    static let icon = Color.white.opacity(0.82)
    static let mint = Color(red: 127 / 255, green: 217 / 255, blue: 176 / 255)
    static let warning = Color(red: 1, green: 176 / 255, blue: 120 / 255)

    static let blackField = LinearGradient(
        colors: [
            Color(red: 46 / 255, green: 52 / 255, blue: 58 / 255),
            Color(red: 23 / 255, green: 28 / 255, blue: 33 / 255),
            Color(red: 11 / 255, green: 14 / 255, blue: 17 / 255),
        ],
        startPoint: UnitPoint(x: 0.2, y: 0),
        endPoint: UnitPoint(x: 0.8, y: 1)
    )

    static let greenField = LinearGradient(
        colors: [
            Color(red: 77 / 255, green: 122 / 255, blue: 108 / 255),
            Color(red: 63 / 255, green: 107 / 255, blue: 94 / 255),
            Color(red: 53 / 255, green: 95 / 255, blue: 84 / 255),
            Color(red: 42 / 255, green: 79 / 255, blue: 70 / 255),
            Color(red: 31 / 255, green: 63 / 255, blue: 56 / 255),
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static let mintButton = LinearGradient(
        colors: [
            Color(red: 143 / 255, green: 232 / 255, blue: 192 / 255),
            Color(red: 75 / 255, green: 185 / 255, blue: 138 / 255),
            Color(red: 47 / 255, green: 154 / 255, blue: 108 / 255),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

extension Animation {
    static let routevaEase = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 0.45)
}

struct RoutevaField<Content: View>: View {
    var connected = false
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            RoutevaTheme.blackField
                .ignoresSafeArea()
            RoutevaTheme.greenField
                .opacity(connected ? 1 : 0)
                .ignoresSafeArea()
            RoutevaMapWash()
                .ignoresSafeArea()
            RoutevaHalftone()
                .ignoresSafeArea()
            content
        }
        .foregroundStyle(RoutevaTheme.primary)
        .animation(.routevaEase, value: connected)
    }
}

private struct RoutevaMapWash: View {
    var body: some View {
        Canvas { context, size in
            var ellipse = Path(ellipseIn: CGRect(
                x: -size.width * 0.1,
                y: size.height * 0.22,
                width: size.width * 1.2,
                height: size.height * 0.28
            ))
            context.stroke(ellipse, with: .color(.white.opacity(0.035)), lineWidth: 1)

            ellipse = Path()
            ellipse.move(to: CGPoint(x: -20, y: size.height * 0.38))
            ellipse.addCurve(
                to: CGPoint(x: size.width + 20, y: size.height * 0.34),
                control1: CGPoint(x: size.width * 0.25, y: size.height * 0.25),
                control2: CGPoint(x: size.width * 0.72, y: size.height * 0.45)
            )
            context.stroke(ellipse, with: .color(.white.opacity(0.035)), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}

private struct RoutevaHalftone: View {
    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                let startY = size.height * 0.58
                var y = startY
                while y < size.height {
                    var x = 0.0
                    while x < size.width {
                        let progress = (y - startY) / max(size.height - startY, 1)
                        let opacity = 0.012 + progress * 0.045
                        context.fill(
                            Path(ellipseIn: CGRect(x: x, y: y, width: 1.6, height: 1.6)),
                            with: .color(.white.opacity(opacity))
                        )
                        x += 6
                    }
                    y += 6
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .allowsHitTesting(false)
    }
}
