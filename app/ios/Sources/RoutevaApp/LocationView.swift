import SwiftUI

struct LocationView: View {
    @EnvironmentObject private var model: RoutevaAppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        RoutevaField {
            VStack(spacing: 0) {
                RoutevaNavigationHeader(
                    title: "Node list",
                    backSystemName: "chevron.left",
                    backLabel: "Back",
                    backAction: dismiss.callAsFunction
                ) {
                    LocationTestButton(
                        isTesting: model.isTestingNodes,
                        isEnabled: model.canStartLocationLatencyTest,
                        action: { Task { await model.testNodeLatencies() } }
                    )
                }
                .accessibilityIdentifier("location.screen")

                ScrollView {
                    let nodes = model.locationDisplayNodes
                    if nodes.isEmpty {
                        LocationEmptyState()
                            .frame(maxWidth: .infinity, minHeight: 420)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
                                LocationRow(
                                    node: node,
                                    latency: model.nodeLatencies[node.id],
                                    isPreferred: node.id == model.activeSubscription?.preferredNodeID
                                ) {
                                    Task { @MainActor in
                                        await model.selectPreferredNode(id: node.id)
                                        dismiss()
                                    }
                                }
                                .accessibilityIdentifier("location.node.\(index)")

                                if index < nodes.count - 1 {
                                    Rectangle()
                                        .fill(.white.opacity(0.065))
                                        .frame(height: 0.7)
                                        .padding(.leading, 16)
                                }
                            }
                        }
                        .routevaGlass(cornerRadius: 20)
                        .padding(.top, 6)
                    }
                }
            }
            .padding(.horizontal, 22)
            .safeAreaPadding(.top, 4)
            .safeAreaPadding(.bottom, 12)
            .overlay(alignment: .top) {
                if model.latencyTestUnavailableToast {
                    LocationLatencyUnavailableToast()
                        .padding(.top, 58)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .task {
                            try? await Task.sleep(for: .seconds(2.5))
                            guard model.latencyTestUnavailableToast else { return }
                            withAnimation(.routevaEase) { model.latencyTestUnavailableToast = false }
                        }
                }
            }
        }
        .onDisappear {
            model.cancelLocationLatencyTest()
        }
    }
}

private struct LocationLatencyUnavailableToast: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Color(red: 37 / 255, green: 20 / 255, blue: 15 / 255))
                .frame(width: 28, height: 28)
                .background(RoutevaTheme.warning, in: Circle())
            Text("Couldn’t test latency on this connection.")
                .font(.system(size: 14, weight: .bold))
            Spacer()
        }
        .padding(12)
        .routevaToast(cornerRadius: 16)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("location.test.unavailable")
    }
}

private struct LocationTestButton: View {
    let isTesting: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if isTesting {
                    ProgressView()
                        .controlSize(.small)
                        .tint(RoutevaTheme.mint)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                }
                Text(isTesting ? "Testing…" : "Test")
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(isTesting ? RoutevaTheme.mint : RoutevaTheme.primary)
            .padding(.horizontal, 12)
            .frame(minHeight: 36)
            .routevaGlass(cornerRadius: 999, highlighted: isTesting)
        }
        .buttonStyle(RoutevaPressStyle())
        .disabled(isTesting || !isEnabled)
        .accessibilityIdentifier("location.test")
        .accessibilityLabel(isTesting ? "Testing latency" : "Test latency")
    }
}

private struct LocationRow: View {
    let node: NodeSummary
    let latency: NodeLatencyStatus?
    let isPreferred: Bool
    let action: () -> Void

    private var latencyText: String {
        latency?.label ?? "Not tested"
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(node.flag)
                    .font(.system(size: 18))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(node.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(RoutevaTheme.primary)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(node.protocolName)
                        Text("·")
                            .foregroundStyle(RoutevaTheme.quiet)
                        Text(latencyText)
                            .foregroundStyle(latency == .unavailable ? RoutevaTheme.warning : RoutevaTheme.secondary)
                    }
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(RoutevaTheme.mint)
                    .opacity(isPreferred ? 1 : 0)
                    .frame(width: 22, height: 22)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(isPreferred ? RoutevaTheme.mint.opacity(0.09) : .clear)
            .contentShape(Rectangle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .buttonStyle(RoutevaPressStyle())
        .accessibilityLabel("\(node.name), \(node.protocolName), \(latencyText)")
        .accessibilityValue(isPreferred ? String(localized: "Selected") : "")
    }
}

private struct LocationEmptyState: View {
    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "list.bullet")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(RoutevaTheme.quiet)
                .frame(width: 56, height: 56)
                .background(.white.opacity(0.06), in: Circle())
            Text("No nodes in this subscription")
                .font(.system(size: 20, weight: .bold))
                .padding(.top, 16)
            Text("Update your subscription or pick another one with nodes.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(RoutevaTheme.muted)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.top, 8)
                .frame(maxWidth: 260)
        }
    }
}
