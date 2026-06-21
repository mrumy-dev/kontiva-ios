import SwiftUI

/// The iOS Kontiva app. Reuses the shared KontivaKit engine (model, crypto,
/// encrypted storage) and presents a touch-native UI on top.
@main
struct KontivaApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .environmentObject(model.localizer)
                .tint(KontivaTheme.accent)
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .background: model.appDidEnterBackground()
                    case .active:     model.appWillEnterForeground()
                    default:          break
                    }
                }
        }
    }
}
