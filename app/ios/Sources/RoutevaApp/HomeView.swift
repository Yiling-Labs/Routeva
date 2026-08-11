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
                downloadMbps: model.liveDownloadMbps,
                uploadMbps: model.liveUploadMbps
            )
            .frame(height: 112)
        default:
            NodeCoverFlow(
                nodes: model.availableNodes,
                selection: $model.selectedNodeIndex,
                openLocations: { model.presentedSurface = .locations }
            )
            .frame(height: 136)
        }
    }

    private var statusBand: some View {
        VStack(spacing: 10) {
            Text(LocalizedStringKey(statusTitle))
                .font(.system(size: 30, weight: .bold))
                .tracking(-0.8)

            switch model.connectionState {
            case .idle, .failed:
                modeButton
            case .connected:
                VStack(spacing: 9) {
                    Button {
                        model.presentedSurface = .locations
                    } label: {
                        HStack(spacing: 7) {
                            Text(node?.flag ?? "")
                            Text(node?.name ?? "")
                                .fontWeight(.semibold)
                            Text("· \(node?.protocolName ?? "")")
                                .foregroundStyle(RoutevaTheme.quiet)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(RoutevaTheme.quiet)
                        }
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .routevaGlass(cornerRadius: 999)
                    }
                    .buttonStyle(RoutevaPressStyle())
                    .accessibilityIdentifier("home.location")
                    modeButton
                }
            case .connecting:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity)
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
            }
            .buttonStyle(RoutevaPressStyle())
            .accessibilityIdentifier("home.mode")
        }
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
    let openLocations: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false

    private let step: CGFloat = 78

    private var boundedSelection: Int {
        guard !nodes.isEmpty else { return 0 }
        return min(max(selection, 0), nodes.count - 1)
    }

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { proxy in
                ZStack {
                    ForEach(Array(nodes.enumerated()), id: \.element.id) { item in
                        // Follow the finger while dragging: a leftward finger
                        // movement carries the visible node strip left, then
                        // settles the next item into the center on release.
                        let distance = CGFloat(item.offset - boundedSelection) + dragOffset / step
                        let absoluteDistance = abs(distance)

                        if absoluteDistance < 3.8 {
                            let isSelected = absoluteDistance < 0.45
                            let scale = coverScale(for: absoluteDistance)
                            let opacity = coverOpacity(for: absoluteDistance)
                            let verticalOffset = min(18, absoluteDistance * absoluteDistance * 2)

                            Button {
                                guard !isDragging else { return }
                                withAnimation(.routevaEase) {
                                    selection = item.offset
                                }
                            } label: {
                                NodeFlagOrb(flag: item.element.flag, isSelected: isSelected)
                            }
                            .buttonStyle(RoutevaPressStyle())
                            .scaleEffect(scale)
                            .opacity(opacity)
                            .offset(
                                x: distance * step,
                                y: verticalOffset
                            )
                            .zIndex(30 - Double(absoluteDistance) * 6)
                            .accessibilityLabel("\(item.element.country), \(item.element.name)")
                            .accessibilityAddTraits(isSelected ? .isSelected : [])
                        }
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .contentShape(Rectangle())
                // Keep each orb tappable. The drag recognizer joins rather
                // than replaces child button taps; it only claims a held,
                // horizontal movement once the user passes its threshold.
                .simultaneousGesture(dragGesture)
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
            .frame(height: 96)
            .animation(.routevaEase, value: selection)

            if !nodes.isEmpty {
                let selected = nodes[boundedSelection]
                Button(action: openLocations) {
                    HStack(spacing: 5) {
                        Text(selected.name)
                            .font(.system(size: 16, weight: .semibold))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .layoutPriority(0)
                        Text("· \(selected.protocolName)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(RoutevaTheme.quiet)
                            .lineLimit(1)
                            .layoutPriority(1)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(RoutevaTheme.quiet)
                            .fixedSize()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 28)
                }
                .buttonStyle(RoutevaPressStyle())
                .accessibilityLabel("Choose location, \(selected.name)")
                .accessibilityIdentifier("home.location")
            }
        }
    }

    private func coverScale(for distance: CGFloat) -> CGFloat {
        switch distance {
        case ..<0.5: 1.24
        case ..<1.5: 0.86
        case ..<2.5: 0.74
        default: 0.64
        }
    }

    private func coverOpacity(for distance: CGFloat) -> Double {
        switch distance {
        case ..<0.5: 1
        case ..<1.5: 0.8
        case ..<2.5: 0.5
        default: 0.3
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                isDragging = true
                dragOffset = value.translation.width
            }
            .onEnded { value in
                guard !nodes.isEmpty else {
                    dragOffset = 0
                    isDragging = false
                    return
                }

                let threshold: CGFloat = 36
                let nextSelection: Int
                if value.translation.width < -threshold {
                    nextSelection = min(boundedSelection + 1, nodes.count - 1)
                } else if value.translation.width > threshold {
                    nextSelection = max(boundedSelection - 1, 0)
                } else {
                    nextSelection = boundedSelection
                }

                withAnimation(.routevaEase) {
                    selection = nextSelection
                    dragOffset = 0
                }
                // Button actions can be delivered at the end of the same
                // touch sequence. Keep the drag state for this run loop so a
                // completed swipe cannot also select whichever orb it ended on.
                DispatchQueue.main.async {
                    isDragging = false
                }
            }
    }
}

private struct NodeFlagOrb: View {
    let flag: String
    let isSelected: Bool

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

            ForEach([RoutingMode.automatic, .global]) { mode in
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
    let downloadMbps: Double
    let uploadMbps: Double

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: 9) {
                Text(duration(from: startedAt, to: context.date))
                    .font(.system(size: 40, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .tracking(-0.8)
                HStack(spacing: 18) {
                    Text("↓ \(downloadMbps, format: .number.precision(.fractionLength(1))) Mb/s")
                    Text("↑ \(uploadMbps, format: .number.precision(.fractionLength(1))) Mb/s")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.78))
                .monospacedDigit()
            }
        }
    }

    private func duration(from start: Date, to end: Date) -> String {
        let seconds = max(0, Int(end.timeIntervalSince(start)))
        return String(format: "%02d:%02d:%02d", seconds / 3600, (seconds / 60) % 60, seconds % 60)
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

    private var lightLevel: CGFloat {
        max(0, min(1, isConnected || showsConnectingChrome ? 1 : progress))
    }

    private var ringProgress: CGFloat {
        isConnected || showsConnectingChrome ? ignitionProgress : progress
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
                        // The reference's busy cue lives in the upper face only;
                        // keep its dark-to-light range deliberately restrained.
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
                        .allowsHitTesting(false)
                    }
                }
                .shadow(color: showsConnectedChrome ? RoutevaTheme.mint.opacity(0.42) : .black.opacity(0.48), radius: 18, y: 12)
                .offset(y: trackTop + trackPadding + progress * travel)
                // Animate the moving geometry itself. State changes can also
                // restyle the thumb, so binding this to state caused a stale
                // top-half shadow to linger at the destination during a tap.
                .animation(reduceMotion || isDragging ? nil : slideAnimation, value: progress)
            }
            .frame(width: stageWidth, height: stageHeight)
            .scaleEffect(scale)
            .frame(width: stageWidth * scale, height: stageHeight * scale)
            .contentShape(Rectangle())
            .gesture(dragGesture, including: isEnabled ? .all : .none)
            .onAppear(perform: synchronizeConnectionAnimation)
            .onChange(of: state) { _, newState in
                switch newState {
                case .idle, .failed:
                    isPresentingConnection = false
                case .connected:
                    // A successful connection must immediately settle the
                    // capsule; only connecting owns the breathing highlight.
                    isPresentingConnection = false
                case .connecting:
                    break
                }
                synchronizeConnectionAnimation()
            }
            .onTapGesture {
                guard isEnabled, !showsConnectingChrome else { return }
                isConnected ? onDisconnect() : beginConnecting()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(showsConnectedChrome ? "Disconnect" : "Connect")
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("home.connect")

            Text(LocalizedStringKey(showsConnectedChrome ? "Swipe up to disconnect" : "Swipe down to connect"))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(RoutevaTheme.muted)
        }
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
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                guard !showsConnectingChrome else { return }
                isDragging = true
                translation = isConnected
                    ? min(0, max(-travel, value.translation.height / scale))
                    : max(0, min(travel, value.translation.height / scale))
            }
            .onEnded { _ in
                guard !showsConnectingChrome else { return }
                let shouldAct = isConnected ? progress < 0.35 : progress > 0.65
                isDragging = false
                translation = 0
                if shouldAct {
                    isConnected ? onDisconnect() : beginConnecting()
                }
            }
    }

    private func synchronizeConnectionAnimation() {
        if isConnecting || isPresentingConnection {
            ignitionProgress = 0
            busyPulseBright = false

            guard !reduceMotion else {
                ignitionProgress = 1
                return
            }

            withAnimation(.easeOut(duration: 0.9)) {
                ignitionProgress = 1
            }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                busyPulseBright = true
            }
        } else if isConnected {
            ignitionProgress = 1
            busyPulseBright = false
        } else {
            busyPulseBright = false
            if reduceMotion {
                ignitionProgress = 0
            } else {
                withAnimation(.easeOut(duration: 0.4)) {
                    ignitionProgress = 0
                }
            }
        }
    }

    private func beginConnecting() {
        isPresentingConnection = true
        synchronizeConnectionAnimation()
        onConnect()
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
