import SwiftUI
import KontivaCore

/// Übersicht — the iOS dashboard. Same information and figures as the desktop
/// (reusing the shared availability/trend engine), restacked for a single column.
struct OverviewView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var loc: Localizer

    private var a: MonthlyAvailability { model.availability }
    private var trend: [(month: Date, available: Money, savings: Money)] { model.trend() }
    private var hasData: Bool { model.hasAnyPlanningData || !model.bills.isEmpty }

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: KontivaTheme.Space.md)]

    var body: some View {
        NavigationStack {
            ScreenScroll {
                if !hasData {
                    KontivaCard {
                        EmptyState(systemImage: "square.grid.2x2",
                                   title: loc(.overviewTitle),
                                   message: loc(.overviewEmpty),
                                   actionTitle: loc(.overviewAddCta)) { model.selectedTab = 1 }
                    }
                } else {
                    headlineCard
                    chartCard
                    metricsGrid
                    trendCard
                    breakdownCard
                    securityFooter
                }
            }
            .background(KontivaTheme.pageGradient.ignoresSafeArea())
            .navigationTitle(loc(.overviewTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { MonthSelector() } }
            .animation(.snappy, value: a)
        }
    }

    // MARK: Hero

    private var status: (text: String, color: Color)? {
        guard hasData else { return nil }
        if a.available.isNegative { return (loc(.overviewStatusNegative), KontivaTheme.swissRed) }
        if a.netIncomeThisMonth.isPositive && a.available.percent(of: a.netIncomeThisMonth) < 12 {
            return (loc(.overviewStatusTight), KontivaTheme.warning)
        }
        return (loc(.overviewStatusGood), KontivaTheme.positive)
    }

    private var headlineCard: some View {
        KontivaCard {
            VStack(alignment: .leading, spacing: KontivaTheme.Space.sm) {
                HStack {
                    CardTitle(loc(.overviewAvailableThisMonth))
                    Spacer(minLength: KontivaTheme.Space.sm)
                    if let status { StatusPill(text: status.text, color: status.color) }
                }
                HStack(alignment: .center) {
                    Text(a.available.formattedCHF())
                        .font(.system(size: 34, weight: .bold)).monospacedDigit()
                        .contentTransition(.numericText())
                        .foregroundStyle(a.available.isNegative ? KontivaTheme.swissRed : KontivaTheme.textPrimary)
                        .lineLimit(1).minimumScaleFactor(0.5)
                    Spacer(minLength: KontivaTheme.Space.sm)
                    Sparkline(values: trend.map { Double($0.available.rappen) / 100 },
                              color: a.available.isNegative ? KontivaTheme.swissRed : KontivaTheme.chartAvailable,
                              width: 88, height: 32)
                }
            }
        }
    }

    @ViewBuilder private var chartCard: some View {
        if a.netIncomeThisMonth.isPositive || a.totalCommitted.isPositive {
            KontivaCard {
                VStack(alignment: .leading, spacing: KontivaTheme.Space.md) {
                    CardTitle(loc(.chartSpendingTitle))
                    SpendingDonut(availability: a, loc: loc.localization)
                }
            }
        }
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: columns, spacing: KontivaTheme.Space.md) {
            MetricTile(title: loc(.planningIncome), value: a.netIncomeThisMonth.formattedCHF(),
                       icon: "arrow.down.circle.fill", iconColor: KontivaTheme.positive,
                       valueColor: KontivaTheme.positive)
            MetricTile(title: loc(.planningFixed), value: a.recurringFixedCosts.formattedCHF(),
                       icon: "repeat.circle.fill")
            MetricTile(title: loc(.planningVariable), value: a.plannedVariableBudgets.formattedCHF(),
                       icon: "slider.horizontal.3")
            if !model.savingsGoals.isEmpty {
                MetricTile(title: loc(.navSparen), value: model.totalMonthlySavings.formattedCHF(),
                           icon: "banknote.fill", iconColor: KontivaTheme.positive,
                           caption: "\(loc(.sparenAccumulatedTotal)): \(model.totalAccumulatedSavings.formattedCHF())")
            }
            MetricTile(title: loc(.navBills), value: a.openBillsDueThisMonth.formattedCHF(),
                       icon: "doc.text.fill")
            if model.hasAnyDebt {
                MetricTile(title: loc(.navSchulden), value: model.totalDebt.formattedCHF(),
                           icon: "creditcard", iconColor: KontivaTheme.swissRed, valueColor: KontivaTheme.swissRed,
                           caption: model.totalOverdueBills.isZero ? nil
                                : "\(loc(.schuldenOverdueBills)): \(model.totalOverdueBills.formattedCHF())")
            }
        }
    }

    private var trendCard: some View {
        KontivaCard {
            VStack(alignment: .leading, spacing: KontivaTheme.Space.md) {
                CardTitle(loc(.overviewTrendTitle))
                TrendChart(points: trend.map { .init(month: $0.month, value: $0.available) },
                           locale: loc.language.locale,
                           color: a.available.isNegative ? KontivaTheme.swissRed : KontivaTheme.chartAvailable)
            }
        }
    }

    private var breakdownCard: some View {
        KontivaCard {
            DisclosureGroup {
                breakdownRows.padding(.top, KontivaTheme.Space.sm)
            } label: {
                Text(loc(.overviewShowCalculation))
                    .font(.system(size: 13, weight: .medium)).foregroundStyle(KontivaTheme.textSecondary)
            }
            .tint(KontivaTheme.textSecondary)
        }
    }

    private var breakdownRows: some View {
        VStack(alignment: .leading, spacing: KontivaTheme.Space.sm) {
            Text(loc(.overviewFormulaExplainer))
                .font(.caption).foregroundStyle(KontivaTheme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
            MoneyRow(label: loc(.overviewNetIncome), amount: a.netIncomeThisMonth, emphasised: true)
            if let thirteenth = a.thirteenthShownSeparately {
                HStack {
                    Text(loc(.overviewThirteenthSeparate)).font(.caption).foregroundStyle(KontivaTheme.textTertiary)
                    Spacer()
                    Text(thirteenth.formattedCHF()).font(.caption).monospacedDigit()
                        .foregroundStyle(KontivaTheme.textTertiary)
                }
            }
            Divider()
            MoneyRow(label: loc(.overviewRecurringFixed), amount: a.recurringFixedCosts, subtractive: true)
            MoneyRow(label: loc(.overviewPlannedVariable), amount: a.plannedVariableBudgets, subtractive: true)
            MoneyRow(label: loc(.overviewBillsDueThisMonth), amount: a.openBillsDueThisMonth, subtractive: true)
            MoneyRow(label: loc(.overviewOverdueBills), amount: a.overdueOpenBills, subtractive: true)
            if a.plannedSavings.isPositive {
                MoneyRow(label: loc(.overviewPlannedSavings), amount: a.plannedSavings, subtractive: true)
            }
            Divider()
            MoneyRow(label: loc(.overviewAvailableThisMonth), amount: a.available, emphasised: true)
        }
    }

    private var securityFooter: some View {
        HStack(spacing: KontivaTheme.Space.xxs) {
            Image(systemName: "lock.fill")
            Text("AES-256-GCM")
        }
        .font(.caption2).foregroundStyle(KontivaTheme.textTertiary)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, KontivaTheme.Space.xs)
    }
}
