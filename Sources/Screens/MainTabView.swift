import SwiftUI

/// The unlocked app shell: a bottom tab bar (iOS-native) with a NavigationStack per
/// tab. Screens are placeholders for now — each gets ported from the desktop one,
/// reusing the shared engine, in a later phase.
struct MainTabView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var loc: Localizer

    var body: some View {
        TabView(selection: $model.selectedTab) {
            OverviewView()
                .tabItem { Label(loc(.overviewTitle), systemImage: "square.grid.2x2") }.tag(0)
            PlanningView()
                .tabItem { Label(loc(.planningTitle), systemImage: "calendar") }.tag(1)
            placeholder(loc(.billsTitle), "doc.text")
                .tabItem { Label(loc(.billsTitle), systemImage: "doc.text") }.tag(2)
            placeholder(loc(.navSparen), "banknote")
                .tabItem { Label(loc(.navSparen), systemImage: "banknote") }.tag(3)
            MoreTab()
                .tabItem { Label("Mehr", systemImage: "ellipsis.circle") }.tag(4)
        }
    }

    private func placeholder(_ title: String, _ icon: String) -> some View {
        NavigationStack {
            VStack(spacing: KontivaTheme.Space.sm) {
                Image(systemName: icon).font(.system(size: 44)).foregroundStyle(KontivaTheme.accent)
                Text(title).font(.title2.bold()).foregroundStyle(KontivaTheme.textPrimary)
                Text("In Arbeit").font(.callout).foregroundStyle(KontivaTheme.textSecondary)
            }
            .navigationTitle(title)
        }
    }
}

/// "More" tab — currently just a lock action; will host Insights, Schulden,
/// Settings, and Problem melden.
private struct MoreTab: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("Erkenntnisse", systemImage: "lightbulb")
                    Label("Schulden", systemImage: "creditcard")
                    Label("Einstellungen", systemImage: "gearshape")
                    Label("Problem melden", systemImage: "exclamationmark.bubble")
                }
                Section {
                    Button(role: .destructive) {
                        Task { await model.lock() }
                    } label: {
                        Label("Sperren", systemImage: "lock")
                    }
                }
            }
            .navigationTitle("Mehr")
        }
    }
}
