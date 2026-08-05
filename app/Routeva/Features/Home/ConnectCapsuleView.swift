import SwiftUI

/// Vertical capsule Connect Gesture (ADR 0018 / hi-fi 02-home).
/// Idle: START at top, swipe down. Connected: STOP at bottom, swipe up.
struct ConnectCapsuleView: View {
    let connection: ConnectionState
    let onConnect: () -> Void
    let onDisconnect: () -> Void

    private let trackW: CGFloat = 82
    private let trackH: CGFloat = 186
    private let thumbH: CGFloat = 78
    private let pad: CGFloat = 8
    private let commitThreshold: CGFloat = 0.72

    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @GestureState private var fingerDragging = false

    private var travel: CGFloat { trackH - thumbH - pad * 2 }

    /// 0 = START top, 1 = STOP bottom
    private var baseProgress: CGFloat {
        switch connection {
        case .idle, .cantConnect: return 0
        case .connecting, .connected: return 1
        }
    }

    private var progress: CGFloat {
        let raw = baseProgress + dragOffset / travel
        return min(1, max(0, raw))
    }

    private var thumbY: CGFloat { pad + travel * progress }

    /// Ring ignite 0…1 — idle none; drag ramps; connecting/connected full
    private var ignite: CGFloat {
        switch connection {
        case .connecting, .connected:
            return 1
        case .idle, .cantConnect:
            return isDragging || fingerDragging ? progress : 0
        }
    }

    private var isConnected: Bool {
        if case .connected = connection { return true }
        return false
    }

    private var isConnecting: Bool {
        if case .connecting = connection { return true }
        return false
    }

    private var canDrag: Bool {
        !isConnecting
    }

    var body: some View {
        ZStack {
            // Track
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.10),
                            Color.black.opacity(0.38),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay {
                    Capsule()
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                }
                .frame(width: trackW, height: trackH)
                .shadow(color: .black.opacity(0.35), radius: 8, y: 4)

            // Rings anchored near STOP seat (bottom)
            ringStack
                .frame(width: trackW, height: trackH)
                .allowsHitTesting(false)

            // Thumb
            thumb
                .frame(width: trackW - pad * 2, height: thumbH)
                .position(x: trackW / 2, y: thumbY + thumbH / 2)
                .gesture(dragGesture)
                .animation(
                    isDragging ? nil : .timingCurve(0.22, 1, 0.36, 1, duration: 0.42),
                    value: progress
                )
                .accessibilityElement()
                .accessibilityLabel(isConnected ? "Stop" : "Start")
                .accessibilityHint(isConnected ? "Swipe up to disconnect" : "Swipe down to connect")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction {
                    if isConnected {
                        onDisconnect()
                    } else if !isConnecting {
                        onConnect()
                    }
                }
        }
        .frame(width: trackW, height: trackH)
        .onChange(of: connection) { _, new in
            // Snap without residual drag when mode changes externally
            if !isDragging {
                dragOffset = 0
            }
            _ = new
        }
    }

    // MARK: - Thumb

    private var thumb: some View {
        ZStack {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.24, green: 0.27, blue: 0.30),
                            Color(red: 0.10, green: 0.12, blue: 0.15),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay {
                    Capsule()
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.45), radius: 12, y: 8)

            VStack(spacing: 4) {
                Text(isConnected || isConnecting ? "STOP" : "START")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.4)
                    .foregroundStyle(.white)

                Image(systemName: isConnected || isConnecting ? "stop.fill" : "power")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }

            // Top LED — dim idle → bright with progress / connected (not whole thumb green)
            Circle()
                .fill(ledColor)
                .frame(width: 6, height: 6)
                .shadow(color: ledColor.opacity(ledBrightness > 0.5 ? 0.9 : 0), radius: 4)
                .opacity(0.35 + 0.65 * ledBrightness)
                .offset(y: -(thumbH / 2) + 14)
        }
    }

    private var ledBrightness: CGFloat {
        if isConnected { return 1 }
        if isConnecting { return 0.85 }
        return progress
    }

    private var ledColor: Color {
        if isConnected {
            return RoutevaTheme.mint
        }
        // ramp toward mint as user commits
        return Color(
            red: 0.16 + 0.34 * progress,
            green: 0.27 + 0.58 * progress,
            blue: 0.20 + 0.49 * progress
        )
    }

    // MARK: - Rings (3, inner → outer with ignite)

    private var ringStack: some View {
        let seatY = trackH - pad - thumbH / 2
        return ZStack {
            ForEach(0..<3, id: \.self) { i in
                let ringProgress = ringAmount(index: i)
                Circle()
                    .stroke(
                        isConnected
                            ? RoutevaTheme.mint.opacity(0.25 + 0.55 * ringProgress)
                            : Color.white.opacity(0.08 + 0.45 * ringProgress),
                        lineWidth: 1.6
                    )
                    .frame(width: 36 + CGFloat(i) * 22, height: 36 + CGFloat(i) * 22)
                    .opacity(ringProgress > 0.02 ? 0.35 + 0.65 * ringProgress : 0)
                    .scaleEffect(0.92 + 0.08 * ringProgress)
            }
        }
        .position(x: trackW / 2, y: seatY)
    }

    /// Ring i lights when ignite crosses i/3, i=0 inner.
    private func ringAmount(index: Int) -> CGFloat {
        let start = CGFloat(index) / 3
        let end = CGFloat(index + 1) / 3
        if ignite <= start { return 0 }
        if ignite >= end { return 1 }
        return (ignite - start) / (end - start)
    }

    // MARK: - Gesture

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .updating($fingerDragging) { _, state, _ in
                state = true
            }
            .onChanged { value in
                guard canDrag else { return }
                isDragging = true
                // Finger down increases y (progress); up decreases.
                // From idle base 0: translation.height > 0 → down.
                // From connected base 1: translation.height < 0 → up.
                let delta = value.translation.height
                if baseProgress < 0.5 {
                    // connecting: only allow down
                    dragOffset = max(0, min(travel, delta))
                } else {
                    // disconnecting: only allow up
                    dragOffset = max(-travel, min(0, delta))
                }
            }
            .onEnded { _ in
                guard canDrag else {
                    dragOffset = 0
                    isDragging = false
                    return
                }
                let p = progress
                isDragging = false

                if baseProgress < 0.5 {
                    // Idle → maybe connect
                    if p >= commitThreshold {
                        withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.42)) {
                            dragOffset = travel // hold visual at bottom until state updates
                        }
                        onConnect()
                        // Clear offset after model jumps to connecting
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                            dragOffset = 0
                        }
                    } else {
                        withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.38)) {
                            dragOffset = 0
                        }
                    }
                } else {
                    // Connected → maybe disconnect (progress toward 0)
                    if p <= (1 - commitThreshold) {
                        withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.42)) {
                            dragOffset = -travel
                        }
                        onDisconnect()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                            dragOffset = 0
                        }
                    } else {
                        withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.38)) {
                            dragOffset = 0
                        }
                    }
                }
            }
    }
}
