import SwiftUI

struct SettingsView: View {
    private enum Screen: Equatable {
        case root
        case routing
        case dns
        case overrides
        case about
    }

    @EnvironmentObject private var model: RoutevaAppModel
    @Environment(\.dismiss) private var dismiss
    @State private var screen: Screen = .root
    @State private var showsAddOverride = false

    var body: some View {
        RoutevaField {
            Group {
                switch screen {
                case .root:
                    settingsRoot
                case .routing:
                    picker(
                        title: "Routing mode",
                        values: RoutingMode.allCases,
                        selection: Binding(
                            get: { model.routingMode },
                            set: { model.setRoutingMode($0) }
                        ),
                        titleFor: \.rawValue,
                        detailFor: \.detail
                    )
                case .dns:
                    picker(
                        title: "DNS",
                        values: DNSPreset.allCases,
                        selection: $model.dnsPreset,
                        titleFor: \.rawValue,
                        detailFor: \.detail
                    )
                case .overrides:
                    overridesScreen
                case .about:
                    AboutView { screen = .root }
                }
            }
            .padding(.horizontal, 22)
            .safeAreaPadding(.top, 4)
            .safeAreaPadding(.bottom, 12)
            .animation(.routevaEase, value: screen)
        }
        .sheet(isPresented: $showsAddOverride) {
            AddOverrideSheet { value in
                showsAddOverride = false
                Task { await model.saveOverride(domain: value.domain, action: value.action) }
            }
            .presentationDetents([.height(390)])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(28)
            .presentationBackground { RoutevaSheetBackground() }
        }
        .onChange(of: screen) { _, value in
            if value == .overrides { Task { await model.syncOverrides() } }
        }
        .alert("Apply override changes?", isPresented: $model.overrideReconnectPrompt) {
            Button("Apply and reconnect") { model.applyOverrideChangesAndReconnect() }
            Button("Later", role: .cancel) { model.overrideReconnectPrompt = false }
        } message: {
            Text("The current connection keeps its existing routes until you reconnect.")
        }
    }

    private var settingsRoot: some View {
        VStack(spacing: 0) {
            RoutevaNavigationHeader(
                title: "Settings",
                backSystemName: "xmark",
                backLabel: "Close",
                backAction: dismiss.callAsFunction
            )

            ScrollView {
                VStack(spacing: 0) {
                    RoutevaSectionLabel(title: "Connection")
                        .padding(.top, 6)
                        .padding(.bottom, 8)
                    SettingsGroup {
                        SettingsRow(
                            title: "Routing mode",
                            subtitle: "How traffic uses your proxy",
                            value: model.routingMode.rawValue
                        ) { screen = .routing }
                        SettingsDivider()
                        SettingsRow(
                            title: "DNS",
                            subtitle: "How names resolve on your connection",
                            value: model.dnsPreset.rawValue
                        ) { screen = .dns }
                        SettingsDivider()
                        SettingsRow(
                            title: "Overrides",
                            subtitle: "Exceptions for specific domains",
                            value: model.overrides.isEmpty ? "None" : "\(model.overrides.count)"
                        ) { screen = .overrides }
                    }

                    RoutevaSectionLabel(title: "App")
                        .padding(.top, 20)
                        .padding(.bottom, 8)
                    SettingsGroup {
                        AutoUpdateRow(isOn: Binding(
                            get: { model.autoUpdateEnabled },
                            set: { model.setAutoUpdateEnabled($0) }
                        ))
                        SettingsDivider()
                        SettingsRow(
                            title: "Subscriptions",
                            value: model.activeSubscription?.displayName
                        ) {
                            dismiss()
                            model.presentedSurface = .subscriptions
                        }
                        SettingsDivider()
                        SettingsRow(title: "About") { screen = .about }
                    }
                }
            }
        }
    }

    private func picker<Value: Identifiable & Equatable>(
        title: String,
        values: [Value],
        selection: Binding<Value>,
        titleFor: KeyPath<Value, String>,
        detailFor: KeyPath<Value, String>
    ) -> some View {
        VStack(spacing: 0) {
            RoutevaNavigationHeader(
                title: title,
                backSystemName: "chevron.left",
                backLabel: "Back"
            ) { screen = .root }

            SettingsGroup {
                ForEach(Array(values.enumerated()), id: \.element.id) { index, value in
                    Button {
                        selection.wrappedValue = value
                    } label: {
                        HStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(LocalizedStringKey(value[keyPath: titleFor]))
                                    .font(.system(size: 16, weight: selection.wrappedValue == value ? .bold : .semibold))
                                Text(LocalizedStringKey(value[keyPath: detailFor]))
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(RoutevaTheme.secondary)
                            }
                            Spacer()
                            if selection.wrappedValue == value {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(RoutevaTheme.mint)
                            }
                        }
                        .foregroundStyle(RoutevaTheme.primary)
                        .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
                        .padding(.horizontal, 16)
                        .background(selection.wrappedValue == value ? RoutevaTheme.mint.opacity(0.09) : .clear)
                        .contentShape(Rectangle())
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .buttonStyle(RoutevaPressStyle())

                    if index < values.count - 1 { SettingsDivider() }
                }
            }
            .padding(.top, 6)

            Spacer()
        }
    }

    private var overridesScreen: some View {
        VStack(spacing: 0) {
            RoutevaNavigationHeader(
                title: "Overrides",
                backSystemName: "chevron.left",
                backLabel: "Back"
            ) { screen = .root }

            if model.overrides.isEmpty {
                VStack(spacing: 0) {
                    Spacer()
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.48))
                        .frame(width: 48, height: 48)
                        .routevaGlass(cornerRadius: 14)
                    Text("No exceptions yet")
                        .font(.system(size: 22, weight: .bold))
                        .padding(.top, 20)
                    Text("Pin a domain to proxy or direct when the default mode isn’t enough.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(RoutevaTheme.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.top, 12)
                        .frame(maxWidth: 280)
                    Text("A few exceptions, not a full rule set.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(RoutevaTheme.muted)
                        .padding(.top, 8)
                    Text("One domain each")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(RoutevaTheme.muted)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .routevaGlass(cornerRadius: 999)
                        .padding(.top, 18)
                    Spacer()
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Domain exceptions apply in Smart, Global, and Direct — not a full rule set.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(RoutevaTheme.muted)
                            .lineSpacing(2)
                            .padding(.horizontal, 4)
                        Text("Each exception matches one exact domain inside the tunnel. Proxy uses your current Routeva node.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(RoutevaTheme.warning.opacity(0.86))
                            .lineSpacing(2)
                            .padding(.horizontal, 4)

                        ForEach(model.overrides) { item in
                            OverrideCard(
                                item: item,
                                setEnabled: { enabled in
                                    Task { await model.setOverrideEnabled(domain: item.domain, enabled: enabled) }
                                },
                                remove: {
                                    Task { await model.deleteOverride(domain: item.domain) }
                                }
                            )
                        }
                    }
                    .padding(.top, 6)
                }
            }

            RoutevaPrimaryButton(title: "Add exception") {
                showsAddOverride = true
            }
            .padding(.top, 12)
        }
    }
}

private struct SettingsGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .routevaGlass(cornerRadius: 20)
    }
}

private struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(.white.opacity(0.065))
            .frame(height: 0.7)
            .padding(.leading, 16)
    }
}

private struct AutoUpdateRow: View {
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Auto-update subscription")
                    .font(.system(size: 16, weight: .medium))
                Text("When you launch the app, refresh the active subscription about once a day")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(RoutevaTheme.muted)
                    .lineSpacing(2)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(RoutevaTheme.mint)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 64)
    }
}

private struct SettingsRow: View {
    let title: String
    var subtitle: String?
    var value: String?
    let action: () -> Void

    init(
        title: String,
        subtitle: String? = nil,
        value: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.value = value
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(LocalizedStringKey(title))
                        .font(.system(size: 16, weight: .medium))
                    if let subtitle {
                        Text(LocalizedStringKey(subtitle))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(RoutevaTheme.muted)
                    }
                }
                Spacer()
                HStack(spacing: 7) {
                    if let value, !value.isEmpty {
                        Text(LocalizedStringKey(value))
                            .lineLimit(1)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .opacity(0.5)
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(RoutevaTheme.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: subtitle == nil ? 52 : 64)
            .padding(.horizontal, 16)
            .foregroundStyle(RoutevaTheme.primary)
            .contentShape(Rectangle())
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .buttonStyle(RoutevaPressStyle())
    }
}

private struct OverrideCard: View {
    let item: DomainOverrideSummary
    let setEnabled: (Bool) -> Void
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                Text(item.domain)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
                Text(item.action == .proxy ? "Via proxy" : "Direct")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(item.action == .proxy ? RoutevaTheme.mint : RoutevaTheme.muted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(item.action == .proxy ? RoutevaTheme.mint.opacity(0.16) : .white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
            }
            Spacer()
            Button {
                setEnabled(!item.isEnabled)
            } label: {
                Capsule()
                    .fill(item.isEnabled ? RoutevaTheme.mint : Color.white.opacity(0.14))
                    .frame(width: 50, height: 30)
                    .overlay(alignment: item.isEnabled ? .trailing : .leading) {
                        Circle()
                            .fill(item.isEnabled ? Color(red: 10 / 255, green: 31 / 255, blue: 24 / 255) : .white.opacity(0.78))
                            .frame(width: 24, height: 24)
                            .padding(3)
                    }
            }
                .buttonStyle(RoutevaPressStyle())
                .accessibilityLabel("\(item.domain) enabled")
                .accessibilityValue(item.isEnabled ? "On" : "Off")
            Button(action: remove) {
                Image(systemName: "xmark")
                    .foregroundStyle(RoutevaTheme.muted)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(RoutevaPressStyle())
            .accessibilityLabel("Remove \(item.domain)")
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .padding(.vertical, 12)
        .opacity(item.isEnabled ? 1 : 0.55)
        .routevaGlass(cornerRadius: 18)
    }
}

private struct AddOverrideSheet: View {
    let save: (DomainOverrideSummary) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var domain = ""
    @State private var action: DomainOverrideSummary.Action = .proxy

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Capsule()
                .fill(.white.opacity(0.20))
                .frame(width: 36, height: 4)
                .frame(maxWidth: .infinity)
            HStack {
                Text("Add exception")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Button("Cancel") { dismiss() }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(RoutevaTheme.mint)
            }

            Text("One domain per exception.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(RoutevaTheme.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("DOMAIN")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(0.7)
                    .foregroundStyle(RoutevaTheme.muted)
                TextField("example.com", text: $domain)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .font(.system(size: 16, weight: .medium))
                    .padding(14)
                    .routevaGlass(cornerRadius: 14)
            }

            Picker("Action", selection: $action) {
                ForEach(DomainOverrideSummary.Action.allCases) { value in
                    Text(value.rawValue).tag(value)
                }
            }
            .pickerStyle(.segmented)

            Text(action == .proxy ? "Send this domain through the proxy." : "Bypass the proxy for this domain.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(RoutevaTheme.muted)
                .lineSpacing(2)

            RoutevaPrimaryButton(title: "Save exception", isEnabled: isValidDomain) {
                save(DomainOverrideSummary(
                    id: UUID(),
                    domain: normalizedDomain,
                    action: action,
                    isEnabled: true
                ))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 28)
        .foregroundStyle(RoutevaTheme.primary)
    }

    private var normalizedDomain: String {
        domain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var isValidDomain: Bool {
        let value = normalizedDomain
        return value.contains(".") && !value.contains("/") && !value.contains(":") && !value.contains(" ")
    }
}

private struct AboutView: View {
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var model: RoutevaAppModel
    let back: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            RoutevaNavigationHeader(
                title: "About",
                backSystemName: "chevron.left",
                backLabel: "Back",
                backAction: back
            )

            ScrollView {
                VStack(spacing: 18) {
                    VStack(spacing: 12) {
                        Text("Routeva")
                            .font(.system(size: 28, weight: .bold))
                        Text(versionText)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(RoutevaTheme.secondary)
                        Text("Privacy first. No analytics, ads, cloud help, or third-party crash SDK in this Beta.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(RoutevaTheme.muted)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                        Text("On iPhone, domain exceptions may back up to your iCloud for reinstalls and device switches.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(RoutevaTheme.muted)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 24)
                    .routevaGlass(cornerRadius: 20)

                    SettingsGroup {
                        SettingsRow(title: "Privacy Policy", subtitle: "How we handle your data") {
                            openURL(URL(string: "https://routeva.yilinglabs.com/privacy/")!)
                        }
                        SettingsDivider()
                        SettingsRow(title: "Terms of Use", subtitle: "Rules for using Routeva") {
                            openURL(URL(string: "https://routeva.yilinglabs.com/terms/")!)
                        }
                        SettingsDivider()
                        SettingsRow(title: "Source code", subtitle: "Routeva is GPL-3.0-or-later") {
                            openURL(URL(string: "https://github.com/Yiling-Labs/Routeva")!)
                        }
                        SettingsDivider()
                        SettingsRow(title: "Open-source licenses", subtitle: "License and third-party notices") {
                            openURL(URL(string: "https://github.com/Yiling-Labs/Routeva/blob/main/LICENSE")!)
                        }
                        SettingsDivider()
                        SettingsRow(title: "Support") {
                            openURL(URL(string: "https://routeva.yilinglabs.com/privacy/#contact")!)
                        }
                    }

                    Text("Some interface text may be machine-translated. Critical explanations stay in English.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(RoutevaTheme.quiet)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .frame(maxWidth: 290)

                    ShareLink(item: model.redactedDiagnosticReport) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export diagnostic report")
                        }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(RoutevaTheme.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .routevaGlass(cornerRadius: 18)
                    }
                    .buttonStyle(RoutevaPressStyle())

                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "Version \(version) (\(build))"
    }
}
