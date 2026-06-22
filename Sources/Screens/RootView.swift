import SwiftUI

/// Top-level gate: first run → onboarding, existing vault → lock, unlocked → app.
struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var loc: Localizer

    var body: some View {
        ZStack {
            KontivaTheme.pageBackground.ignoresSafeArea()
            switch model.lockState {
            case .needsSetup: OnboardingView()
            case .locked:     LockView()
            case .unlocked:   MainTabView()
            }
        }
        // Mirror the whole UI for right-to-left scripts (Arabic, Urdu, Pashto).
        // `loc` republishes on language change, so this updates live.
        .environment(\.layoutDirection, loc.language.isRTL ? .rightToLeft : .leftToRight)
    }
}
