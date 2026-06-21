import SwiftUI
import KontivaCore

// MARK: - Form building blocks (iOS)

/// Prefill helper: format a Money value for an editable text field (no symbol).
func moneyEditString(_ money: Money?) -> String {
    guard let money else { return "" }
    return money.formattedCHF(showSymbol: false)
}

/// Standard add/edit sheet chrome: a navigation stack with a `Form`, an inline
/// title, and a Cancel / Save bar. Presented via `.sheet`.
struct FormSheet<Content: View>: View {
    @EnvironmentObject private var loc: Localizer
    @Environment(\.dismiss) private var dismiss
    let title: String
    let canSave: Bool
    let onSave: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        NavigationStack {
            Form { content }
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(loc(.commonCancel)) { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(loc(.commonSave), action: onSave)
                            .fontWeight(.semibold).disabled(!canSave)
                    }
                }
        }
    }
}

/// A CHF amount row: trailing decimal-pad field with a "CHF" affordance.
struct MoneyRowField: View {
    let label: String
    @Binding var text: String
    var body: some View {
        LabeledContent(label) {
            HStack(spacing: 4) {
                Text("CHF").font(.caption).foregroundStyle(KontivaTheme.textTertiary)
                TextField("0.00", text: $text)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
            }
        }
    }
}

// MARK: - Income

struct IncomeFormSheet: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var loc: Localizer
    @Environment(\.dismiss) private var dismiss

    let existing: Income?
    @State private var label: String
    @State private var amount: String
    @State private var thirteenthOn: Bool
    @State private var thirteenth: String
    @State private var thModel: ThirteenthSalaryModel

    init(existing: Income?) {
        self.existing = existing
        _label = State(initialValue: existing?.label ?? "")
        _amount = State(initialValue: moneyEditString(existing?.monthlyNet))
        _thirteenthOn = State(initialValue: existing?.thirteenthAmount != nil)
        _thirteenth = State(initialValue: moneyEditString(existing?.thirteenthAmount))
        _thModel = State(initialValue: existing?.thirteenthModel ?? .separate)
    }

    private var parsedNet: Money? { Money.parse(amount) }
    private var canSave: Bool {
        !label.isEmpty && parsedNet != nil && (!thirteenthOn || Money.parse(thirteenth) != nil)
    }

    var body: some View {
        FormSheet(title: loc(existing == nil ? .commonAdd : .commonEdit),
                  canSave: canSave, onSave: save) {
            Section {
                TextField(loc(.formName), text: $label)
                MoneyRowField(label: loc(.formAmount), text: $amount)
            }
            Section {
                Toggle(loc(.formThirteenthAmount), isOn: $thirteenthOn.animation())
                if thirteenthOn {
                    MoneyRowField(label: loc(.formAmount), text: $thirteenth)
                    Picker(loc(.formThirteenthModel), selection: $thModel) {
                        Text(loc(.thirteenthModelSeparate)).tag(ThirteenthSalaryModel.separate)
                        Text(loc(.thirteenthModelAveraged)).tag(ThirteenthSalaryModel.averagedMonthly)
                    }
                }
            }
        }
    }

    private func save() {
        guard let net = parsedNet else { return }
        let income = Income(id: existing?.id ?? UUID(), label: label, monthlyNet: net,
                            thirteenthAmount: thirteenthOn ? Money.parse(thirteenth) : nil,
                            thirteenthModel: thModel)
        Task { await model.upsertIncome(income); dismiss() }
    }
}

// MARK: - Recurring fixed expense

struct FixedExpenseFormSheet: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var loc: Localizer
    @Environment(\.dismiss) private var dismiss

    let existing: RecurringFixedExpense?
    @State private var name: String
    @State private var amount: String
    @State private var category: FixedExpenseCategory
    @State private var limited: Bool
    @State private var startMonth: Date
    @State private var installments: Int

    init(existing: RecurringFixedExpense?) {
        self.existing = existing
        _name = State(initialValue: existing?.name ?? "")
        _amount = State(initialValue: moneyEditString(existing?.monthlyAmount))
        _category = State(initialValue: existing?.category ?? .other)
        _limited = State(initialValue: existing?.isLimited ?? false)
        _startMonth = State(initialValue: existing?.startMonth ?? Date())
        _installments = State(initialValue: existing?.installments ?? 6)
    }

    private var parsed: Money? { Money.parse(amount) }
    private var canSave: Bool { !name.isEmpty && parsed != nil && (!limited || installments >= 1) }

    var body: some View {
        FormSheet(title: loc(existing == nil ? .commonAdd : .commonEdit),
                  canSave: canSave, onSave: save) {
            Section {
                TextField(loc(.formName), text: $name)
                MoneyRowField(label: loc(.formAmount), text: $amount)
                Picker(loc(.formCategory), selection: $category) {
                    ForEach(FixedExpenseCategory.allCases, id: \.self) { c in
                        Label(c.localizedName(loc.localization), systemImage: c.systemImage).tag(c)
                    }
                }
            }
            Section {
                Toggle(loc(.formLimitedDuration), isOn: $limited.animation())
                if limited {
                    DatePicker(loc(.formStartMonth), selection: $startMonth, displayedComponents: .date)
                    Stepper(value: $installments, in: 1...120) {
                        LabeledContent(loc(.formInstallments)) {
                            Text("\(installments)").monospacedDigit()
                        }
                    }
                }
            } footer: {
                Text(loc(.formLimitedDurationHint))
            }
        }
    }

    private func save() {
        guard let amt = parsed else { return }
        let item = RecurringFixedExpense(id: existing?.id ?? UUID(), name: name,
                                         monthlyAmount: amt, category: category,
                                         startMonth: limited ? startMonth : nil,
                                         installments: limited ? installments : nil)
        Task { await model.upsertFixedCost(item); dismiss() }
    }
}

// MARK: - Variable budget

struct VariableBudgetFormSheet: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var loc: Localizer
    @Environment(\.dismiss) private var dismiss

    let existing: VariableMonthlyBudget?
    @State private var name: String
    @State private var amount: String
    @State private var category: VariableBudgetCategory

    init(existing: VariableMonthlyBudget?) {
        self.existing = existing
        _name = State(initialValue: existing?.name ?? "")
        _amount = State(initialValue: moneyEditString(existing?.plannedAmount))
        _category = State(initialValue: existing?.category ?? .other)
    }

    private var parsed: Money? { Money.parse(amount) }
    private var canSave: Bool { !name.isEmpty && parsed != nil }

    var body: some View {
        FormSheet(title: loc(existing == nil ? .commonAdd : .commonEdit),
                  canSave: canSave, onSave: save) {
            Section {
                TextField(loc(.formName), text: $name)
                MoneyRowField(label: loc(.formAmount), text: $amount)
                Picker(loc(.formCategory), selection: $category) {
                    ForEach(VariableBudgetCategory.allCases, id: \.self) { c in
                        Label(c.localizedName(loc.localization), systemImage: c.systemImage).tag(c)
                    }
                }
            }
        }
    }

    private func save() {
        guard let amt = parsed else { return }
        let item = VariableMonthlyBudget(id: existing?.id ?? UUID(), name: name,
                                         plannedAmount: amt, category: category)
        Task { await model.upsertVariableBudget(item); dismiss() }
    }
}

// MARK: - Savings goal

struct SavingsGoalFormSheet: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var loc: Localizer
    @Environment(\.dismiss) private var dismiss

    let existing: SavingsGoal?
    @State private var name: String
    @State private var category: SavingsCategory
    @State private var monthly: String
    @State private var startDate: Date
    @State private var startingBalance: String
    @State private var target: String

    init(existing: SavingsGoal?) {
        self.existing = existing
        _name = State(initialValue: existing?.name ?? "")
        _category = State(initialValue: existing?.category ?? .other)
        _monthly = State(initialValue: moneyEditString(existing?.monthlyContribution))
        _startDate = State(initialValue: existing?.startDate ?? Date())
        _startingBalance = State(initialValue: moneyEditString(existing?.startingBalance))
        _target = State(initialValue: existing.map { $0.hasTarget ? moneyEditString($0.target) : "" } ?? "")
    }

    private var parsedMonthly: Money? { Money.parse(monthly) }
    private var canSave: Bool {
        !name.isEmpty && parsedMonthly != nil
            && (target.isEmpty || Money.parse(target) != nil)
            && (startingBalance.isEmpty || Money.parse(startingBalance) != nil)
    }

    var body: some View {
        FormSheet(title: loc(existing == nil ? .commonAdd : .commonEdit),
                  canSave: canSave, onSave: save) {
            Section {
                TextField(loc(.formName), text: $name)
                Picker(loc(.formCategory), selection: $category) {
                    ForEach(SavingsCategory.allCases, id: \.self) { c in
                        Label(c.localizedName(loc.localization), systemImage: c.systemImage).tag(c)
                    }
                }
                MoneyRowField(label: loc(.formMonthlyContribution), text: $monthly)
            }
            Section {
                DatePicker(loc(.formStartDate), selection: $startDate, displayedComponents: .date)
                MoneyRowField(label: loc(.formStartingBalance), text: $startingBalance)
                MoneyRowField(label: loc(.formTarget), text: $target)
            }
        }
    }

    private func save() {
        guard let monthlyAmount = parsedMonthly else { return }
        let item = SavingsGoal(id: existing?.id ?? UUID(), name: name, category: category,
                               target: Money.parse(target) ?? .zero,
                               monthlyContribution: monthlyAmount,
                               startingBalance: Money.parse(startingBalance) ?? .zero,
                               startDate: startDate)
        Task { await model.upsertSavingsGoal(item); dismiss() }
    }
}

// MARK: - One-off bill

struct BillFormSheet: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var loc: Localizer
    @Environment(\.dismiss) private var dismiss

    let existing: OneOffBill?
    @State private var provider: String
    @State private var amount: String
    @State private var dueDate: Date
    @State private var status: BillStatus
    @State private var notes: String

    init(existing: OneOffBill?) {
        self.existing = existing
        _provider = State(initialValue: existing?.provider ?? "")
        _amount = State(initialValue: moneyEditString(existing?.amount))
        _dueDate = State(initialValue: existing?.dueDate ?? Date())
        _status = State(initialValue: existing?.status ?? .open)
        _notes = State(initialValue: existing?.notes ?? "")
    }

    private var parsed: Money? { Money.parse(amount) }
    private var canSave: Bool { !provider.isEmpty && parsed != nil }

    var body: some View {
        FormSheet(title: loc(existing == nil ? .commonAdd : .commonEdit),
                  canSave: canSave, onSave: save) {
            Section {
                TextField(loc(.billsProvider), text: $provider)
                MoneyRowField(label: loc(.formAmount), text: $amount)
                DatePicker(loc(.billsDueDate), selection: $dueDate, displayedComponents: .date)
                Picker(loc(.formStatus), selection: $status) {
                    Text(loc(.billsStatusOpen)).tag(BillStatus.open)
                    Text(loc(.billsStatusPaid)).tag(BillStatus.paid)
                }.pickerStyle(.segmented)
            }
            Section(loc(.formNotes)) {
                TextField(loc(.formNotes), text: $notes, axis: .vertical).lineLimit(2...4)
            }
        }
    }

    private func save() {
        guard let amt = parsed else { return }
        let bill = OneOffBill(id: existing?.id ?? UUID(), provider: provider, amount: amt,
                              dueDate: dueDate, status: status,
                              notes: notes.isEmpty ? nil : notes)
        Task { await model.upsertBill(bill); dismiss() }
    }
}

// MARK: - Debt (Schuld)

struct DebtFormSheet: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var loc: Localizer
    @Environment(\.dismiss) private var dismiss

    let existing: DebtItem?
    @State private var creditor: String
    @State private var amount: String
    @State private var type: DebtType
    @State private var hasDate: Bool
    @State private var date: Date
    @State private var reference: String
    @State private var notes: String

    init(existing: DebtItem?) {
        self.existing = existing
        _creditor = State(initialValue: existing?.creditor ?? "")
        _amount = State(initialValue: moneyEditString(existing?.amount))
        _type = State(initialValue: existing?.type ?? .openClaim)
        _hasDate = State(initialValue: existing?.date != nil)
        _date = State(initialValue: existing?.date ?? Date())
        _reference = State(initialValue: existing?.reference ?? "")
        _notes = State(initialValue: existing?.notes ?? "")
    }

    private var parsed: Money? { Money.parse(amount) }
    private var canSave: Bool { !creditor.isEmpty && parsed != nil }

    var body: some View {
        FormSheet(title: loc(existing == nil ? .commonAdd : .commonEdit),
                  canSave: canSave, onSave: save) {
            Section {
                TextField(loc(.debtCreditor), text: $creditor)
                MoneyRowField(label: loc(.formAmount), text: $amount)
                Picker(loc(.debtType), selection: $type) {
                    ForEach(DebtType.allCases, id: \.self) { t in
                        Label(t.localizedName(loc.localization), systemImage: t.systemImage).tag(t)
                    }
                }
            }
            Section {
                Toggle(loc(.debtDate), isOn: $hasDate.animation())
                if hasDate {
                    DatePicker(loc(.debtDate), selection: $date, displayedComponents: .date)
                }
                TextField(loc(.debtReference), text: $reference)
            }
            Section(loc(.formNotes)) {
                TextField(loc(.formNotes), text: $notes, axis: .vertical).lineLimit(2...4)
            }
        }
    }

    private func save() {
        guard let amt = parsed else { return }
        let debt = DebtItem(id: existing?.id ?? UUID(), creditor: creditor, amount: amt,
                            type: type, date: hasDate ? date : nil,
                            reference: reference.isEmpty ? nil : reference,
                            notes: notes.isEmpty ? nil : notes)
        Task { await model.upsertDebt(debt); dismiss() }
    }
}
