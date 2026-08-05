import SwiftUI

/// Root: Welcome (once) → Home shell. ADR 0019 / 0020.
struct RootView: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        Group {
            if !app.hasCompletedWelcome {
                WelcomeView()
            } else {
                HomeView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: app.hasCompletedWelcome)
    }
}
