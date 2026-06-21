import SwiftUI

/// The unlocked app shell: a bottom tab bar (iOS-native) with a NavigationStack per
/// tab. Screens are placeholders for now — each gets ported from the desktop one,
/// reusing the shared engine, in a later phase.
struct MainTabView: View {
    var body: some View {
        TabView {
            placeholder("Übersicht", "square.grid.2x2")
                .tabItem { Label("Übersicht", systemImage: "square.grid.2x2") }
            placeholder("Planung", "calendar")
                .tabItem { Label("Planung", systemImage: "calendar") }
            placeholder("Rechnungen", "doc.text")
                .tabItem { Label("Rechnungen", systemImage: "doc.text") }
            placeholder("Sparen", "banknote")
                .tabItem { Label("Sparen", systemImage: "banknote") }
            MoreTab()
                .tabItem { Label("Mehr", systemImage: "ellipsis.circle") }
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
