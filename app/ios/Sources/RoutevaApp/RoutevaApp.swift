import SwiftUI

@main
struct RoutevaApp: App {
    @StateObject private var model = RoutevaAppModel()

    var body: some Scene {
        WindowGroup {
            RoutevaRootView()
                .environmentObject(model)
                .preferredColorScheme(.dark)
        }
    }
}

private struct RoutevaRootView: View {
    @EnvironmentObject private var model: RoutevaAppModel

    var body: some View {
        Group {
            switch model.onboardingStep {
            case .welcome:
                WelcomeView {
                    model.onboardingStep = .dataAndPrivacy
                }
            case .dataAndPrivacy:
                DataAndPrivacyView {
                    model.completeOnboarding()
                }
            case .complete:
                HomeView()
            }
        }
        .animation(.routevaEase, value: model.onboardingStep)
    }
}
