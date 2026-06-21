import SwiftUI

/// Top-level gate: first run → onboarding, existing vault → lock, unlocked → app.
struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ZStack {
            KontivaTheme.pageBackground.ignoresSafeArea()
            switch model.lockState {
            case .needsSetup: OnboardingView()
            case .locked:     LockView()
            case .unlocked:   MainTabView()
            }
        }
    }
}
