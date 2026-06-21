import SwiftUI
import KontivaCore

/// Erkenntnisse: rule-based observations about the current budget — where money
/// concentrates, ratios vs Swiss guidelines, and gentle tips. No judgement, no
/// advice claims. Pushed inside the "Mehr" tab's navigation stack.
struct InsightsView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var loc: Localizer

    var body: some View {
        Group {
            if model.insights.isEmpty {
                ScreenScroll {
                    KontivaCard {
                        EmptyState(systemImage: "lightbulb",
                                   title: loc(.navInsights),
                                   message: loc(.overviewEmpty))
                    }
                }
            } else {
                ScreenScroll {
                    ForEach(model.insights) { insight in
                        insightCard(insight)
                    }
                }
                .animation(.snappy, value: model.dataset)
            }
        }
        .background(KontivaTheme.pageGradient.ignoresSafeArea())
        .navigationTitle(loc(.navInsights))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { MonthSelector() } }
    }

    private func insightCard(_ insight: Insight) -> some View {
        let c = content(for: insight)
        return KontivaCard {
            HStack(alignment: .top, spacing: KontivaTheme.Space.md) {
                Image(systemName: c.icon).font(.title3).foregroundStyle(c.color).frame(width: 26)
                VStack(alignment: .leading, spacing: KontivaTheme.Space.xxs) {
                    Text(c.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(KontivaTheme.textPrimary)
                    Text(c.detail).font(.callout).foregroundStyle(KontivaTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func content(for insight: Insight) -> (icon: String, color: Color, title: String, detail: String) {
        func pctIncome(_ p: Int) -> String { "\(p)% \(loc(.fragOfNetIncome))" }

        switch insight {
        case .overspending(let deficit):
            return ("exclamationmark.triangle.fill", KontivaTheme.swissRed,
                    loc(.insightOverspending), "\(loc(.fragShortfall)): \(deficit.formattedCHF())")
        case .tightBudget(let available, let pct):
            return ("exclamationmark.circle.fill", KontivaTheme.warning,
                    loc(.insightTightBudget), "\(available.formattedCHF()) · \(pctIncome(pct))")
        case .healthySurplus(let available, let pct):
            return ("checkmark.circle.fill", KontivaTheme.positive,
                    loc(.insightHealthySurplus), "\(available.formattedCHF()) · \(pctIncome(pct))")
        case .highFixedBurden(let total, let pct):
            return ("chart.pie.fill", KontivaTheme.warning,
                    loc(.insightHighFixed), "\(total.formattedCHF()) · \(pctIncome(pct))")
        case .highHousing(let amount, let pct):
            return ("house.fill", KontivaTheme.warning,
                    loc(.insightHighHousing),
                    "\(amount.formattedCHF()) · \(pctIncome(pct)) · \(loc(.insightHousingHint))")
        case .largestFixedCost(let name, let amount, let pctOfFixed):
            return ("chart.bar.fill", KontivaTheme.chartFixed,
                    loc(.insightLargestFixed),
                    "\(name) · \(amount.formattedCHF()) · \(pctOfFixed)% \(loc(.fragOfFixedCosts))")
        case .largestVariable(let name, let amount):
            return ("chart.bar.fill", KontivaTheme.chartFixed,
                    loc(.insightLargestVariable), "\(name) · \(amount.formattedCHF())")
        case .overdueBills(let count, let total):
            return ("calendar.badge.exclamationmark", KontivaTheme.swissRed,
                    loc(.insightOverdue), "\(count) × · \(total.formattedCHF())")
        case .noSavings:
            return ("lightbulb.fill", KontivaTheme.warning,
                    loc(.insightNoSavings), loc(.insightNoSavingsDetail))
        case .goodSavingsRate(let monthly, let pct):
            return ("checkmark.circle.fill", KontivaTheme.positive,
                    loc(.insightGoodSavings), "\(monthly.formattedCHF()) · \(pctIncome(pct))")
        case .allHealthy:
            return ("checkmark.seal.fill", KontivaTheme.positive,
                    loc(.insightAllHealthy), loc(.insightAllHealthyDetail))
        }
    }
}
