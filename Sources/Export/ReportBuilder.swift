import SwiftUI
import KontivaCore

/// Assembles the exported financial report: a cover page, an at-a-glance summary
/// (key numbers + spending donut + the available-balance breakdown), the planning
/// tables (income, fixed costs, variable budgets — each with a bar chart), savings
/// goals, bills, and the rule-based insights. Everything is built from the live
/// in-memory dataset and rendered to a vector PDF locally.
/// Everything the report needs, decoupled from `AppModel` so the builder can be
/// driven and rendered in isolation (and tested headlessly).
struct ReportInput {
    let loc: Localization
    let locale: Locale
    let month: Date
    let availability: MonthlyAvailability
    let incomes: [Income]
    let fixedCosts: [RecurringFixedExpense]
    let variableBudgets: [VariableMonthlyBudget]
    let savingsGoals: [SavingsGoal]
    let bills: [OneOffBill]
    let insights: [Insight]
    let household: Household?
}

@MainActor
enum ReportBuilder {

    /// Build the whole report as PDF bytes, or `nil` if there is nothing to export.
    static func makePDF(model: AppModel) -> Data? {
        makePDF(ReportInput(
            loc: model.localizer.localization,
            locale: model.localizer.language.locale,
            month: model.selectedMonth,
            availability: model.availability,
            incomes: model.incomes,
            fixedCosts: model.fixedCosts,
            variableBudgets: model.variableBudgets,
            savingsGoals: model.savingsGoals,
            bills: model.bills,
            insights: model.insights,
            household: model.dataset.household))
    }

    /// Build the report from a plain input bundle.
    static func makePDF(_ input: ReportInput) -> Data? {
        let loc = input.loc
        let locale = input.locale
        let month = input.month
        let a = input.availability
        let incomes = input.incomes
        let fixedCosts = input.fixedCosts
        let variableBudgets = input.variableBudgets
        let savingsGoals = input.savingsGoals
        let bills = input.bills
        let insights = input.insights

        guard !incomes.isEmpty || !fixedCosts.isEmpty || !variableBudgets.isEmpty
                || !savingsGoals.isEmpty || !bills.isEmpty else { return nil }

        let period = monthLabel(month, locale: locale)
        let generatedOn = "\(loc.string(.pdfGeneratedOn)) \(SwissDate.medium(Date(), locale: locale))"

        // Each block becomes one printed page.
        var blocks: [(title: String, body: AnyView)] = []
        blocks.append((loc.string(.pdfSummary),
                       AnyView(ReportSummaryBody(a: a, loc: loc, segments: donutSegments(a, loc)))))
        blocks += planningBlocks(incomes: incomes, fixedCosts: fixedCosts, asOf: month, loc: loc)
        blocks += variableBlocks(variableBudgets: variableBudgets, loc: loc)
        blocks += savingsBlocks(savingsGoals: savingsGoals, asOf: month, loc: loc)
        blocks += billsBlocks(bills: bills, asOf: month, loc: loc, locale: locale)
        if !insights.isEmpty {
            blocks.append((loc.string(.navInsights), AnyView(ReportInsightsBody(insights: insights, loc: loc))))
        }

        let pageCount = blocks.count + 1   // + cover
        let household = input.household
        let name = (household?.name).flatMap { $0.isEmpty ? nil : $0 } ?? loc.string(.pdfDefaultHousehold)
        let cover = AnyView(ReportCoverBody(
            loc: loc, householdName: name, avatarName: household?.avatarName,
            cantonText: household?.canton.map { "\($0.name) (\($0.abbreviation))" },
            period: period, generatedOn: generatedOn))

        var pages: [AnyView] = [cover]
        for (i, block) in blocks.enumerated() {
            pages.append(AnyView(ReportPage(
                sectionTitle: block.title, period: period,
                pageIndex: i + 2, pageCount: pageCount,
                generatedOn: generatedOn, loc: loc, content: { block.body })))
        }
        return ReportPDFRenderer.render(pages)
    }

    /// A suggested filename like `kontiva-bericht-2026-06.pdf`.
    static func suggestedFilename(month: Date) -> String {
        let f = DateFormatter()
        f.calendar = .swiss
        f.dateFormat = "yyyy-MM"
        return "kontiva-bericht-\(f.string(from: month)).pdf"
    }

    // MARK: - Section builders

    private static func planningBlocks(incomes: [Income], fixedCosts: [RecurringFixedExpense],
                                       asOf: Date, loc: Localization) -> [(String, AnyView)] {
        // Only costs active this month appear in a monthly report — a finished
        // standing order is no longer a cost.
        let activeFixed = fixedCosts.filter { $0.isActive(in: asOf) }
        guard !incomes.isEmpty || !activeFixed.isEmpty else { return [] }
        let title = loc.string(.planningTitle)
        let incomeWidths: [CGFloat] = [300, 203]
        let fixedWidths: [CGFloat] = [200, 165, 138]

        let incomeHeader = [ReportCell(text: loc.string(.formName)),
                            ReportCell(text: loc.string(.formAmount), trailing: true)]
        let incomeRows = incomes.map {
            [ReportCell(text: $0.label),
             ReportCell(text: $0.monthlyNet.formattedCHF(), trailing: true)]
        }

        // Income alone → one small section, no fixed-costs table.
        if activeFixed.isEmpty {
            return [(title, AnyView(VStack(alignment: .leading, spacing: 14) {
                ReportSubheading(loc.string(.planningIncome))
                ReportTable(header: incomeHeader, rows: incomeRows, widths: incomeWidths)
            }))]
        }

        // Mark a limited standing order with its current instalment (e.g. 2/6).
        func categoryText(_ item: RecurringFixedExpense) -> String {
            let cat = item.category.localizedName(loc)
            guard item.isLimited, let n = item.installmentNumber(in: asOf),
                  let count = item.installments else { return cat }
            return "\(cat) · \(loc.string(.planningStandingOrder)) \(n)/\(count)"
        }

        let fixedHeader = [ReportCell(text: loc.string(.formName)),
                           ReportCell(text: loc.string(.formCategory)),
                           ReportCell(text: loc.string(.formAmount), trailing: true)]
        let fixedRows = activeFixed.map {
            [ReportCell(text: $0.name),
             ReportCell(text: categoryText($0), color: ReportStyle.inkSecondary),
             ReportCell(text: $0.monthlyAmount.formattedCHF(), trailing: true)]
        }
        let total = activeFixed.map(\.monthlyAmount).total()
        let footer = [ReportCell(text: loc.string(.pdfTotal), bold: true),
                      ReportCell(text: ""),
                      ReportCell(text: total.formattedCHF(), trailing: true, bold: true)]
        let bars = topBars(activeFixed.map { ($0.name, $0.monthlyAmount) })

        let intro = AnyView(VStack(alignment: .leading, spacing: 14) {
            if !incomes.isEmpty {
                ReportSubheading(loc.string(.planningIncome))
                ReportTable(header: incomeHeader, rows: incomeRows, widths: incomeWidths)
            }
            ReportSubheading(loc.string(.planningFixed))
            if !bars.isEmpty { ReportBars(bars: bars) }
        })

        return tableSection(title: title, header: fixedHeader, rows: fixedRows, widths: fixedWidths,
                            intro: intro, footerRow: footer, rowsFirst: 8, rowsRest: 22)
    }

    private static func variableBlocks(variableBudgets: [VariableMonthlyBudget],
                                       loc: Localization) -> [(String, AnyView)] {
        guard !variableBudgets.isEmpty else { return [] }
        let widths: [CGFloat] = [215, 150, 138]
        let header = [ReportCell(text: loc.string(.formName)),
                      ReportCell(text: loc.string(.formCategory)),
                      ReportCell(text: loc.string(.formAmount), trailing: true)]
        let rows = variableBudgets.map {
            [ReportCell(text: $0.name),
             ReportCell(text: $0.category.localizedName(loc), color: ReportStyle.inkSecondary),
             ReportCell(text: $0.plannedAmount.formattedCHF(), trailing: true)]
        }
        let total = variableBudgets.map(\.plannedAmount).total()
        let footer = [ReportCell(text: loc.string(.pdfTotal), bold: true),
                      ReportCell(text: ""),
                      ReportCell(text: total.formattedCHF(), trailing: true, bold: true)]
        let bars = topBars(variableBudgets.map { ($0.name, $0.plannedAmount) })
        let intro = bars.isEmpty ? nil : AnyView(ReportBars(bars: bars))

        return tableSection(title: loc.string(.planningVariable), header: header, rows: rows, widths: widths,
                            intro: intro, footerRow: footer, rowsFirst: 10, rowsRest: 22)
    }

    private static func savingsBlocks(savingsGoals: [SavingsGoal], asOf: Date,
                                      loc: Localization) -> [(String, AnyView)] {
        guard !savingsGoals.isEmpty else { return [] }
        let widths: [CGFloat] = [88, 116, 112, 96, 91]
        let header = [ReportCell(text: loc.string(.formName)),
                      ReportCell(text: loc.string(.formCategory)),
                      ReportCell(text: loc.string(.formMonthlyContribution), trailing: true),
                      ReportCell(text: loc.string(.sparenAccumulatedTotal), trailing: true),
                      ReportCell(text: loc.string(.pdfColProgress), trailing: true)]
        let rows = savingsGoals.map { g -> [ReportCell] in
            let pct = g.progressPercent(asOf: asOf)
            return [ReportCell(text: g.name),
                    ReportCell(text: g.category.localizedName(loc), color: ReportStyle.inkSecondary),
                    ReportCell(text: (g.monthlyContribution ?? .zero).formattedCHF(), trailing: true),
                    ReportCell(text: g.accumulated(asOf: asOf).formattedCHF(), trailing: true,
                               color: ReportStyle.positive),
                    ReportCell(text: g.hasTarget ? "\(pct)%" : "—", trailing: true,
                               color: pct >= 100 ? ReportStyle.positive : ReportStyle.ink)]
        }
        return tableSection(title: loc.string(.planningSavings), header: header, rows: rows, widths: widths,
                            rowsFirst: 16, rowsRest: 20)
    }

    private static func billsBlocks(bills: [OneOffBill], asOf: Date,
                                    loc: Localization, locale: Locale) -> [(String, AnyView)] {
        guard !bills.isEmpty else { return [] }
        let widths: [CGFloat] = [165, 105, 108, 125]
        let header = [ReportCell(text: loc.string(.billsProvider)),
                      ReportCell(text: loc.string(.billsDueDate)),
                      ReportCell(text: loc.string(.formAmount), trailing: true),
                      ReportCell(text: loc.string(.formStatus))]
        let order: (BillState) -> Int = { s in
            switch s { case .overdue: return 0; case .dueThisMonth: return 1
                       case .future: return 2; case .paid: return 3 }
        }
        let sorted = bills.sorted { l, r in
            let ls = order(BillClassifier.state(of: l, asOf: asOf))
            let rs = order(BillClassifier.state(of: r, asOf: asOf))
            return ls == rs ? l.dueDate < r.dueDate : ls < rs
        }
        let rows = sorted.map { bill -> [ReportCell] in
            let (text, color) = billStatePresentation(BillClassifier.state(of: bill, asOf: asOf), loc)
            return [ReportCell(text: bill.provider),
                    ReportCell(text: SwissDate.medium(bill.dueDate, locale: locale), color: ReportStyle.inkSecondary),
                    ReportCell(text: bill.amount.formattedCHF(), trailing: true),
                    ReportCell(text: text, color: color)]
        }
        return tableSection(title: loc.string(.billsTitle), header: header, rows: rows, widths: widths,
                            rowsFirst: 20, rowsRest: 24)
    }

    // MARK: - Generic table → paginated blocks

    /// Split `rows` across as many pages as needed. The optional `intro` (e.g. a
    /// chart) appears only on the first page; the optional `footerRow` (e.g. a
    /// total) appears only on the last.
    private static func tableSection(title: String, header: [ReportCell], rows: [[ReportCell]],
                                     widths: [CGFloat], intro: AnyView? = nil,
                                     footerRow: [ReportCell]? = nil,
                                     rowsFirst: Int, rowsRest: Int) -> [(String, AnyView)] {
        if rows.isEmpty {
            return [(title, AnyView(VStack(alignment: .leading, spacing: 12) {
                if let intro { intro }
                ReportTable(header: header, rows: [], widths: widths, footerRow: footerRow)
            }))]
        }
        var blocks: [(String, AnyView)] = []
        var index = 0
        var firstPage = true
        while index < rows.count {
            let take = max(1, firstPage ? rowsFirst : rowsRest)
            let end = min(index + take, rows.count)
            let chunk = Array(rows[index..<end])
            let pageIntro = firstPage ? intro : nil
            let pageFooter = (end >= rows.count) ? footerRow : nil
            blocks.append((title, AnyView(VStack(alignment: .leading, spacing: 12) {
                if let pageIntro { pageIntro }
                ReportTable(header: header, rows: chunk, widths: widths, footerRow: pageFooter)
            })))
            index = end
            firstPage = false
        }
        return blocks
    }

    // MARK: - Helpers

    private static func topBars(_ named: [(String, Money)]) -> [ReportBars.Bar] {
        named.sorted { $0.1 > $1.1 }.prefix(7).enumerated().map { i, item in
            ReportBars.Bar(name: item.0, amount: item.1,
                           color: ReportStyle.categoryPalette[i % ReportStyle.categoryPalette.count])
        }
    }

    static func donutSegments(_ a: MonthlyAvailability, _ loc: Localization) -> [ReportDonut.Segment] {
        func chf(_ m: Money) -> Double { Double(m.rappen) / 100 }
        var result: [ReportDonut.Segment] = []
        func add(_ key: L10nKey, _ m: Money, _ color: Color) {
            if m.isPositive { result.append(.init(label: loc.string(key), value: chf(m), color: color)) }
        }
        add(.overviewRecurringFixed, a.recurringFixedCosts, ReportStyle.chartFixed)
        add(.overviewPlannedVariable, a.plannedVariableBudgets, ReportStyle.chartVariable)
        add(.billsTitle, a.openBillsDueThisMonth + a.overdueOpenBills, ReportStyle.chartBills)
        add(.overviewPlannedSavings, a.plannedSavings, ReportStyle.chartSavings)
        add(.overviewAvailableThisMonth, a.available, ReportStyle.chartAvailable)
        return result
    }

    static func monthLabel(_ date: Date, locale: Locale) -> String {
        let f = DateFormatter()
        f.locale = locale
        f.calendar = .swiss
        f.setLocalizedDateFormatFromTemplate("LLLL yyyy")
        return f.string(from: date)
    }

    private static func billStatePresentation(_ state: BillState, _ loc: Localization) -> (String, Color) {
        switch state {
        case .overdue:      return (loc.string(.billsStateOverdue), ReportStyle.accent)
        case .dueThisMonth: return (loc.string(.billsStateDueThisMonth), ReportStyle.warning)
        case .future:       return (loc.string(.billsStateFuture), ReportStyle.inkTertiary)
        case .paid:         return (loc.string(.billsStatusPaid), ReportStyle.positive)
        }
    }

    static func insightPresentation(_ insight: Insight, _ loc: Localization) -> (Color, String, String) {
        func pctIncome(_ p: Int) -> String { "\(p)% \(loc.string(.fragOfNetIncome))" }
        let dot: Color
        switch insight.severity {
        case .warning:  dot = ReportStyle.accent
        case .tip:      dot = ReportStyle.warning
        case .info:     dot = ReportStyle.chartFixed
        case .positive: dot = ReportStyle.positive
        }
        switch insight {
        case .overspending(let deficit):
            return (dot, loc.string(.insightOverspending), "\(loc.string(.fragShortfall)): \(deficit.formattedCHF())")
        case .tightBudget(let available, let pct):
            return (dot, loc.string(.insightTightBudget), "\(available.formattedCHF()) · \(pctIncome(pct))")
        case .healthySurplus(let available, let pct):
            return (dot, loc.string(.insightHealthySurplus), "\(available.formattedCHF()) · \(pctIncome(pct))")
        case .highFixedBurden(let total, let pct):
            return (dot, loc.string(.insightHighFixed), "\(total.formattedCHF()) · \(pctIncome(pct))")
        case .highHousing(let amount, let pct):
            return (dot, loc.string(.insightHighHousing),
                    "\(amount.formattedCHF()) · \(pctIncome(pct)) · \(loc.string(.insightHousingHint))")
        case .largestFixedCost(let name, let amount, let pctOfFixed):
            return (dot, loc.string(.insightLargestFixed),
                    "\(name) · \(amount.formattedCHF()) · \(pctOfFixed)% \(loc.string(.fragOfFixedCosts))")
        case .largestVariable(let name, let amount):
            return (dot, loc.string(.insightLargestVariable), "\(name) · \(amount.formattedCHF())")
        case .overdueBills(let count, let total):
            return (dot, loc.string(.insightOverdue), "\(count) × · \(total.formattedCHF())")
        case .noSavings:
            return (dot, loc.string(.insightNoSavings), loc.string(.insightNoSavingsDetail))
        case .goodSavingsRate(let monthly, let pct):
            return (dot, loc.string(.insightGoodSavings), "\(monthly.formattedCHF()) · \(pctIncome(pct))")
        case .allHealthy:
            return (dot, loc.string(.insightAllHealthy), loc.string(.insightAllHealthyDetail))
        }
    }
}

// MARK: - Page bodies

/// Cover page: wordmark, report title, period, household + generation metadata.
struct ReportCoverBody: View {
    let loc: Localization
    let householdName: String
    var avatarName: String? = nil
    let cantonText: String?
    let period: String
    let generatedOn: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack { Image("Wordmark").resizable().scaledToFit().frame(height: 26); Spacer() }
            Rectangle().fill(ReportStyle.accent).frame(width: 54, height: 3).padding(.top, 12)

            Spacer()
            VStack(alignment: .leading, spacing: 10) {
                Text(loc.string(.pdfSubtitle).uppercased())
                    .font(.system(size: 12, weight: .semibold)).tracking(1.2)
                    .foregroundStyle(ReportStyle.accent)
                Text(loc.string(.pdfTitle))
                    .font(.system(size: 40, weight: .bold)).foregroundStyle(ReportStyle.ink)
                Text(period).font(.system(size: 18)).foregroundStyle(ReportStyle.inkSecondary)
            }
            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                Rectangle().fill(ReportStyle.hair).frame(height: 1)
                HStack(alignment: .bottom) {
                    if let avatarName {
                        ProfileAvatar(name: avatarName, size: 34)
                            .padding(.trailing, 4)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(householdName).font(.system(size: 13, weight: .semibold)).foregroundStyle(ReportStyle.ink)
                        if let cantonText {
                            Text(cantonText).font(.system(size: 11)).foregroundStyle(ReportStyle.inkSecondary)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(generatedOn).font(.system(size: 10)).foregroundStyle(ReportStyle.inkTertiary)
                        Text(loc.string(.appTagline)).font(.system(size: 9)).foregroundStyle(ReportStyle.inkTertiary)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
        }
        .padding(56)
        .frame(width: ReportStyle.pageSize.width, height: ReportStyle.pageSize.height)
        .background(ReportStyle.paper)
    }
}

/// At-a-glance summary: hero available balance, metric strip, spending donut and
/// the transparent income − costs − bills = available breakdown.
struct ReportSummaryBody: View {
    let a: MonthlyAvailability
    let loc: Localization
    let segments: [ReportDonut.Segment]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(loc.string(.overviewAvailableThisMonth).uppercased())
                    .font(.system(size: 10, weight: .semibold)).tracking(0.6)
                    .foregroundStyle(ReportStyle.inkTertiary)
                Text(a.available.formattedCHF())
                    .font(.system(size: 34, weight: .bold)).monospacedDigit()
                    .foregroundStyle(a.available.isNegative ? ReportStyle.accent : ReportStyle.ink)
                    .lineLimit(1).minimumScaleFactor(0.5)
            }

            HStack(spacing: 12) {
                ReportMetricBox(title: loc.string(.overviewNetIncome),
                                value: a.netIncomeThisMonth.formattedCHF(), color: ReportStyle.positive)
                ReportMetricBox(title: loc.string(.overviewRecurringFixed),
                                value: a.recurringFixedCosts.formattedCHF())
                ReportMetricBox(title: loc.string(.overviewPlannedVariable),
                                value: a.plannedVariableBudgets.formattedCHF())
                ReportMetricBox(title: loc.string(.overviewOverdueBills),
                                value: a.overdueOpenBills.formattedCHF(),
                                color: a.overdueOpenBills.isZero ? ReportStyle.ink : ReportStyle.accent)
            }

            if !segments.isEmpty {
                ReportCardBox(title: loc.string(.chartSpendingTitle)) {
                    ReportDonut(segments: segments,
                                centerTitle: loc.string(.overviewAvailableThisMonth),
                                centerValue: a.available.formattedCHF(),
                                centerNegative: a.available.isNegative)
                }
            }

            ReportCardBox {
                VStack(alignment: .leading, spacing: 8) {
                    line(loc.string(.overviewNetIncome), a.netIncomeThisMonth, emphasised: true)
                    Rectangle().fill(ReportStyle.hair).frame(height: 1)
                    line(loc.string(.overviewRecurringFixed), a.recurringFixedCosts, subtractive: true)
                    line(loc.string(.overviewPlannedVariable), a.plannedVariableBudgets, subtractive: true)
                    line(loc.string(.overviewBillsDueThisMonth), a.openBillsDueThisMonth, subtractive: true)
                    line(loc.string(.overviewOverdueBills), a.overdueOpenBills, subtractive: true)
                    if a.plannedSavings.isPositive {
                        line(loc.string(.overviewPlannedSavings), a.plannedSavings, subtractive: true)
                    }
                    Rectangle().fill(ReportStyle.ink.opacity(0.22)).frame(height: 1)
                    line(loc.string(.overviewAvailableThisMonth), a.available, emphasised: true)
                }
            }
        }
    }

    private func line(_ label: String, _ amount: Money,
                      subtractive: Bool = false, emphasised: Bool = false) -> some View {
        HStack {
            Text(subtractive ? "− \(label)" : label)
                .font(.system(size: emphasised ? 13 : 11, weight: emphasised ? .semibold : .regular))
                .foregroundStyle(emphasised ? ReportStyle.ink : ReportStyle.inkSecondary)
            Spacer(minLength: 12)
            Text(amount.formattedCHF())
                .font(.system(size: emphasised ? 14 : 12, weight: emphasised ? .semibold : .regular))
                .monospacedDigit()
                .foregroundStyle(amount.isNegative ? ReportStyle.accent : ReportStyle.ink)
        }
    }
}

/// Insights: severity-ordered observations, each a coloured dot + title + detail.
struct ReportInsightsBody: View {
    let insights: [Insight]
    let loc: Localization

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(loc.string(.insightsSubtitle))
                .font(.system(size: 11)).foregroundStyle(ReportStyle.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(insights) { insight in
                let p = ReportBuilder.insightPresentation(insight, loc)
                HStack(alignment: .top, spacing: 12) {
                    Circle().fill(p.0).frame(width: 9, height: 9).padding(.top, 4)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(p.1).font(.system(size: 12, weight: .semibold)).foregroundStyle(ReportStyle.ink)
                        Text(p.2).font(.system(size: 10)).foregroundStyle(ReportStyle.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 8).padding(.horizontal, 12)
                .background(RoundedRectangle(cornerRadius: 8).fill(ReportStyle.zebra))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(ReportStyle.hair, lineWidth: 1))
            }
        }
    }
}
