import SwiftUI
import UIKit

struct HomeView: View {
    @EnvironmentObject private var model: RoutevaAppModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var showsModeSheet = false

    private var connected: Bool {
        if case .connected = model.connectionState { true } else { false }
    }

    var body: some View {
        RoutevaField(connected: connected) {
            ZStack {
                VStack(spacing: 0) {
                    HomeChrome()
                    Spacer()
                }

                if model.activeSubscription == nil {
                    HomeEmptyContent()
                } else {
                    HomeConnectionContent { showsModeSheet = true }
                }

                if let confirmation = model.importConfirmation {
                    ImportSuccessToast(confirmation: confirmation)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .padding(.horizontal, 22)
                        .padding(.top, 58)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .task(id: confirmation.displayName) {
                            try? await Task.sleep(for: .seconds(2.5))
                            guard model.importConfirmation == confirmation else { return }
                            withAnimation(.routevaEase) { model.importConfirmation = nil }
                        }
                }

                if let message = model.connectionFailureMessage {
                    ConnectionFailureToast(message: message)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .padding(.horizontal, 22)
                        .padding(.top, 58)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .task(id: message) {
                            try? await Task.sleep(for: .seconds(2.5))
                            guard model.connectionFailureMessage == message else { return }
                            withAnimation(.routevaEase) { model.connectionFailureMessage = nil }
                        }
                }

                if let nodeName = model.nodeFailoverToast {
                    NodeFailoverToast(nodeName: nodeName)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .padding(.horizontal, 22)
                        .padding(.top, 58)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .task(id: nodeName) {
                            try? await Task.sleep(for: .seconds(2.5))
                            guard model.nodeFailoverToast == nodeName else { return }
                            withAnimation(.routevaEase) { model.nodeFailoverToast = nil }
                        }
                }
            }
            .safeAreaPadding(.top, 4)
            .safeAreaPadding(.bottom, 8)
        }
        .fullScreenCover(item: $model.presentedSurface) { surface in
            switch surface {
            case .addSubscription:
                AddSubscriptionView()
            case .subscriptions:
                SubscriptionsView()
            case .locations:
                LocationView()
            case .settings:
                SettingsView()
            }
        }
        .sheet(isPresented: $showsModeSheet) {
            HomeModeSheet()
                .presentationDetents([.height(292)])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(28)
                .presentationBackground { RoutevaSheetBackground() }
        }
        .defersSystemGestures(on: connected ? .bottom : [])
        .onAppear {
            model.setHomeVisible(true)
            model.setSceneActive(scenePhase == .active)
        }
        .onDisappear { model.setHomeVisible(false) }
        .onChange(of: scenePhase) { _, phase in
            model.setSceneActive(phase == .active)
        }
    }
}

private struct NodeFailoverToast: View {
    let nodeName: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Color(red: 10 / 255, green: 31 / 255, blue: 24 / 255))
                .frame(width: 28, height: 28)
                .background(RoutevaTheme.mint, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("Switched node")
                    .font(.system(size: 14, weight: .bold))
                Text(nodeName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(RoutevaTheme.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(12)
        .routevaToast(cornerRadius: 16, highlighted: true)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.nodeFailoverToast")
    }
}

private struct ConnectionFailureToast: View {
    let message: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Color(red: 37 / 255, green: 20 / 255, blue: 15 / 255))
                .frame(width: 28, height: 28)
                .background(RoutevaTheme.warning, in: Circle())
            Text(message)
                .font(.system(size: 14, weight: .bold))
            Spacer()
        }
        .padding(12)
        .routevaToast(cornerRadius: 16)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.connectionFailureToast")
    }
}

private struct ImportSuccessToast: View {
    let confirmation: ImportConfirmation

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Color(red: 10 / 255, green: 31 / 255, blue: 24 / 255))
                .frame(width: 28, height: 28)
                .background(RoutevaTheme.mint, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(confirmation.displayName)
                    .font(.system(size: 14, weight: .bold))
                    .lineLimit(1)
                Text(String.localizedStringWithFormat(
                    String(localized: "Added %d nodes"),
                    confirmation.nodeCount
                ))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(RoutevaTheme.secondary)
            }
            Spacer()
        }
        .padding(12)
        .routevaToast(cornerRadius: 16, highlighted: true)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String.localizedStringWithFormat(
            String(localized: "Subscription added. %d nodes."),
            confirmation.nodeCount
        ))
        .accessibilityIdentifier("home.importConfirmation")
    }
}

private struct HomeChrome: View {
    @EnvironmentObject private var model: RoutevaAppModel

    var body: some View {
        HStack(spacing: 10) {
            if model.activeSubscription != nil {
                GlassOrb(
                    systemName: "rectangle.stack",
                    accessibilityLabel: "Subscriptions"
                ) {
                    model.presentedSurface = .subscriptions
                }
            }

            Spacer()

            GlassOrb(systemName: "gearshape", accessibilityLabel: "Settings") {
                model.presentedSurface = .settings
            }
        }
        .frame(height: 48)
        .padding(.horizontal, 22)
    }
}

private struct HomeEmptyContent: View {
    @EnvironmentObject private var model: RoutevaAppModel

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 120)

            Button {
                model.presentedSurface = .addSubscription
            } label: {
                VStack(spacing: 18) {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(RoutevaTheme.mint)
                        .frame(width: 56, height: 56)
                        .routevaGlass(cornerRadius: 28)

                    VStack(spacing: 10) {
                        Text("Add subscription")
                            .font(.system(size: 30, weight: .bold))
                            .tracking(-0.7)
                        Text("Paste a link you already have")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(RoutevaTheme.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.addSubscriptionHeader")
            .accessibilityLabel("Add subscription")

            Spacer()

            ConnectCapsule(
                state: .idle,
                isEnabled: false,
                scale: 1,
                onConnect: {},
                onDisconnect: {}
            )
            .opacity(0.30)

            RoutevaPrimaryButton(title: "Add subscription") {
                model.presentedSurface = .addSubscription
            }
            .accessibilityIdentifier("home.addSubscription")
            .padding(.top, 20)
            .padding(.horizontal, 28)
        }
        .padding(.bottom, 10)
    }
}

private struct HomeConnectionContent: View {
    @EnvironmentObject private var model: RoutevaAppModel
    let showModeSheet: () -> Void

    private var node: NodeSummary? {
        guard !model.availableNodes.isEmpty else { return nil }
        return model.availableNodes[min(model.selectedNodeIndex, model.availableNodes.count - 1)]
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = layout(for: proxy.size)

            VStack(spacing: 0) {
                upperBand
                    // Keep the enlarged selected orb clearly below the chrome;
                    // the cover-flow must never collide with the top controls.
                    .padding(.top, layout.nodeTopInset)

                Spacer()

                statusBand

                Spacer()

                ConnectCapsule(
                    state: model.connectionState,
                    isEnabled: true,
                    scale: layout.capsuleScale,
                    onConnect: model.requestConnection,
                    onDisconnect: model.disconnect
                )
            }
            // The capsule needs visual breathing room above the Home indicator.
            // This mirrors the reference's bottom stage rather than pinning the
            // interaction affordance to the screen edge.
            .padding(.bottom, layout.bottomInset)
        }
    }

    private func layout(for size: CGSize) -> HomeLayout {
        let heightScale: CGFloat
        let nodeTopInset: CGFloat
        let bottomInset: CGFloat

        switch size.height {
        case ..<700:
            heightScale = 0.78
            nodeTopInset = 36
            bottomInset = 30
        case ..<820:
            heightScale = 0.90
            nodeTopInset = 44
            bottomInset = 40
        default:
            heightScale = 1
            nodeTopInset = 52
            bottomInset = 50
        }

        // Keep the 260pt reference stage inside narrow windows too; iPad and
        // large iPhone layouts retain the authored 1× visual proportions.
        let widthScale = min(1, max(0.72, (size.width - 48) / 260))
        return HomeLayout(
            nodeTopInset: nodeTopInset,
            capsuleScale: min(heightScale, widthScale),
            bottomInset: bottomInset
        )
    }

    @ViewBuilder
    private var upperBand: some View {
        switch model.connectionState {
        case let .connected(startedAt):
            SessionStatsView(
                startedAt: startedAt,
                downloadedBytes: model.sessionDownloadedBytes,
                uploadedBytes: model.sessionUploadedBytes
            )
            .frame(height: 112)
        default:
            NodeCoverFlow(
                nodes: model.coverFlowNodes,
                selection: Binding(
                    get: { model.coverFlowSelectedIndex },
                    set: { model.setCoverFlowSelectedIndex($0) }
                ),
                latencies: model.nodeLatencies,
                locationEnabled: {
                    if case .connecting = model.connectionState { return false }
                    return true
                }(),
                openLocations: { model.presentedSurface = .locations }
            )
            .frame(height: 136)
        }
    }

    private var statusBand: some View {
        VStack(spacing: 10) {
            Group {
                if case .connecting = model.connectionState {
                    ConnectingEllipsisText()
                } else {
                    Text(LocalizedStringKey(statusTitle))
                }
            }
            .font(.system(size: 30, weight: .bold))
            .tracking(-0.8)

            switch model.connectionState {
            case .idle, .failed:
                modeButton
                    .transition(.opacity)
            case .connected:
                LocationModeSplitBar(
                    node: node,
                    modeTitle: model.routingMode == .direct
                        ? nil
                        : LocalizedStringKey(model.routingMode.rawValue),
                    onLocation: { model.presentedSurface = .locations },
                    onMode: showModeSheet
                )
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.97)),
                        removal: .opacity
                    )
                )
            case .connecting:
                Color.clear
                    .frame(height: 0)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
        .animation(locationModeAnimation, value: locationModePhase)
    }

    /// Idle / busy / on — scoped so capsule travel is not driven from here.
    private var locationModePhase: String {
        switch model.connectionState {
        case .idle, .failed: "idle"
        case .connecting: "busy"
        case .connected: "on"
        }
    }

    private var locationModeAnimation: Animation {
        if UIAccessibility.isReduceMotionEnabled {
            return .easeOut(duration: 0.15)
        }
        switch locationModePhase {
        case "on": return .easeOut(duration: 0.38).delay(0.12)
        case "idle": return .easeOut(duration: 0.20)
        default: return .easeOut(duration: 0.18)
        }
    }

    private var statusTitle: String {
        switch model.connectionState {
        case .idle: "Not Connected"
        case .connecting: "Connecting…"
        case .connected: "Connected"
        case .failed: "Not Connected"
        }
    }

    @ViewBuilder
    private var modeButton: some View {
        if model.routingMode != .direct {
            Button(action: showModeSheet) {
                HStack(spacing: 5) {
                    Text("Mode")
                        .foregroundStyle(RoutevaTheme.quiet)
                    Text(LocalizedStringKey(model.routingMode.rawValue))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(RoutevaTheme.quiet)
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(RoutevaTheme.secondary)
                .frame(minHeight: 44)
                .padding(.horizontal, 16)
            }
            .buttonStyle(RoutevaPressStyle())
            .accessibilityIdentifier("home.mode")
        }
    }
}

/// Connected: Location | Mode as one centered 44pt glass pill.
private struct LocationModeSplitBar: View {
    let node: NodeSummary?
    let modeTitle: LocalizedStringKey?
    let onLocation: () -> Void
    let onMode: () -> Void

    private let barHeight: CGFloat = 44

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onLocation) {
                HStack(spacing: 7) {
                    Text(node?.flag ?? "")
                        .font(.system(size: 16))
                    Text(Self.displayName(node?.name ?? ""))
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(RoutevaTheme.quiet)
                }
                .padding(.leading, 14)
                .padding(.trailing, 12)
                .frame(height: barHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(RoutevaPressStyle())
            .accessibilityLabel("Choose location, \(node?.name ?? "")")
            .accessibilityIdentifier("home.location")

            if modeTitle != nil {
                Rectangle()
                    .fill(Color.white.opacity(0.16))
                    .frame(width: 1, height: 16)

                Button(action: onMode) {
                    HStack(spacing: 5) {
                        Text("Mode")
                            .foregroundStyle(RoutevaTheme.quiet)
                        if let modeTitle {
                            Text(modeTitle)
                        }
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(RoutevaTheme.quiet)
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(RoutevaTheme.secondary)
                    .padding(.leading, 12)
                    .padding(.trailing, 16)
                    .frame(height: barHeight)
                    .fixedSize(horizontal: true, vertical: true)
                    .contentShape(Rectangle())
                }
                .buttonStyle(RoutevaPressStyle())
                .accessibilityIdentifier("home.mode")
            }
        }
        .frame(height: barHeight)
        .frame(maxWidth: 320)
        .fixedSize(horizontal: false, vertical: true)
        .routevaGlass(cornerRadius: barHeight / 2)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
    }

    /// Circular flag is already shown — drop a leading regional-indicator pair.
    private static func displayName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let scalars = Array(trimmed.unicodeScalars)
        let region: ClosedRange<UInt32> = 0x1F1E6...0x1F1FF
        guard scalars.count >= 2,
              region.contains(scalars[0].value),
              region.contains(scalars[1].value)
        else { return trimmed }
        return String(String.UnicodeScalarView(scalars.dropFirst(2)))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct HomeLayout {
    let nodeTopInset: CGFloat
    let capsuleScale: CGFloat
    let bottomInset: CGFloat
}

private struct NodeCoverFlow: View {
    let nodes: [NodeSummary]
    @Binding var selection: Int
    let latencies: [UUID: NodeLatencyStatus]
    var locationEnabled = true
    let openLocations: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Continuous strip position (node-index units). Unbounded so loops can
    /// fling across the seam without snapping scrollIndex back mid-gesture.
    @State private var scrollIndex: CGFloat = 0
    /// `scrollIndex` when the current drag began.
    @State private var dragOriginIndex: CGFloat = 0
    /// True for the whole touch sequence (incl. end-of-runloop) so orb taps
    /// do not fire after a swipe.
    @State private var isDragging = false

    private let step: CGFloat = 78
    /// Residual coast multiplier. ~1 keeps system prediction; higher feels light/floaty.
    private let flingGain: CGFloat = 0.59

    private var nodeCount: Int { nodes.count }

    /// Loop only when there is a meaningful ring (≥2 nodes).
    private var isLooping: Bool { nodeCount > 1 }

    private var boundedSelection: Int {
        guard !nodes.isEmpty else { return 0 }
        return min(max(selection, 0), nodes.count - 1)
    }

    /// Heavier settle: shorter travel, soft stop without a long coast.
    private var inertiaAnimation: Animation {
        if reduceMotion {
            return .easeOut(duration: 0.15)
        }
        return .interpolatingSpring(stiffness: 265, damping: 40.6)
    }

    var body: some View {
        VStack(spacing: 8) {
            // Animatable strip receives interpolated scrollIndex each frame so
            // intermediate nodes stay mounted and the coast is visible.
            NodeCoverFlowStrip(
                nodes: nodes,
                scrollIndex: scrollIndex,
                step: step,
                looping: isLooping,
                latencies: latencies,
                onSelect: { index in
                    guard !isDragging else { return }
                    commitToIndex(index, animated: true)
                }
            )
            .frame(height: 96)
            .contentShape(Rectangle())
            .simultaneousGesture(dragGesture)
            .onAppear {
                scrollIndex = CGFloat(boundedSelection)
            }
            .onChange(of: selection) { _, newValue in
                guard !isDragging else { return }
                guard !nodes.isEmpty else { return }
                let normalized = ((newValue % nodeCount) + nodeCount) % nodeCount
                let target = nearestScrollIndex(to: normalized)
                guard abs(scrollIndex - target) > 0.001 else { return }
                commitScrollIndex(target, selection: normalized, animated: true)
            }
            .onChange(of: nodes.count) { _, _ in
                guard !nodes.isEmpty else {
                    scrollIndex = 0
                    return
                }
                let normalized = boundedSelection
                let target = nearestScrollIndex(to: normalized)
                if abs(scrollIndex - target) > 0.001 {
                    commitScrollIndex(target, selection: normalized, animated: false)
                }
            }

            if !nodes.isEmpty {
                // Caption uses the same animatable scrollIndex presentation.
                NodeCoverFlowCaption(
                    nodes: nodes,
                    scrollIndex: scrollIndex,
                    looping: isLooping,
                    isEnabled: locationEnabled,
                    openLocations: openLocations
                )
            }
        }
    }

    /// Normalized selection index in `0..<count`.
    private func normalizedIndex(_ raw: Int) -> Int {
        guard nodeCount > 0 else { return 0 }
        let m = raw % nodeCount
        return m >= 0 ? m : m + nodeCount
    }

    /// Scroll target for a logical index that is closest to the current scroll
    /// (so external selection changes animate the short way around the ring).
    private func nearestScrollIndex(to logicalIndex: Int) -> CGFloat {
        guard isLooping else { return CGFloat(logicalIndex) }
        let count = CGFloat(nodeCount)
        let base = CGFloat(logicalIndex)
        let k = ((scrollIndex - base) / count).rounded()
        return base + k * count
    }

    private func commitToIndex(_ index: Int, animated: Bool) {
        guard !nodes.isEmpty else { return }
        let logical = normalizedIndex(index)
        let target = nearestScrollIndex(to: logical)
        commitScrollIndex(target, selection: logical, animated: animated)
    }

    private func commitScrollIndex(_ index: CGFloat, selection newSelection: Int, animated: Bool) {
        if animated && !reduceMotion {
            withAnimation(inertiaAnimation) {
                scrollIndex = index
                selection = newSelection
            }
        } else {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                scrollIndex = index
                selection = newSelection
            }
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard isLooping else { return }
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    if !isDragging {
                        isDragging = true
                        dragOriginIndex = scrollIndex
                    }
                    // Free continuous index — loops have no end rubber-band.
                    scrollIndex = dragOriginIndex - value.translation.width / step
                }
            }
            .onEnded { value in
                guard !nodes.isEmpty else {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        scrollIndex = 0
                        isDragging = false
                    }
                    return
                }
                guard isLooping else {
                    isDragging = false
                    return
                }

                // Coast from gesture velocity, then snap to nearest node on the ring.
                let finger = value.translation.width
                let residual = (value.predictedEndTranslation.width - finger) * flingGain
                let projectedFree = dragOriginIndex - (finger + residual) / step
                let rounded = projectedFree.rounded()
                let nextSelection = normalizedIndex(Int(rounded))

                withAnimation(inertiaAnimation) {
                    // Keep continuous scroll at the rounded projection so the
                    // seam crosses without a visual jump; selection is modular.
                    scrollIndex = rounded
                    selection = nextSelection
                }
                DispatchQueue.main.async {
                    isDragging = false
                }
            }
    }
}

/// Strip layout that participates in the scrollIndex animation timeline so
/// intermediate indices stay visible while a fling coasts.
private struct NodeCoverFlowStrip: View, @preconcurrency Animatable {
    let nodes: [NodeSummary]
    var scrollIndex: CGFloat
    let step: CGFloat
    let looping: Bool
    let latencies: [UUID: NodeLatencyStatus]
    let onSelect: (Int) -> Void

    nonisolated var animatableData: CGFloat {
        get { scrollIndex }
        set { scrollIndex = newValue }
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(Array(nodes.enumerated()), id: \.element.id) { item in
                    let distance = circularDistance(to: item.offset)
                    let absoluteDistance = abs(distance)

                    // Wide window so multi-node flings keep orbs mounted.
                    if absoluteDistance < 5.5 {
                        let isSelected = absoluteDistance < 0.45
                        let scale = coverScale(for: absoluteDistance)
                        let opacity = coverOpacity(for: absoluteDistance)
                        let verticalOffset = min(18, absoluteDistance * absoluteDistance * 2)

                        Button {
                            onSelect(item.offset)
                        } label: {
                            NodeFlagOrb(
                                flag: item.element.flag,
                                isSelected: isSelected,
                                latency: latencies[item.element.id]
                            )
                        }
                        .buttonStyle(RoutevaPressStyle())
                        .scaleEffect(scale)
                        .opacity(opacity)
                        .offset(
                            x: distance * step,
                            y: verticalOffset
                        )
                        .zIndex(30 - Double(absoluteDistance) * 6)
                        .accessibilityLabel(
                            accessibilityLabel(
                                node: item.element,
                                latency: latencies[item.element.id]
                            )
                        )
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .white, location: 0.10),
                        .init(color: .white, location: 0.90),
                        .init(color: .clear, location: 1),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
        }
    }

    /// Signed distance from `scrollIndex` to `itemIndex` on a linear strip or ring.
    private func circularDistance(to itemIndex: Int) -> CGFloat {
        let raw = CGFloat(itemIndex) - scrollIndex
        guard looping, nodes.count > 1 else { return raw }
        let count = CGFloat(nodes.count)
        // Wrap into (-count/2, count/2].
        var d = raw - count * floor((raw + count / 2) / count)
        // When count is even, floor can leave -count/2 and +count/2 aliases;
        // prefer the non-negative half so left/right don't fight.
        if d <= -count / 2 { d += count }
        if d > count / 2 { d -= count }
        return d
    }

    private func coverScale(for distance: CGFloat) -> CGFloat {
        let d = min(max(distance, 0), 3)
        switch d {
        case ..<1: return 1.24 + (0.86 - 1.24) * d
        case ..<2: return 0.86 + (0.74 - 0.86) * (d - 1)
        default: return 0.74 + (0.64 - 0.74) * (d - 2)
        }
    }

    private func coverOpacity(for distance: CGFloat) -> Double {
        let d = min(max(distance, 0), 3)
        switch d {
        case ..<1: return 1 + (0.8 - 1) * Double(d)
        case ..<2: return 0.8 + (0.5 - 0.8) * Double(d - 1)
        default: return 0.5 + (0.3 - 0.5) * Double(d - 2)
        }
    }

    private func accessibilityLabel(node: NodeSummary, latency: NodeLatencyStatus?) -> String {
        let latencyPart: String
        switch latency {
        case let .measured(ms): latencyPart = ", \(ms) milliseconds"
        case .testing: latencyPart = ", testing latency"
        case .unavailable: latencyPart = ", timeout"
        case .none: latencyPart = ""
        }
        return "\(node.country), \(node.name)\(latencyPart)"
    }
}

/// Caption that tracks the animating scroll position (same Animatable path).
private struct NodeCoverFlowCaption: View, @preconcurrency Animatable {
    let nodes: [NodeSummary]
    var scrollIndex: CGFloat
    let looping: Bool
    var isEnabled = true
    let openLocations: () -> Void

    nonisolated var animatableData: CGFloat {
        get { scrollIndex }
        set { scrollIndex = newValue }
    }

    private var focusedIndex: Int {
        guard !nodes.isEmpty else { return 0 }
        let rounded = Int(scrollIndex.rounded())
        if looping {
            let count = nodes.count
            let m = rounded % count
            return m >= 0 ? m : m + count
        }
        return min(max(rounded, 0), nodes.count - 1)
    }

    var body: some View {
        let focused = nodes[focusedIndex]
        let label = HStack(spacing: 5) {
            Text(focused.name)
                .font(.system(size: 16, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.tail)
                .layoutPriority(0)
            Text("· \(focused.protocolName)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(RoutevaTheme.quiet)
                .lineLimit(1)
                .layoutPriority(1)
            if isEnabled {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(RoutevaTheme.quiet)
                    .fixedSize()
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 28)
        .padding(.vertical, 10)
        .contentTransition(.opacity)

        Group {
            if isEnabled {
                Button(action: openLocations) { label }
                    .buttonStyle(RoutevaPressStyle())
            } else {
                label
                    .opacity(0.45)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityLabel("Choose location, \(focused.name)")
        .accessibilityIdentifier("home.location")
        .accessibilityAddTraits(isEnabled ? [] : .isStaticText)
    }
}

private struct NodeFlagOrb: View {
    let flag: String
    let isSelected: Bool
    var latency: NodeLatencyStatus? = nil

    private var flagURL: URL? {
        guard let countryCode = countryCode(from: flag) else { return nil }
        return URL(string: "https://flagcdn.com/w160/\(countryCode.lowercased()).png")
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: isSelected
                            ? [.white.opacity(0.30), .white.opacity(0.08), .black.opacity(0.16)]
                            : [.white.opacity(0.10), .white.opacity(0.025)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(Color(red: 26 / 255, green: 34 / 255, blue: 40 / 255))
                .overlay {
                    FlagImageFill(url: flagURL, fallbackFlag: flag, isDimmed: !isSelected)
                }
                .clipShape(Circle())
                .padding(isSelected ? 4 : 3)

            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.34), .white.opacity(0.05), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: isSelected ? 42 : 38, height: isSelected ? 20 : 18)
                .offset(y: isSelected ? -14 : -13)
                .allowsHitTesting(false)
        }
        .frame(width: 60, height: 60)
        .background {
            if isSelected {
                Circle()
                    .fill(.white.opacity(0.10))
                    .padding(-3)
            }
        }
        .overlay {
            Circle().stroke(
                isSelected ? .white.opacity(0.62) : .white.opacity(0.12),
                lineWidth: isSelected ? 1.6 : 1
            )
        }
        // Inset glass chip (design B) — sits on the flag disc, not hanging below.
        .overlay(alignment: .bottom) {
            CoverFlowLatencyBadge(status: latency, emphasized: isSelected)
                .padding(.horizontal, isSelected ? 9 : 8)
                .padding(.bottom, isSelected ? 8 : 7)
        }
        .shadow(color: .black.opacity(isSelected ? 0.48 : 0.32), radius: isSelected ? 16 : 9, y: isSelected ? 11 : 7)
        .shadow(color: isSelected ? .white.opacity(0.13) : .clear, radius: 10)
    }

    private func countryCode(from flag: String) -> String? {
        let regionalIndicatorBase: UInt32 = 0x1F1E6
        let regionalIndicatorLimit: UInt32 = 0x1F1FF
        let scalars = Array(flag.unicodeScalars)

        guard scalars.count == 2,
              scalars.allSatisfy({
                  regionalIndicatorBase...regionalIndicatorLimit ~= $0.value
              })
        else { return nil }

        return scalars.compactMap { scalar in
            UnicodeScalar(scalar.value - regionalIndicatorBase + 65).map { String($0) }
        }
        .joined()
    }
}

/// Inset glass latency chip (design B2): `NNms` + tier color.
/// Thresholds for proxy TCP RTT: &lt;100 good · 100…200 fair · &gt;200 / timeout poor.
private struct CoverFlowLatencyBadge: View {
    let status: NodeLatencyStatus?
    var emphasized = false

    /// Soft glass tints — readable on flag photos without traffic-light noise.
    private enum Tier {
        case good, fair, poor, neutral

        static func of(status: NodeLatencyStatus?) -> Tier {
            switch status {
            case let .measured(ms) where ms < 100: .good
            case let .measured(ms) where ms <= 200: .fair
            case .measured, .unavailable: .poor
            case .testing, .none: .neutral
            }
        }
    }

    var body: some View {
        switch status {
        case .none:
            EmptyView()
        case .testing:
            chip(label: "…", tier: .neutral)
        case let .measured(ms):
            chip(label: "\(ms)ms", tier: Tier.of(status: status))
        case .unavailable:
            chip(label: "—", tier: .poor)
        }
    }

    private func chip(label: String, tier: Tier) -> some View {
        Text(label)
            .font(.system(size: emphasized ? 9.5 : 8.5, weight: .bold).monospacedDigit())
            .tracking(label.hasSuffix("ms") ? -0.4 : 0)
            .foregroundStyle(foreground(tier))
            .frame(maxWidth: .infinity)
            .frame(height: emphasized ? 17 : 15)
            .background {
                Capsule()
                    .fill(background(tier))
                    .overlay {
                        Capsule()
                            .stroke(border(tier), lineWidth: 0.5)
                    }
                    .shadow(color: glow(tier), radius: tier == .neutral ? 2 : 4, y: 1)
            }
    }

    private func foreground(_ tier: Tier) -> Color {
        switch tier {
        case .good: Color(red: 190 / 255, green: 255 / 255, blue: 220 / 255)
        case .fair: Color(red: 255 / 255, green: 230 / 255, blue: 170 / 255)
        case .poor: Color(red: 255 / 255, green: 190 / 255, blue: 180 / 255)
        case .neutral: Color.white.opacity(0.62)
        }
    }

    private func background(_ tier: Tier) -> LinearGradient {
        switch tier {
        case .good:
            LinearGradient(
                colors: [
                    Color(red: 40 / 255, green: 120 / 255, blue: 90 / 255).opacity(0.90),
                    Color(red: 18 / 255, green: 56 / 255, blue: 42 / 255).opacity(0.94),
                ],
                startPoint: .top, endPoint: .bottom
            )
        case .fair:
            LinearGradient(
                colors: [
                    Color(red: 140 / 255, green: 100 / 255, blue: 36 / 255).opacity(0.88),
                    Color(red: 56 / 255, green: 40 / 255, blue: 14 / 255).opacity(0.94),
                ],
                startPoint: .top, endPoint: .bottom
            )
        case .poor:
            LinearGradient(
                colors: [
                    Color(red: 140 / 255, green: 52 / 255, blue: 44 / 255).opacity(0.88),
                    Color(red: 56 / 255, green: 22 / 255, blue: 18 / 255).opacity(0.94),
                ],
                startPoint: .top, endPoint: .bottom
            )
        case .neutral:
            LinearGradient(
                colors: [Color.white.opacity(0.20), Color.black.opacity(0.55)],
                startPoint: .top, endPoint: .bottom
            )
        }
    }

    private func border(_ tier: Tier) -> Color {
        switch tier {
        case .good: Color(red: 120 / 255, green: 230 / 255, blue: 180 / 255).opacity(0.45)
        case .fair: Color(red: 240 / 255, green: 200 / 255, blue: 100 / 255).opacity(0.40)
        case .poor: Color(red: 240 / 255, green: 140 / 255, blue: 120 / 255).opacity(0.38)
        case .neutral: Color.white.opacity(0.14)
        }
    }

    private func glow(_ tier: Tier) -> Color {
        switch tier {
        case .good: Color(red: 80 / 255, green: 200 / 255, blue: 140 / 255).opacity(0.35)
        case .fair: Color(red: 220 / 255, green: 170 / 255, blue: 60 / 255).opacity(0.28)
        case .poor: Color(red: 200 / 255, green: 80 / 255, blue: 60 / 255).opacity(0.28)
        case .neutral: .black.opacity(0.22)
        }
    }
}

private struct FlagImageFill: View {
    let url: URL?
    let fallbackFlag: String
    let isDimmed: Bool

    @State private var image: UIImage?
    @State private var didFailToLoad = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .saturation(isDimmed ? 0.75 : 1.05)
                    .brightness(isDimmed ? -0.12 : 0.02)
            } else if didFailToLoad {
                fallback
            } else {
                loading
            }
        }
        .scaleEffect(1.08)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        // The cover flow is removed from the hierarchy while connected. Keep
        // previously displayed flags outside that transient view lifecycle so
        // a disconnect does not depend on the network becoming available again.
        .task(id: url) {
            image = nil
            didFailToLoad = false

            guard let url else {
                didFailToLoad = true
                return
            }

            if let cachedImage = FlagImageCache.shared.image(for: url) {
                image = cachedImage
                return
            }

            image = await FlagImageCache.shared.loadImage(for: url)
            didFailToLoad = image == nil
        }
    }

    private var fallback: some View {
        Text(fallbackFlag)
            .font(.system(size: 28))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 26 / 255, green: 34 / 255, blue: 40 / 255))
    }

    private var loading: some View {
        LinearGradient(
            colors: [
                Color(red: 33 / 255, green: 43 / 255, blue: 50 / 255),
                Color(red: 20 / 255, green: 27 / 255, blue: 32 / 255),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

@MainActor
private final class FlagImageCache {
    static let shared = FlagImageCache()

    private let images = NSCache<NSURL, UIImage>()

    private init() {
        // Three cover-flow positions are normally visible; this keeps a small
        // buffer for swiping without retaining an unbounded number of flags.
        images.countLimit = 24
    }

    func image(for url: URL) -> UIImage? {
        images.object(forKey: url as NSURL)
    }

    func loadImage(for url: URL) async -> UIImage? {
        if let image = image(for: url) {
            return image
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let response = response as? HTTPURLResponse,
                  200..<300 ~= response.statusCode,
                  let image = UIImage(data: data)
            else {
                return nil
            }

            images.setObject(image, forKey: url as NSURL)
            return image
        } catch {
            return nil
        }
    }
}

private struct HomeModeSheet: View {
    @EnvironmentObject private var model: RoutevaAppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Capsule()
                .fill(.white.opacity(0.20))
                .frame(width: 36, height: 5)
                .frame(maxWidth: .infinity)

            Text("Mode")
                .font(.system(size: 22, weight: .bold))

            ForEach(RoutingMode.userSelectable) { mode in
                Button {
                    model.setRoutingMode(mode)
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(LocalizedStringKey(mode.rawValue))
                                .font(.system(size: 16, weight: .bold))
                            Text(LocalizedStringKey(mode.detail))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(RoutevaTheme.secondary)
                        }
                        Spacer()
                        if model.routingMode == mode {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .heavy))
                                .foregroundStyle(RoutevaTheme.mint)
                        }
                    }
                    .padding(14)
                    .routevaGlass(cornerRadius: 16, highlighted: model.routingMode == mode)
                }
                .buttonStyle(RoutevaPressStyle())
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .preferredColorScheme(.dark)
    }
}

private struct SessionStatsView: View {
    let startedAt: Date
    let downloadedBytes: UInt64
    let uploadedBytes: UInt64

    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        formatter.allowsNonnumericFormatting = false
        return formatter
    }()

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: 9) {
                Text(duration(from: startedAt, to: context.date))
                    .font(.system(size: 40, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .tracking(-0.8)
                HStack(spacing: 18) {
                    Text("↓ \(Self.formatBytes(downloadedBytes))")
                    Text("↑ \(Self.formatBytes(uploadedBytes))")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.78))
                .monospacedDigit()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    "Downloaded \(Self.formatBytes(downloadedBytes)), uploaded \(Self.formatBytes(uploadedBytes))"
                )
            }
        }
    }

    private func duration(from start: Date, to end: Date) -> String {
        let seconds = max(0, Int(end.timeIntervalSince(start)))
        return String(format: "%02d:%02d:%02d", seconds / 3600, (seconds / 60) % 60, seconds % 60)
    }

    /// Session cumulative traffic since this connection started.
    private static func formatBytes(_ bytes: UInt64) -> String {
        let value = Int64(clamping: bytes)
        return byteFormatter.string(fromByteCount: value)
    }
}

/// Connecting 态的“还在干活”提示：词干保持本地化，句点 . / .. / ... 循环。
private struct ConnectingEllipsisText: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dotCount = 1

    var body: some View {
        Group {
            if reduceMotion {
                Text("Connecting…")
            } else {
                let stem = Self.stem
                Text(stem + "...")
                    .hidden()
                    .overlay(alignment: .leading) {
                        Text(stem + String(repeating: ".", count: dotCount))
                    }
            }
        }
        .accessibilityLabel(Text("Connecting…"))
        .task(id: reduceMotion) {
            guard !reduceMotion else { return }
            dotCount = 1
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
                dotCount = dotCount % 3 + 1
            }
        }
    }

    /// 从已有 `Connecting…` 译串去掉尾部省略号，避免再维护一套词干。
    private static var stem: String {
        let localized = String(localized: "Connecting…")
        let trimmed = localized.trimmingCharacters(in: .whitespaces)
        if trimmed.hasSuffix("...") {
            return String(trimmed.dropLast(3)).trimmingCharacters(in: .whitespaces)
        }
        if trimmed.hasSuffix("…") {
            return String(trimmed.dropLast()).trimmingCharacters(in: .whitespaces)
        }
        return trimmed
    }
}

private struct ConnectCapsule: View {
    let state: RoutevaAppModel.ConnectionState
    let isEnabled: Bool
    let scale: CGFloat
    let onConnect: () -> Void
    let onDisconnect: () -> Void

    @State private var translation: CGFloat = 0
    @State private var isDragging = false
    @State private var ignitionProgress: CGFloat = 0
    @State private var busyPulseBright = false
    @State private var isPulsing = false
    @State private var isPresentingConnection = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let trackHeight: CGFloat = 204
    private let trackWidth: CGFloat = 80
    private let thumbHeight: CGFloat = 104
    private let inset: CGFloat = 5
    private let trackPadding: CGFloat = 7
    private let stageWidth: CGFloat = 260
    private let stageHeight: CGFloat = 340

    private var isConnected: Bool {
        if case .connected = state { true } else { false }
    }

    private var isConnecting: Bool {
        if case .connecting = state { true } else { false }
    }

    /// VPN startup can complete in a single render pass. Keep the authored
    /// connecting treatment until the actual connected state arrives, but
    /// never let it bleed into the settled connected chrome.
    private var showsConnectingChrome: Bool {
        isConnecting || (isPresentingConnection && !isConnected)
    }

    private var showsConnectedChrome: Bool {
        isConnected && !showsConnectingChrome
    }

    private var travel: CGFloat { trackHeight - thumbHeight - trackPadding * 2 }

    private var trackTop: CGFloat { (stageHeight - trackHeight) * 0.38 }

    private var stoppedCapCenterY: CGFloat {
        trackTop + travel + thumbHeight - (trackWidth - inset * 2) / 2 + 10
    }

    private var progress: CGFloat {
        if showsConnectingChrome { return 1 }
        let base = isConnected ? travel : 0
        return max(0, min(1, (base + translation) / travel))
    }

    /// Idle / Connected 静止座：热区停在这里，不跟着拇指走。
    private var restSeat: CGFloat {
        if showsConnectingChrome || isConnected { 1 } else { 0 }
    }

    private var lightLevel: CGFloat {
        if showsConnectingChrome { return 1 }
        if isDragging { return progress }
        if isConnected { return 1 }
        return progress
    }

    private var ringProgress: CGFloat {
        if showsConnectingChrome { return ignitionProgress }
        if isDragging { return progress }
        if isConnected { return ignitionProgress }
        return progress
    }

    private var slideAnimation: Animation {
        .timingCurve(0.22, 1, 0.36, 1, duration: 0.92)
    }

    private var ledColor: Color {
        guard lightLevel >= 0.06 else {
            return Color(red: 28 / 255, green: 36 / 255, blue: 32 / 255)
        }

        return Color(
            red: 30 / 255,
            green: Double(55 + 200 * lightLevel) / 255,
            blue: 70 / 255
        )
        .opacity(0.22 + 0.78 * Double(lightLevel))
    }

    var body: some View {
        VStack(spacing: 2) {
            ZStack(alignment: .top) {
                PinDotField(
                    progress: ringProgress,
                    centerY: stoppedCapCenterY,
                    isAnimating: showsConnectedChrome
                )
                    .frame(width: stageWidth, height: stageHeight)
                    .allowsHitTesting(false)

                RoundedRectangle(cornerRadius: 999)
                    .fill(
                        LinearGradient(
                            colors: showsConnectedChrome
                                ? [Color(red: 12 / 255, green: 36 / 255, blue: 28 / 255).opacity(0.50), Color(red: 6 / 255, green: 20 / 255, blue: 16 / 255).opacity(0.78)]
                                : [.white.opacity(0.12), Color(red: 8 / 255, green: 10 / 255, blue: 12 / 255).opacity(0.42), .black.opacity(0.48)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(RoundedRectangle(cornerRadius: 999).stroke(.white.opacity(0.10), lineWidth: 0.8))
                    .shadow(color: showsConnectedChrome ? RoutevaTheme.mint.opacity(0.16) : .black.opacity(0.35), radius: 18, y: 10)
                    .frame(width: trackWidth, height: trackHeight)
                    .offset(y: trackTop)

                if !showsConnectedChrome && lightLevel < 0.75 {
                    VStack(spacing: 1) {
                        Text("SWIPE")
                            .font(.system(size: 10, weight: .heavy))
                            .tracking(1.6)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(.white.opacity(0.55))
                    .opacity(0.42 * Double(1 - lightLevel))
                    .offset(y: trackTop + trackHeight - 39)
                    .allowsHitTesting(false)
                }

                if showsConnectedChrome {
                    VStack(spacing: 1) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 12, weight: .bold))
                        Text("SWIPE")
                            .font(.system(size: 10, weight: .heavy))
                            .tracking(1.6)
                    }
                    .foregroundStyle(Color(red: 180 / 255, green: 255 / 255, blue: 220 / 255).opacity(0.62))
                    .opacity(0.40)
                    .offset(y: trackTop + 11)
                    .allowsHitTesting(false)
                }

                thumbChrome
                    .allowsHitTesting(false)
                    .offset(y: trackTop + trackPadding + progress * travel)
                    .animation(reduceMotion || isDragging ? nil : slideAnimation, value: progress)

                // 手势打在静止热区上。绑在会移动的拇指上时，位移会取消手势，
                // translation 归零后手指还在，新手势又开始，录屏里就是隔帧回顶。
                Color.white.opacity(0.001)
                    .frame(width: trackWidth - inset * 2, height: thumbHeight)
                    .contentShape(Capsule())
                    .highPriorityGesture(dragGesture, including: gestureMask)
                    .offset(y: trackTop + trackPadding + restSeat * travel)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        showsConnectingChrome ? "Connecting" : (showsConnectedChrome ? "Disconnect" : "Connect")
                    )
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier("home.connect")
                    .accessibilityAction {
                        guard isEnabled, !showsConnectingChrome else { return }
                        isConnected ? onDisconnect() : beginConnecting(slideThumb: true)
                    }
            }
            .coordinateSpace(name: "connect-stage")
            .frame(width: stageWidth, height: stageHeight)
            .scaleEffect(scale)
            .frame(width: stageWidth * scale, height: stageHeight * scale)
            .onAppear(perform: synchronizeConnectionAnimation)
            .onChange(of: state) { _, newState in
                applyConnectionState(newState)
            }

            Group {
                if showsConnectingChrome {
                    ConnectingEllipsisText()
                } else {
                    Text(LocalizedStringKey(showsConnectedChrome ? "Swipe up to disconnect" : "Swipe down to connect"))
                }
            }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(RoutevaTheme.muted)
        }
    }

    private var gestureMask: GestureMask {
        isEnabled && !showsConnectingChrome ? .all : .none
    }

    private var thumbChrome: some View {
        VStack(spacing: 8) {
            Circle()
                .fill(ledColor)
                .frame(width: 7, height: 7)
                .shadow(
                    color: Color(red: 50 / 255, green: 255 / 255, blue: 130 / 255)
                        .opacity(lightLevel < 0.08 ? 0 : 0.25 + 0.70 * Double(lightLevel)),
                    radius: lightLevel < 0.08 ? 0 : 4 + 12 * lightLevel
                )
            Text(LocalizedStringKey(showsConnectingChrome ? "…" : (showsConnectedChrome ? "STOP" : "START")))
                .font(.system(size: 12, weight: .heavy))
                .tracking(1.4)
            Image(systemName: "power")
                .font(.system(size: 24, weight: .semibold))
        }
        .foregroundStyle(showsConnectedChrome ? Color(red: 10 / 255, green: 31 / 255, blue: 24 / 255) : .white)
        .frame(width: trackWidth - inset * 2, height: thumbHeight)
        .background {
            Capsule()
                .fill(thumbBackground)
        }
        .clipShape(Capsule())
        .overlay(Capsule().stroke(.white.opacity(showsConnectedChrome ? 0.28 : 0.16), lineWidth: 0.7))
        .overlay {
            if showsConnectingChrome {
                LinearGradient(
                    colors: [
                        Color(red: 117 / 255, green: 142 / 255, blue: 132 / 255)
                            .opacity(busyPulseBright ? 0.24 : 0.11),
                        Color(red: 76 / 255, green: 98 / 255, blue: 92 / 255)
                            .opacity(busyPulseBright ? 0.13 : 0.06),
                        .clear,
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: thumbHeight * 0.56, alignment: .top)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .clipShape(Capsule())
            }
        }
        .shadow(color: showsConnectedChrome ? RoutevaTheme.mint.opacity(0.42) : .black.opacity(0.48), radius: 18, y: 12)
    }

    private var thumbBackground: AnyShapeStyle {
        if showsConnectedChrome {
            return AnyShapeStyle(RoutevaTheme.mintButton)
        }
        if showsConnectingChrome {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color(red: 50 / 255, green: 61 / 255, blue: 58 / 255),
                        Color(red: 36 / 255, green: 46 / 255, blue: 43 / 255),
                        Color(red: 27 / 255, green: 35 / 255, blue: 33 / 255),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        return AnyShapeStyle(
            LinearGradient(
                colors: [
                    Color(red: 74 / 255, green: 82 / 255, blue: 90 / 255),
                    Color(red: 42 / 255, green: 49 / 255, blue: 56 / 255),
                    Color(red: 26 / 255, green: 31 / 255, blue: 36 / 255),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("connect-stage"))
            .onChanged { value in
                guard isEnabled, !showsConnectingChrome else { return }
                let dy = value.translation.height
                withoutAnimation {
                    isDragging = true
                    translation = isConnected
                        ? min(0, max(-travel, dy))
                        : max(0, min(travel, dy))
                }
            }
            .onEnded { value in
                guard isEnabled, !showsConnectingChrome else { return }
                let dy = value.translation.height
                let isTap = abs(dy) < 4 && abs(value.translation.width) < 4
                withoutAnimation { isDragging = false }

                if isTap {
                    if isConnected {
                        onDisconnect()
                    } else {
                        beginConnecting(slideThumb: true)
                    }
                    return
                }

                let shouldAct = isConnected ? progress < 0.35 : progress > 0.65
                if shouldAct {
                    if isConnected {
                        onDisconnect()
                        withoutAnimation { translation = 0 }
                    } else {
                        beginConnecting(slideThumb: progress < 0.97)
                    }
                } else {
                    withAnimation(reduceMotion ? nil : slideAnimation) {
                        translation = 0
                    }
                }
            }
    }

    private func applyConnectionState(_ newState: RoutevaAppModel.ConnectionState) {
        switch newState {
        case .idle, .failed:
            isPresentingConnection = false
            stopBusyPulse()
            if reduceMotion {
                ignitionProgress = 0
            } else {
                withAnimation(.easeOut(duration: 0.4)) {
                    ignitionProgress = 0
                }
            }
        case .connected:
            isPresentingConnection = false
            stopBusyPulse()
            ignitionProgress = 1
        case .connecting:
            if !isPresentingConnection {
                isPresentingConnection = true
                let lit = max(ignitionProgress, progress)
                ignitionProgress = lit
                settleIgnition(from: lit)
            }
            startBusyPulse()
        }
    }

    private func synchronizeConnectionAnimation() {
        applyConnectionState(state)
    }

    private func beginConnecting(slideThumb: Bool) {
        let lit = max(ignitionProgress, progress)
        if slideThumb && !reduceMotion {
            withAnimation(slideAnimation) {
                isPresentingConnection = true
                translation = 0
            }
        } else {
            withoutAnimation {
                isPresentingConnection = true
                translation = 0
            }
        }
        ignitionProgress = lit
        settleIgnition(from: lit)
        startBusyPulse()
        onConnect()
    }

    private func settleIgnition(from lit: CGFloat) {
        guard lit < 1 else { return }
        if reduceMotion {
            ignitionProgress = 1
        } else {
            withAnimation(.easeOut(duration: 0.9)) {
                ignitionProgress = 1
            }
        }
    }

    private func startBusyPulse() {
        guard !reduceMotion, !isPulsing else { return }
        isPulsing = true
        withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
            busyPulseBright = true
        }
    }

    private func stopBusyPulse() {
        isPulsing = false
        busyPulseBright = false
    }

    private func withoutAnimation(_ updates: () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction, updates)
    }
}

private struct PinDotField: View {
    let progress: CGFloat
    let centerY: CGFloat
    /// The connected field is alive: each dot gently dips at its own cadence.
    /// Connecting and drag-preview retain the deterministic ignite sequence.
    let isAnimating: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if isAnimating && !reduceMotion {
                TimelineView(.periodic(from: .now, by: 1.0 / 12.0)) { timeline in
                    dotField(at: timeline.date.timeIntervalSinceReferenceDate)
                }
            } else {
                dotField(at: 0)
            }
        }
    }

    private func dotField(at time: TimeInterval) -> some View {
        GeometryReader { proxy in
            let center = CGPoint(x: proxy.size.width / 2, y: centerY)
            let arcs: [(radius: CGFloat, count: Int, size: CGFloat)] = [
                (53, 32, 3.84),
                (73, 40, 3.42),
                (93, 48, 3.0),
            ]
            let ringPhase = isAnimating && !reduceMotion
                ? CGFloat((time / 2).truncatingRemainder(dividingBy: 1))
                : 0

            ForEach(Array(arcs.enumerated()), id: \.offset) { ring in
                let ringStart = CGFloat(ring.offset) / 3
                let ringSpan: CGFloat = 0.32
                let ringLit = max(0, min(1, (progress - ringStart) / ringSpan))
                let ringPosition = CGFloat(ring.offset) / CGFloat(arcs.count - 1)
                let ringPulse = isAnimating && !reduceMotion && progress > 0.95
                    ? max(
                        pulse(at: ringPosition - ringPhase),
                        pulse(at: ringPosition - (ringPhase - 1))
                    )
                    : 0

                ForEach(0..<ring.element.count, id: \.self) { dot in
                    let fraction = CGFloat(dot) / CGFloat(ring.element.count - 1)
                    // 240° open at the top: -30° → 210°, passing through the bottom.
                    let angle = -Double.pi / 6 + Double.pi * 4 / 3 * Double(fraction)
                    let elevation = sin(angle)
                    let sideFall = CGFloat(0.38 + 0.62 * pow(max(0, elevation + 0.42), 0.4))
                    let fromCenter = abs(fraction - 0.5) * 2
                    let dotStart = ringStart + fromCenter * ringSpan * 0.85
                    let dotLit = max(0, min(1, (progress - dotStart) / 0.1))
                    let intensity = min(ringLit, 0.15 + 0.85 * dotLit) * sideFall
                    let brightness = intensity * (0.55 + 0.45 * sideFall)
                        + ringPulse * 0.7 * sideFall * intensity
                    let size = max(1.5, ring.element.size * (1 - 0.5 * fromCenter))
                    let hot = intensity > 0.75 || ringPulse > 0.45
                    let flicker = flickerAmount(ring: ring.offset, dot: dot, time: time)

                    if intensity >= 0.04 {
                        Circle()
                            .fill(hot ? Color(red: 154 / 255, green: 1, blue: 212 / 255) : Color(red: 46 / 255, green: 232 / 255, blue: 138 / 255))
                            .frame(width: size, height: size)
                            .position(
                                x: center.x + CGFloat(cos(angle)) * ring.element.radius,
                                y: center.y + CGFloat(sin(angle)) * ring.element.radius
                            )
                            .opacity(Double(min(1, brightness) * flicker))
                            .shadow(color: hot ? Color(red: 80 / 255, green: 1, blue: 180 / 255).opacity(0.88) : .clear, radius: hot ? 5 + size * 1.3 : 0)
                    }
                }
            }
        }
    }

    /// Stable pseudo-random slots mean neighbouring dots never blink in unison.
    /// This is a direct native counterpart to the reference `02-home.html` field.
    private func flickerAmount(ring: Int, dot: Int, time: TimeInterval) -> CGFloat {
        guard isAnimating && !reduceMotion && progress > 0.95 else { return 1 }

        let seed = stableFraction((Double(ring) * 157.31 + Double(dot) * 71.7) * 0.3183)
        let rate = 1.2 + seed * 1.8
        let slot = floor(time * rate + seed * 97)
        let random = stableFraction(slot * 127.1 + seed * 311.7)
        return random < 0.25 ? 0.72 : 1
    }

    private func stableFraction(_ value: Double) -> Double {
        let hashed = sin(value) * 43_758.5453
        return hashed - floor(hashed)
    }

    private func pulse(at distance: CGFloat) -> CGFloat {
        CGFloat(exp(-pow(Double(distance) * 3.4, 2)))
    }
}
