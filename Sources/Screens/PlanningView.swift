import SwiftUI
import KontivaCore

/// Which add/edit sheet the Planning screen is presenting.
enum PlanningSheet: Identifiable {
    case income(Income?)
    case fixed(RecurringFixedExpense?)
    case variable(VariableMonthlyBudget?)

    var id: String {
        switch self {
        case .income(let i):   return "income-\(i?.id.uuidString ?? "new")"
        case .fixed(let f):    return "fixed-\(f?.id.uuidString ?? "new")"
        case .variable(let v): return "variable-\(v?.id.uuidString ?? "new")"
        }
    }
}

/// Monatsplanung — the recurring plan: income, fixed costs, variable budgets.
/// Card-based, ported from the desktop with iOS-native sheets and context menus.
struct PlanningView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var loc: Localizer
    @State private var sheet: PlanningSheet?

    private var hasAny: Bool {
        !(model.incomes.isEmpty && model.fixedCosts.isEmpty && model.variableBudgets.isEmpty)
    }

    var body: some View {
        NavigationStack {
            ScreenScroll {
                if hasAny { summaryCard }
                incomeCard
                fixedCard
                variableCard
                Text(loc(.planningOneOffHint))
                    .font(.caption).foregroundStyle(KontivaTheme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, KontivaTheme.Space.xs)
            }
            .background(KontivaTheme.pageGradient.ignoresSafeArea())
            .navigationTitle(loc(.planningTitle))
            .animation(.snappy, value: model.dataset)
            .sheet(item: $sheet) { route in
                sheetContent(route).environmentObject(model).environmentObject(loc)
            }
        }
    }

    @ViewBuilder
    private func sheetContent(_ route: PlanningSheet) -> some View {
        switch route {
        case .income(let i):   IncomeFormSheet(existing: i)
        case .fixed(let f):    FixedExpenseFormSheet(existing: f)
        case .variable(let v): VariableBudgetFormSheet(existing: v)
        }
    }

    // MARK: Summary

    private var summaryCard: some View {
        let income = model.incomes.map(\.monthlyNet).total()
        let fixed = model.fixedCosts.map(\.monthlyAmount).total()
        let variable = model.variableBudgets.map(\.plannedAmount).total()
        let balance = income - fixed - variable
        return KontivaCard {
            VStack(alignment: .leading, spacing: KontivaTheme.Space.md) {
                HStack(spacing: KontivaTheme.Space.sm) {
                    KontivaIconTile("calendar")
                    VStack(alignment: .leading, spacing: 1) {
                        CardTitle(loc(.planningBalance))
                        Text(balance.formattedCHF())
                            .font(.title2.weight(.semibold)).monospacedDigit()
                            .contentTransition(.numericText())
                            .foregroundStyle(balance.isNegative ? KontivaTheme.swissRed : KontivaTheme.textPrimary)
                    }
                    Spacer(minLength: 0)
                }
                Divider()
                HStack(spacing: KontivaTheme.Space.md) {
                    SummaryStat(loc(.planningIncome), value: income.formattedCHF(), color: KontivaTheme.positive)
                    SummaryStat(loc(.planningFixed), value: fixed.formattedCHF())
                    SummaryStat(loc(.planningVariable), value: variable.formattedCHF())
                }
            }
        }
    }

    // MARK: Section cards

    private var incomeCard: some View {
        planCard(title: loc(.planningIncome), icon: "arrow.down.circle.fill", count: model.incomes.count,
                 total: model.incomes.isEmpty ? nil : model.incomes.map(\.monthlyNet).total(),
                 explainer: nil, isEmpty: model.incomes.isEmpty,
                 add: { sheet = .income(nil) }) {
            ForEach(Array(model.incomes.enumerated()), id: \.element.id) { idx, income in
                if idx > 0 { rowDivider }
                planRow(icon: "arrow.down.circle.fill", name: income.label,
                        subtitle: thirteenthSubtitle(income), amount: income.monthlyNet,
                        edit: { sheet = .income(income) },
                        delete: { run { await model.deleteIncome(income.id) } },
                        moveUp: idx > 0 ? { run { await model.moveIncomes(from: IndexSet(integer: idx), to: idx - 1) } } : nil,
                        moveDown: idx < model.incomes.count - 1 ? { run { await model.moveIncomes(from: IndexSet(integer: idx), to: idx + 2) } } : nil)
            }
        }
    }

    private var fixedCard: some View {
        planCard(title: loc(.planningFixed), icon: "repeat.circle.fill", count: model.fixedCosts.count,
                 total: model.fixedCosts.isEmpty ? nil : model.fixedCosts.map(\.monthlyAmount).total(),
                 explainer: loc(.planningFixedExplainer), isEmpty: model.fixedCosts.isEmpty,
                 add: { sheet = .fixed(nil) }) {
            ForEach(Array(model.fixedCosts.enumerated()), id: \.element.id) { idx, item in
                if idx > 0 { rowDivider }
                planRow(icon: item.category.systemImage, name: item.name,
                        subtitle: fixedSubtitle(item), amount: item.monthlyAmount,
                        edit: { sheet = .fixed(item) },
                        delete: { run { await model.deleteFixedCost(item.id) } },
                        moveUp: idx > 0 ? { run { await model.moveFixedCosts(from: IndexSet(integer: idx), to: idx - 1) } } : nil,
                        moveDown: idx < model.fixedCosts.count - 1 ? { run { await model.moveFixedCosts(from: IndexSet(integer: idx), to: idx + 2) } } : nil)
            }
        }
    }

    private var variableCard: some View {
        planCard(title: loc(.planningVariable), icon: "slider.horizontal.3", count: model.variableBudgets.count,
                 total: model.variableBudgets.isEmpty ? nil : model.variableBudgets.map(\.plannedAmount).total(),
                 explainer: loc(.planningVariableExplainer), isEmpty: model.variableBudgets.isEmpty,
                 add: { sheet = .variable(nil) }) {
            ForEach(Array(model.variableBudgets.enumerated()), id: \.element.id) { idx, item in
                if idx > 0 { rowDivider }
                planRow(icon: item.category.systemImage, name: item.name,
                        subtitle: item.category.localizedName(loc.localization), amount: item.plannedAmount,
                        edit: { sheet = .variable(item) },
                        delete: { run { await model.deleteVariableBudget(item.id) } },
                        moveUp: idx > 0 ? { run { await model.moveVariableBudgets(from: IndexSet(integer: idx), to: idx - 1) } } : nil,
                        moveDown: idx < model.variableBudgets.count - 1 ? { run { await model.moveVariableBudgets(from: IndexSet(integer: idx), to: idx + 2) } } : nil)
            }
        }
    }

    // MARK: Card shell + rows

    private func planCard<Content: View>(title: String, icon: String, count: Int, total: Money?,
                                         explainer: String?, isEmpty: Bool,
                                         add: @escaping () -> Void,
                                         @ViewBuilder content: () -> Content) -> some View {
        KontivaCard {
            VStack(alignment: .leading, spacing: KontivaTheme.Space.md) {
                HStack(spacing: KontivaTheme.Space.sm) {
                    KontivaIconTile(icon)
                    Text(title).font(.title3.weight(.semibold)).foregroundStyle(KontivaTheme.textPrimary)
                    if count > 0 { CountBadge(count) }
                    Spacer(minLength: KontivaTheme.Space.sm)
                    if let total {
                        VStack(alignment: .trailing, spacing: 0) {
                            Text(total.formattedCHF())
                                .font(.title3.weight(.semibold)).monospacedDigit()
                                .contentTransition(.numericText())
                                .foregroundStyle(KontivaTheme.textPrimary)
                            Text(loc(.sparenPerMonth)).font(.caption2).foregroundStyle(KontivaTheme.textTertiary)
                        }
                    }
                }
                if !isEmpty {
                    rowDivider
                    VStack(spacing: 0) { content() }
                }
                addButton(add)
                if let explainer {
                    Text(explainer).font(.caption).foregroundStyle(KontivaTheme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    /// Fire-and-forget async work (avoids the single-`Task`-closure ambiguity in ternaries).
    private func run(_ work: @escaping () async -> Void) { Task { await work() } }

    private var rowDivider: some View { Divider().background(KontivaTheme.softBorder.opacity(0.4)) }

    private func addButton(_ add: @escaping () -> Void) -> some View {
        Button(action: add) {
            HStack(spacing: KontivaTheme.Space.xs) {
                Image(systemName: "plus")
                Text(loc(.commonAdd))
                Spacer(minLength: 0)
            }
            .font(.callout.weight(.medium)).foregroundStyle(KontivaTheme.accent)
            .padding(.vertical, 10).padding(.horizontal, KontivaTheme.Space.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(KontivaTheme.accent.opacity(0.08)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func planRow(icon: String, name: String, subtitle: String?, amount: Money,
                         edit: @escaping () -> Void, delete: @escaping () -> Void,
                         moveUp: (() -> Void)? = nil, moveDown: (() -> Void)? = nil) -> some View {
        HStack(spacing: KontivaTheme.Space.sm) {
            KontivaIconTile(icon, size: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(name).foregroundStyle(KontivaTheme.textPrimary)
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(KontivaTheme.textTertiary).lineLimit(1)
                }
            }
            Spacer(minLength: KontivaTheme.Space.md)
            Text(amount.formattedCHF())
                .font(.body.weight(.medium)).monospacedDigit().foregroundStyle(KontivaTheme.textPrimary)
        }
        .padding(.vertical, KontivaTheme.Space.xs)
        .contentShape(Rectangle())
        .onTapGesture(perform: edit)
        .contextMenu {
            Button(loc(.commonEdit), systemImage: "pencil", action: edit)
            if let moveUp { Button(loc(.commonMoveUp), systemImage: "arrow.up", action: moveUp) }
            if let moveDown { Button(loc(.commonMoveDown), systemImage: "arrow.down", action: moveDown) }
            Button(loc(.commonDelete), systemImage: "trash", role: .destructive, action: delete)
        }
        .accessibilityElement(children: .combine)
    }

    private func thirteenthSubtitle(_ income: Income) -> String? {
        guard let thirteenth = income.thirteenthAmount, income.thirteenthModel == .separate else { return nil }
        return "+ \(loc(.overviewThirteenthSeparate)): \(thirteenth.formattedCHF())"
    }

    private func fixedSubtitle(_ item: RecurringFixedExpense) -> String {
        let category = item.category.localizedName(loc.localization)
        guard item.isLimited, let start = item.startMonth, let count = item.installments else { return category }
        let f = DateFormatter()
        f.locale = loc.language.locale; f.calendar = .swiss
        f.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return "\(category) · \(loc(.planningStandingOrder)) · \(count)× \(f.string(from: start))"
    }
}
