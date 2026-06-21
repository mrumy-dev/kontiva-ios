import SwiftUI

/// The iOS Kontiva app. Reuses the shared KontivaKit engine (model, crypto,
/// encrypted storage) and presents a touch-native UI on top.
@main
struct KontivaApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .tint(KontivaTheme.accent)
        }
    }
}
