import AVFoundation
import DataKit
import OSLog
import SharedKit
import SwiftUI
import UIKit
import Vision
import VisionKit

struct AddSubscriptionView: View {
    private static let logger = Logger(
        subsystem: "com.yilinglabs.routeva",
        category: "subscription-import"
    )

    private enum ImportFailure: Equatable {
        case clipboardEmpty
        case network
        case providerResponse
        case unsupportedFormat
        case surgeProfileWithoutProxyPolicies
        case secureStorage
        case localStorage
        case cameraUnavailable
        case unknown

        var message: String {
            switch self {
            case .clipboardEmpty:
                "Copy a subscription link, then try again."
            case .network:
                "Couldn’t reach the subscription provider. Check your connection and try again."
            case .providerResponse:
                "The provider didn’t return a valid subscription response."
            case .unsupportedFormat:
                "The provider returned a format Routeva can’t import."
            case .surgeProfileWithoutProxyPolicies:
                "This Surge file has rules and proxy groups, but no proxy servers to import."
            case .secureStorage:
                "Secure storage isn’t available in this build. Nothing was saved."
            case .localStorage:
                "Routeva couldn’t save the subscription on this device."
            case .cameraUnavailable:
                "QR scanning isn’t available on this device."
            case .unknown:
                "Copy a fresh link or QR from your provider, then try again."
            }
        }
    }

    private enum Phase: Equatable {
        case ready
        case parsing(String)
        case failed(ImportFailure)
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var model: RoutevaAppModel
    @State private var phase: Phase = .ready
    @State private var showsQRScanner = false

    var body: some View {
        RoutevaField {
            ZStack {
                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        GlassOrb(systemName: "xmark", accessibilityLabel: "Close") {
                            dismiss()
                        }
                    }
                    .frame(height: 48)

                    if case let .failed(failure) = phase {
                        failureHeader(failure)
                            .padding(.top, 22)
                    } else {
                        readyHeader
                            .padding(.top, 12)
                    }

                    RoutevaPrimaryButton(
                        title: isFailed ? "Paste again" : "Paste from Clipboard"
                    ) {
                        pasteFromClipboard()
                    }
                    .accessibilityIdentifier("subscription.pasteClipboard")
                    .padding(.top, isFailed ? 32 : 48)

                    ImportOptionButton(title: "Scan QR", systemName: "qrcode.viewfinder") {
                        requestQRScanner()
                    }
                    .padding(.top, 12)

                    Spacer()

                    Text(isFailed
                         ? "Nothing on this device was changed."
                         : "We don’t sell or recommend providers.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(RoutevaTheme.muted)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .safeAreaPadding(.top, 4)
                .safeAreaPadding(.bottom, 20)
                .disabled(isParsing)
                .accessibilityHidden(isParsing)

                if case let .parsing(label) = phase {
                    ParsingOverlay(label: label)
                }
            }
        }
        .sheet(isPresented: $showsQRScanner) {
            QRCodeScannerView { value in
                showsQRScanner = false
                phase = .parsing("Reading QR code…")
                Task { @MainActor in
                    do {
                        _ = try await model.importQRCodeText(value)
                        dismiss()
                    } catch {
                        phase = .failed(Self.failure(for: error))
                    }
                }
            }
            .ignoresSafeArea()
        }
    }

    private var isParsing: Bool {
        if case .parsing = phase { true } else { false }
    }

    private var isFailed: Bool {
        if case .failed = phase { true } else { false }
    }

    private var readyHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add subscription")
                .font(.system(size: 28, weight: .bold))
                .tracking(-0.7)
            Text("Get a subscription link or QR from your provider, then paste or scan it here.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(RoutevaTheme.secondary)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func failureHeader(_ failure: ImportFailure) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Color(red: 1, green: 200 / 255, blue: 180 / 255).opacity(0.9))
                .frame(width: 52, height: 52)
                .routevaGlass(cornerRadius: 26)
            Text("Couldn’t add this")
                .font(.system(size: 26, weight: .bold))
                .tracking(-0.5)
            Text(failure.message)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(RoutevaTheme.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(maxWidth: 280)
        }
        .frame(maxWidth: .infinity)
    }

    private func pasteFromClipboard() {
        #if DEBUG
        let value = ProcessInfo.processInfo.environment["ROUTEVA_UI_TEST_CLIPBOARD"]
            ?? UIPasteboard.general.string
        #else
        let value = UIPasteboard.general.string
        #endif
        guard let value, !value.isEmpty else {
            phase = .failed(.clipboardEmpty)
            return
        }
        phase = .parsing("Reading from Clipboard…")
        Task { @MainActor in
            do {
                _ = try await model.importClipboardText(value)
                dismiss()
            } catch {
                phase = .failed(Self.failure(for: error))
            }
        }
    }

    private func requestQRScanner() {
        guard DataScannerViewController.isSupported else {
            phase = .failed(.cameraUnavailable)
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showsQRScanner = true
        case .notDetermined:
            Task { @MainActor in
                if await AVCaptureDevice.requestAccess(for: .video) {
                    showsQRScanner = true
                } else {
                    phase = .failed(.cameraUnavailable)
                }
            }
        case .denied, .restricted:
            phase = .failed(.cameraUnavailable)
        @unknown default:
            phase = .failed(.cameraUnavailable)
        }
    }

    private static func failure(for error: Error) -> ImportFailure {
        if error is URLError { return .network }
        if error is KeychainStoreError { return .secureStorage }
        if error as? SubscriptionParserError == .surgeProfileContainsNoProxyPolicies {
            return .surgeProfileWithoutProxyPolicies
        }
        if error is SubscriptionParserError { return .unsupportedFormat }
        if error is RoutevaDatabaseError { return .localStorage }
        if error is RoutevaAppDataError { return .localStorage }
        if let loaderError = error as? SubscriptionPayloadLoaderError {
            switch loaderError {
            case .insecureRemoteURL, .invalidResponse, .responseTooLarge:
                return .providerResponse
            }
        }
        #if DEBUG
        logger.error(
            "Import failed category=unknown type=\(String(reflecting: type(of: error)), privacy: .public)"
        )
        #endif
        return .unknown
    }
}

private struct QRCodeScannerView: UIViewControllerRepresentable {
    let onRecognized: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onRecognized: onRecognized)
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        try? controller.startScanning()
        return controller
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    static func dismantleUIViewController(_ uiViewController: DataScannerViewController, coordinator: Coordinator) {
        uiViewController.stopScanning()
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onRecognized: (String) -> Void
        private var didRecognize = false

        init(onRecognized: @escaping (String) -> Void) {
            self.onRecognized = onRecognized
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            guard !didRecognize else { return }
            for item in addedItems {
                guard case let .barcode(barcode) = item,
                      let value = barcode.payloadStringValue,
                      !value.isEmpty
                else { continue }
                didRecognize = true
                onRecognized(value)
                return
            }
        }
    }
}

private struct ImportOptionButton: View {
    let title: String
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemName)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.70))
                Text(LocalizedStringKey(title))
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.white.opacity(0.82))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .routevaGlass(cornerRadius: 16)
        }
        .buttonStyle(RoutevaPressStyle())
    }
}

private struct ParsingOverlay: View {
    let label: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .background(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.12), .white.opacity(0.04)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                        .overlay(Circle().stroke(.white.opacity(0.14), lineWidth: 0.8))
                    ProgressView()
                        .tint(RoutevaTheme.mint)
                        .scaleEffect(1.15)
                }
                Text(label)
                    .font(.system(size: 17, weight: .bold))
            }
            .frame(maxWidth: 300)
            .padding(.vertical, 28)
            .padding(.horizontal, 24)
            .background(RoutevaSheetBackground())
            .routevaGlass(cornerRadius: 24)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.updatesFrequently)
    }
}

struct SubscriptionsView: View {
    @EnvironmentObject private var model: RoutevaAppModel
    @Environment(\.dismiss) private var dismiss
    @State private var renameTarget: SubscriptionSummary?
    @State private var renameText = ""
    @State private var deleteTarget: SubscriptionSummary?

    var body: some View {
        RoutevaField {
            VStack(spacing: 0) {
                RoutevaNavigationHeader(
                    title: "Subscriptions",
                    backSystemName: "xmark",
                    backLabel: "Close",
                    backAction: dismiss.callAsFunction
                )

                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(model.subscriptions) { subscription in
                            SubscriptionCard(
                                subscription: subscription,
                                isUpdating: model.updatingSubscriptionIDs.contains(subscription.id),
                                isDeleting: model.deletingSubscriptionIDs.contains(subscription.id),
                                setActive: { setActive(subscription.id) },
                                update: { Task { await model.updateSubscription(subscription.id) } },
                                delete: { deleteTarget = subscription },
                                rename: {
                                    renameTarget = subscription
                                    renameText = subscription.displayName
                                }
                            )
                        }
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 12)
                }

                RoutevaSecondaryButton(title: "Add subscription") {
                    dismiss()
                    model.presentedSurface = .addSubscription
                }
                .padding(.top, 14)
            }
            .padding(.horizontal, 22)
            .safeAreaPadding(.top, 4)
            .safeAreaPadding(.bottom, 12)
        }
        .overlay(alignment: .top) {
            if model.subscriptionUpdateFailureToast {
                SubscriptionUpdateFailureToast()
                    .padding(.horizontal, 22)
                    .padding(.top, 58)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task {
                        try? await Task.sleep(for: .seconds(2.5))
                        withAnimation(.routevaEase) { model.subscriptionUpdateFailureToast = false }
                    }
            }
        }
        .sheet(item: $renameTarget) { target in
            RenameSubscriptionSheet(name: $renameText) {
                let value = renameText
                renameTarget = nil
                Task { await model.renameSubscription(target.id, displayName: value) }
            }
            .presentationDetents([.height(282)])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(22)
            .presentationBackground { RoutevaSheetBackground() }
        }
        .confirmationDialog(
            "Delete subscription?",
            isPresented: Binding(
                get: { deleteTarget != nil },
                set: { if !$0 { deleteTarget = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let target = deleteTarget {
                Button("Delete \(target.displayName)", role: .destructive) {
                    deleteTarget = nil
                    Task { await model.deleteSubscription(target.id) }
                }
            }
            Button("Cancel", role: .cancel) { deleteTarget = nil }
        } message: {
            Text("This removes its nodes and saved credentials from this device.")
        }
    }

    private func setActive(_ id: UUID) {
        Task { @MainActor in
            await model.setActiveSubscription(id)
        }
    }
}

private struct SubscriptionCard: View {
    let subscription: SubscriptionSummary
    let isUpdating: Bool
    let isDeleting: Bool
    let setActive: () -> Void
    let update: () -> Void
    let delete: () -> Void
    let rename: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 2) {
                        Text(subscription.displayName)
                            .font(.system(size: subscription.isActive ? 20 : 17, weight: .bold))
                            .tracking(-0.4)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .layoutPriority(1)
                        Button(action: rename) {
                            Image(systemName: "pencil")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(RoutevaTheme.quiet)
                                .frame(width: 40, height: 40)
                                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(RoutevaPressStyle())
                        .accessibilityLabel("Rename subscription")
                        .offset(x: 2, y: -6)
                    }
                    Text("\(subscription.nodes.count) nodes")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(RoutevaTheme.secondary)
                    if let expiresAt = subscription.expiresAt {
                        Text(expiryText(expiresAt))
                            .font(.system(size: 13, weight: expiresAt < .now ? .semibold : .medium))
                            .foregroundStyle(expiresAt < .now ? RoutevaTheme.warning : RoutevaTheme.secondary)
                    }
                    Text("Updated \(subscription.lastUpdatedDescription)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(RoutevaTheme.muted)
                }

                Spacer()

                if subscription.isActive {
                    ActiveBadge()
                } else {
                    Button("Set active", action: setActive)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.72))
                        .frame(minWidth: 44, minHeight: 44)
                        .buttonStyle(RoutevaPressStyle())
                }
            }

            if subscription.isActive {
                if let used = subscription.usedGigabytes,
                   let total = subscription.totalGigabytes,
                   total > 0 {
                    TrafficUsageView(used: used, total: total)
                        .padding(.top, 12)
                }

                if !subscription.canUpdateAutomatically {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Can’t update automatically")
                            .font(.system(size: 13, weight: .bold))
                        Text("Import a new file or link when your provider changes this subscription.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(RoutevaTheme.muted)
                    }
                    .padding(.top, 14)
                }

            }

            HStack(spacing: 10) {
                if subscription.isActive && subscription.canUpdateAutomatically {
                    SubscriptionCardAction(
                        title: isUpdating ? "Updating…" : "Update",
                        systemName: isUpdating ? nil : "arrow.clockwise",
                        isEnabled: !isUpdating && !isDeleting,
                        action: update
                    )
                }

                SubscriptionCardAction(
                    title: isDeleting ? "Deleting…" : "Delete",
                    systemName: isDeleting ? nil : "trash",
                    isDestructive: true,
                    isEnabled: !isUpdating && !isDeleting,
                    action: delete
                )
            }
            .padding(.top, 14)
        }
        .padding(subscription.isActive ? 17 : 16)
        .background {
            if subscription.isActive {
                LinearGradient(
                    colors: [
                        Color(red: 40 / 255, green: 56 / 255, blue: 52 / 255).opacity(0.94),
                        Color(red: 18 / 255, green: 24 / 255, blue: 22 / 255).opacity(0.98),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .routevaGlass(cornerRadius: 20, highlighted: subscription.isActive)
    }

    private func expiryText(_ date: Date) -> String {
        let formatted = date.formatted(.dateTime.month(.abbreviated).day().year())
        return date < .now ? "Expired \(formatted)" : "Expires \(formatted)"
    }
}

private struct SubscriptionCardAction: View {
    let title: String
    let systemName: String?
    var isDestructive = false
    var isEnabled = true
    let action: () -> Void

    private var destructiveButton: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 1, green: 104 / 255, blue: 118 / 255),
                Color(red: 208 / 255, green: 48 / 255, blue: 66 / 255),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if let systemName { Image(systemName: systemName) }
                Text(LocalizedStringKey(title))
            }
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(
                isEnabled
                    ? (isDestructive ? Color.white : Color(red: 10 / 255, green: 31 / 255, blue: 24 / 255))
                    : RoutevaTheme.quiet
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                isEnabled
                    ? AnyShapeStyle(isDestructive ? destructiveButton : RoutevaTheme.mintButton)
                    : AnyShapeStyle(.white.opacity(0.06)),
                in: RoundedRectangle(cornerRadius: 15, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(
                        .white.opacity(isEnabled ? 0.16 : 0.08),
                        lineWidth: 0.8
                    )
            }
            .shadow(
                color: isEnabled
                    ? (isDestructive ? Color(red: 1, green: 82 / 255, blue: 100 / 255).opacity(0.24) : RoutevaTheme.mint.opacity(0.24))
                    : .clear,
                radius: 12,
                y: 7
            )
        }
        .buttonStyle(RoutevaPressStyle())
        .disabled(!isEnabled)
    }
}

private struct SubscriptionUpdateFailureToast: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark")
                .font(.system(size: 13, weight: .heavy))
                .frame(width: 28, height: 28)
                .background(RoutevaTheme.warning, in: Circle())
            Text("Couldn’t update. Your existing subscription was kept.")
                .font(.system(size: 13, weight: .bold))
            Spacer()
        }
        .padding(12)
        .routevaToast(cornerRadius: 16)
        .accessibilityIdentifier("subscriptions.updateFailureToast")
    }
}

private struct RenameSubscriptionSheet: View {
    @Binding var name: String
    let save: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Capsule()
                .fill(.white.opacity(0.20))
                .frame(width: 36, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 2)
            Text("Rename")
                .font(.system(size: 17, weight: .bold))
            Text("Display name only — doesn’t change your provider subscription.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(RoutevaTheme.muted)
            TextField("Name", text: $name)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .padding(14)
                .routevaGlass(cornerRadius: 14)
            HStack(spacing: 10) {
                RoutevaSecondaryButton(title: "Cancel", action: dismiss.callAsFunction)
                RoutevaPrimaryButton(title: "Save", action: save)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 16)
        .preferredColorScheme(.dark)
    }
}

private struct ActiveBadge: View {
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(RoutevaTheme.mint)
                .frame(width: 6, height: 6)
                .shadow(color: RoutevaTheme.mint.opacity(0.7), radius: 4)
            Text("ACTIVE")
        }
        .font(.system(size: 12, weight: .bold))
        .tracking(0.5)
        .foregroundStyle(Color(red: 180 / 255, green: 240 / 255, blue: 210 / 255))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(RoutevaTheme.mint.opacity(0.16), in: Capsule())
        .overlay(Capsule().stroke(RoutevaTheme.mint.opacity(0.35), lineWidth: 0.7))
    }
}

private struct TrafficUsageView: View {
    let used: Double
    let total: Double

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Data")
                    .foregroundStyle(RoutevaTheme.secondary)
                Spacer()
                Text("\(used, format: .number.precision(.fractionLength(1))) / \(total, format: .number.precision(.fractionLength(0))) GB")
                    .fontWeight(.semibold)
            }
            .font(.system(size: 13, weight: .medium))

            GeometryReader { proxy in
                Capsule().fill(.white.opacity(0.08))
                Capsule()
                    .fill(RoutevaTheme.mintButton)
                    .frame(width: proxy.size.width * min(1, used / total))
            }
            .frame(height: 7)
            .accessibilityLabel("Data used")
            .accessibilityValue("\(Int(used / total * 100)) percent")
        }
    }
}
