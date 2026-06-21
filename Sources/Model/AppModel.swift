import SwiftUI
import KontivaCore
import KontivaPersistence

/// The iOS app model: the lock gate + the decrypted dataset + all the derived
/// figures the screens bind to. Every calculation reuses the shared KontivaKit
/// engines (AvailabilityEngine, BillClassifier, savings accumulation) — money math
/// stays in Int64 Rappen.
@MainActor
final class AppModel: ObservableObject {
    enum LockState: Equatable { case needsSetup, locked, unlocked }

    @Published private(set) var lockState: LockState
    @Published private(set) var dataset: AppDataset = .empty
    @Published var isWorking = false
    @Published var justUnlocked = false

    /// Selected bottom tab (0 = Übersicht … 4 = Mehr). Lets one screen jump to another.
    @Published var selectedTab = 0

    /// Month the screens are showing (recurring data is the same; bills/standing
    /// orders/savings genuinely vary by date).
    @Published var selectedMonth: Date = Calendar.swiss.startOfMonth(for: Date())

    let localizer = Localizer()

    private let store: EncryptedStore

    init() {
        let location = (try? StoreLocation.applicationSupport())
            ?? StoreLocation(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent("Kontiva", isDirectory: true))
        let store = EncryptedStore(location: location)
        self.store = store
        self.lockState = store.hasExistingVault() ? .locked : .needsSetup
    }

    // MARK: Lock gate

    func setUp(passphrase: String) async {
        guard !passphrase.isEmpty else { return }
        isWorking = true; defer { isWorking = false }
        do {
            try await store.createVault(passphrase: passphrase)
            await refresh()
            lockState = .unlocked
        } catch { }
    }

    @discardableResult
    func unlock(passphrase: String) async -> Bool {
        isWorking = true; defer { isWorking = false }
        do {
            try await store.unlock(passphrase: passphrase)
            await refresh()
            justUnlocked = true
            lockState = .unlocked
            return true
        } catch { return false }
    }

    func lock() async {
        await store.lock()
        dataset = .empty
        lockState = .locked
    }

    private func refresh() async {
        dataset = (try? await store.snapshot()) ?? .empty
    }

    // MARK: Month

    func shiftMonth(by months: Int) {
        if let shifted = Calendar.swiss.date(byAdding: .month, value: months, to: selectedMonth) {
            selectedMonth = Calendar.swiss.startOfMonth(for: shifted)
        }
    }
    func goToCurrentMonth() { selectedMonth = Calendar.swiss.startOfMonth(for: Date()) }
    var isCurrentMonth: Bool {
        Calendar.swiss.isDate(selectedMonth, equalTo: Date(), toGranularity: .month)
    }

    // MARK: Dataset accessors

    var incomes: [Income] { dataset.incomes }
    var fixedCosts: [RecurringFixedExpense] { dataset.fixedCosts }
    var variableBudgets: [VariableMonthlyBudget] { dataset.variableBudgets }
    var savingsGoals: [SavingsGoal] { dataset.savingsGoals }
    var bills: [OneOffBill] { dataset.bills }
    var debts: [DebtItem] { dataset.debts }
    var household: Household? { dataset.household }

    var hasAnyPlanningData: Bool {
        !incomes.isEmpty || !fixedCosts.isEmpty || !variableBudgets.isEmpty
    }

    // MARK: Derived figures (shared engine)

    var availability: MonthlyAvailability {
        AvailabilityEngine.compute(
            incomes: incomes, fixedCosts: fixedCosts, variableBudgets: variableBudgets,
            bills: bills, savingsGoals: savingsGoals, asOf: selectedMonth)
    }

    func trend(months: Int = 6) -> [(month: Date, available: Money, savings: Money)] {
        let cal = Calendar.swiss
        return (0..<months).reversed().compactMap { offset in
            guard let shifted = cal.date(byAdding: .month, value: -offset, to: selectedMonth) else { return nil }
            let m = cal.startOfMonth(for: shifted)
            let a = AvailabilityEngine.compute(
                incomes: incomes, fixedCosts: fixedCosts, variableBudgets: variableBudgets,
                bills: bills, savingsGoals: savingsGoals, asOf: m)
            let saved = savingsGoals.map { $0.accumulated(asOf: m) }.total()
            return (m, a.available, saved)
        }
    }

    var totalMonthlySavings: Money { savingsGoals.compactMap(\.monthlyContribution).total() }
    var totalAccumulatedSavings: Money { savingsGoals.map { $0.accumulated(asOf: selectedMonth) }.total() }

    // MARK: Debts (overdue bills flow in automatically, as of today)

    var overdueBills: [OneOffBill] {
        bills.filter { BillClassifier.state(of: $0, asOf: Date()) == .overdue }
    }
    var totalOverdueBills: Money { overdueBills.map(\.amount).total() }
    var totalManualDebt: Money { debts.map(\.amount).total() }
    var totalDebt: Money { totalOverdueBills + totalManualDebt }
    var hasAnyDebt: Bool { !overdueBills.isEmpty || !debts.isEmpty }
}
