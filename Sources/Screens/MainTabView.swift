import SwiftUI

/// The unlocked app shell: a bottom tab bar (iOS-native). The five primary screens
/// are Übersicht, Monatsplanung, Rechnungen, Sparen, and Mehr (which hosts Schulden,
/// Erkenntnisse, Einstellungen, and Problem melden).
struct MainTabView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var loc: Localizer

    var body: some View {
        TabView(selection: $model.selectedTab) {
            OverviewView()
                .tabItem { Label(loc(.overviewTitle), systemImage: "square.grid.2x2") }.tag(0)
            PlanningView()
                .tabItem { Label(loc(.planningTitle), systemImage: "calendar") }.tag(1)
            BillsView()
                .tabItem { Label(loc(.billsTitle), systemImage: "doc.text") }.tag(2)
            SparenView()
                .tabItem { Label(loc(.navSparen), systemImage: "banknote") }.tag(3)
            MoreTab()
                .tabItem { Label("Mehr", systemImage: "ellipsis.circle") }.tag(4)
        }
    }
}

/// "Mehr" tab — a list that pushes Schulden, Erkenntnisse, Einstellungen, and
/// Problem melden, plus the lock action.
private struct MoreTab: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var loc: Localizer

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        SchuldenView()
                    } label: {
                        Label(loc(.navSchulden), systemImage: "creditcard")
                    }
                    NavigationLink {
                        ComingSoon(title: loc(.navInsights), icon: "lightbulb")
                    } label: {
                        Label(loc(.navInsights), systemImage: "lightbulb")
                    }
                    NavigationLink {
                        ComingSoon(title: loc(.navSettings), icon: "gearshape")
                    } label: {
                        Label(loc(.navSettings), systemImage: "gearshape")
                    }
                    NavigationLink {
                        ComingSoon(title: loc(.navReport), icon: "exclamationmark.bubble")
                    } label: {
                        Label(loc(.navReport), systemImage: "exclamationmark.bubble")
                    }
                }
                Section {
                    Button(role: .destructive) {
                        Task { await model.lock() }
                    } label: {
                        Label("Sperren", systemImage: "lock")
                    }
                }
            }
            .tint(KontivaTheme.accent)
            .navigationTitle("Mehr")
        }
    }
}

/// Temporary placeholder for screens not yet ported.
private struct ComingSoon: View {
    let title: String
    let icon: String
    var body: some View {
        VStack(spacing: KontivaTheme.Space.sm) {
            Image(systemName: icon).font(.system(size: 44)).foregroundStyle(KontivaTheme.accent)
            Text(title).font(.title2.bold()).foregroundStyle(KontivaTheme.textPrimary)
            Text("In Arbeit").font(.callout).foregroundStyle(KontivaTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KontivaTheme.pageGradient.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
