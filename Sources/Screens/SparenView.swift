import SwiftUI
import KontivaCore

/// Sparen: recurring savings pots. Each pot has a category and a monthly
/// contribution; the accumulated balance is derived from how long it has been
/// running. Card-based, ported from the desktop for iOS.
struct SparenView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var loc: Localizer
    @State private var editing: SheetBox?

    private var month: Date { model.selectedMonth }

    var body: some View {
        NavigationStack {
            Group {
                if model.savingsGoals.isEmpty {
                    ScreenScroll {
                        KontivaCard {
                            EmptyState(systemImage: "banknote",
                                       title: loc(.navSparen),
                                       message: loc(.sparenEmpty),
                                       actionTitle: loc(.sparenAddCta)) { editing = SheetBox(goal: nil) }
                        }
                    }
                } else {
                    ScreenScroll {
                        MonthSelector().frame(maxWidth: .infinity, alignment: .center)
                        summaryCard
                        ForEach(Array(model.savingsGoals.enumerated()), id: \.element.id) { idx, goal in
                            goalCard(goal, at: idx)
                        }
                    }
                    .animation(.snappy, value: model.dataset)
                }
            }
            .background(KontivaTheme.pageGradient.ignoresSafeArea())
            .navigationTitle(loc(.navSparen))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { editing = SheetBox(goal: nil) } label: { Image(systemName: "plus") }
                        .tint(KontivaTheme.accent)
                        .symbolEffect(.bounce, value: model.savingsGoals.count)
                }
            }
            .sheet(item: $editing) { box in
                SavingsGoalFormSheet(existing: box.goal).environmentObject(model).environmentObject(loc)
            }
        }
    }

    private var summaryCard: some View {
        KontivaCard {
            VStack(alignment: .leading, spacing: KontivaTheme.Space.md) {
                HStack(spacing: KontivaTheme.Space.sm) {
                    KontivaIconTile("banknote.fill", color: KontivaTheme.positive)
                    VStack(alignment: .leading, spacing: 1) {
                        CardTitle(loc(.sparenAccumulatedTotal))
                        Text(model.totalAccumulatedSavings.formattedCHF())
                            .font(.title2.weight(.semibold)).monospacedDigit()
                            .contentTransition(.numericText())
                            .foregroundStyle(KontivaTheme.positive)
                    }
                    Spacer(minLength: 0)
                }
                Divider()
                HStack(spacing: KontivaTheme.Space.lg) {
                    SummaryStat(loc(.sparenMonthlyTotal), value: model.totalMonthlySavings.formattedCHF(),
                                color: KontivaTheme.accent)
                    SummaryStat(loc(.sparenGoalsLabel), value: "\(model.savingsGoals.count)")
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func goalCard(_ goal: SavingsGoal, at idx: Int) -> some View {
        let accumulated = goal.accumulated(asOf: month)
        let months = goal.monthsContributed(asOf: month)
        return KontivaCard {
            VStack(alignment: .leading, spacing: KontivaTheme.Space.md) {
                HStack(spacing: KontivaTheme.Space.sm) {
                    KontivaIconTile(goal.category.systemImage)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(goal.name).font(.title3.weight(.semibold)).foregroundStyle(KontivaTheme.textPrimary)
                        Text(goal.category.localizedName(loc.localization))
                            .font(.caption).foregroundStyle(KontivaTheme.textTertiary)
                    }
                    Spacer(minLength: KontivaTheme.Space.sm)
                    VStack(alignment: .trailing, spacing: 0) {
                        Text((goal.monthlyContribution ?? .zero).formattedCHF())
                            .font(.title3.weight(.semibold)).monospacedDigit()
                            .foregroundStyle(KontivaTheme.textPrimary)
                        Text(loc(.sparenPerMonth)).font(.caption2).foregroundStyle(KontivaTheme.textTertiary)
                    }
                }
                Divider().background(KontivaTheme.softBorder.opacity(0.4))
                HStack(alignment: .center, spacing: KontivaTheme.Space.md) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(loc(.sparenAccumulatedTotal)).font(.caption).foregroundStyle(KontivaTheme.textSecondary)
                        Text("\(months) \(loc(.sparenContributions)) · \(loc(.sparenSince)) \(monthLabel(goal.startDate))")
                            .font(.caption2).foregroundStyle(KontivaTheme.textTertiary)
                    }
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(accumulated.formattedCHF())
                            .font(.title3.bold()).monospacedDigit().contentTransition(.numericText())
                            .foregroundStyle(KontivaTheme.positive)
                        if goal.hasTarget {
                            Text("\(loc(.formTarget)): \(goal.target.formattedCHF())")
                                .font(.caption2).foregroundStyle(KontivaTheme.textTertiary)
                        } else {
                            Text(loc(.sparenOpenEnded)).font(.caption2).foregroundStyle(KontivaTheme.textTertiary)
                        }
                    }
                    if goal.hasTarget {
                        ProgressRing(progress: Double(goal.progressPercent(asOf: month)) / 100)
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { editing = SheetBox(goal: goal) }
        .contextMenu {
            Button(loc(.commonEdit), systemImage: "pencil") { editing = SheetBox(goal: goal) }
            if idx > 0 {
                Button(loc(.commonMoveUp), systemImage: "arrow.up") {
                    Task { await model.moveSavingsGoals(from: IndexSet(integer: idx), to: idx - 1) }
                }
            }
            if idx < model.savingsGoals.count - 1 {
                Button(loc(.commonMoveDown), systemImage: "arrow.down") {
                    Task { await model.moveSavingsGoals(from: IndexSet(integer: idx), to: idx + 2) }
                }
            }
            Button(loc(.commonDelete), systemImage: "trash", role: .destructive) {
                Task { await model.deleteSavingsGoal(goal.id) }
            }
        }
    }

    private func monthLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = loc.language.locale; f.calendar = .swiss
        f.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return f.string(from: date)
    }
}

/// Identifiable wrapper so the add/edit sheet (nil = "new") works with `.sheet(item:)`.
private struct SheetBox: Identifiable {
    let goal: SavingsGoal?
    var id: String { goal?.id.uuidString ?? "new" }
}
