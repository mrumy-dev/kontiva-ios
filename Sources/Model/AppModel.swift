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

    /// Non-sensitive UI preferences (language). Persisted in UserDefaults so they
    /// apply on the lock screen, before the encrypted store is unlocked.
    @Published var settings = AppSettings()
    /// Idle auto-lock interval (stored encrypted in the vault, mirrored here).
    @Published var autoLock: AutoLockInterval = .fiveMinutes
    /// Whether a passphrase is stored behind biometrics (Face ID / Touch ID).
    @Published private(set) var biometricEnabled = BiometricVault.hasStored
    var biometricKind: BiometricKind { Biometrics.kind }

    let localizer: Localizer

    private let store: EncryptedStore
    /// Held only while unlocked, to enrol biometrics without re-prompting; cleared on lock.
    private var sessionPassphrase: String?
    /// When the app was last backgrounded, for idle auto-lock on return.
    private var backgroundedAt: Date?

    private static let languageKey = "kontiva.ui.language"
    private static let accentKey = "kontiva.ui.accent"

    init() {
        let savedLanguage = UserDefaults.standard.string(forKey: Self.languageKey)
            .flatMap(AppLanguage.init(rawValue:)) ?? .deCH
        self.localizer = Localizer(language: savedLanguage)
        let location = (try? StoreLocation.applicationSupport())
            ?? StoreLocation(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent("Kontiva", isDirectory: true))
        let store = EncryptedStore(location: location)
        self.store = store
        self.lockState = store.hasExistingVault() ? .locked : .needsSetup
        self.settings.language = savedLanguage
        // Accent theme is a non-sensitive UI preference (UserDefaults), so it
        // applies on the lock screen and persists across launches.
        let savedAccent = UserDefaults.standard.string(forKey: Self.accentKey)
            .flatMap(AccentTheme.init(rawValue:)) ?? .swissRed
        self.settings.accent = savedAccent
        KontivaTheme.accent = savedAccent.color
    }

    // MARK: Lock gate

    func setUp(passphrase: String) async {
        guard !passphrase.isEmpty else { return }
        isWorking = true; defer { isWorking = false }
        do {
            try await store.createVault(passphrase: passphrase)
            sessionPassphrase = passphrase
            await refresh()
            lockState = .unlocked
        } catch { }
    }

    @discardableResult
    func unlock(passphrase: String) async -> Bool {
        isWorking = true; defer { isWorking = false }
        do {
            try await store.unlock(passphrase: passphrase)
            sessionPassphrase = passphrase
            await refresh()
            justUnlocked = true
            lockState = .unlocked
            return true
        } catch { return false }
    }

    func lock() async {
        await store.lock()
        sessionPassphrase = nil
        dataset = .empty
        lockState = .locked
    }

    private func refresh() async {
        dataset = (try? await store.snapshot()) ?? .empty
        autoLock = dataset.securitySettings.autoLock
    }

    // MARK: Settings

    func setLanguage(_ language: AppLanguage) {
        guard language != localizer.language else { return }
        settings.language = language
        localizer.setLanguage(language)
        UserDefaults.standard.set(language.rawValue, forKey: Self.languageKey)
    }

    /// Change the accent theme. Applies immediately across the app and persists.
    func setAccent(_ accent: AccentTheme) {
        guard accent != settings.accent else { return }
        settings.accent = accent
        KontivaTheme.accent = accent.color
        UserDefaults.standard.set(accent.rawValue, forKey: Self.accentKey)
    }

    func setAutoLock(_ interval: AutoLockInterval) async {
        autoLock = interval
        await mutate { $0.securitySettings.autoLock = interval }
    }

    func updateProfile(name: String, avatarName: String?, canton: Canton?) async {
        await mutate { ds in
            var h = ds.household ?? Household(name: name)
            h.name = name; h.avatarName = avatarName; h.canton = canton
            ds.household = h
        }
    }

    @discardableResult
    func changePassphrase(old: String, new: String) async -> Bool {
        isWorking = true; defer { isWorking = false }
        do {
            try await store.changePassphrase(old: old, new: new)
            sessionPassphrase = new
            if biometricEnabled { _ = BiometricVault.store(passphrase: new) }   // keep biometrics in sync
            return true
        } catch { return false }
    }

    func deleteAllLocalData() async {
        try? await store.deleteAllData()
        disableBiometric()
        sessionPassphrase = nil
        dataset = .empty
        lockState = .needsSetup
    }

    // MARK: Biometric unlock (Face ID / Touch ID)

    /// Store the current passphrase behind biometrics. Requires being unlocked.
    @discardableResult
    func enableBiometric() -> Bool {
        guard let passphrase = sessionPassphrase else { return false }
        let ok = BiometricVault.store(passphrase: passphrase)
        biometricEnabled = BiometricVault.hasStored
        return ok
    }

    func disableBiometric() {
        BiometricVault.delete()
        biometricEnabled = false
    }

    /// Prompt biometrics and unlock with the stored passphrase. Returns success.
    @discardableResult
    func unlockWithBiometrics() async -> Bool {
        guard biometricEnabled, biometricKind.isAvailable else { return false }
        guard let passphrase = await BiometricVault.retrieve(reason: localizer.string(.lockTitle)) else { return false }
        let ok = await unlock(passphrase: passphrase)
        if !ok { disableBiometric() }   // stored passphrase no longer valid → clear it
        return ok
    }

    // MARK: Backup & restore

    /// Produce a portable encrypted backup blob, or nil on failure.
    func makeBackupData(passphrase: String) async -> Data? {
        guard lockState == .unlocked else { return nil }
        isWorking = true; defer { isWorking = false }
        return try? await store.makeBackup(backupPassphrase: passphrase, appVersion: AppInfo.version)
    }

    /// Validate a backup and return its preview (counts/date), or nil if the
    /// passphrase is wrong or the file is invalid.
    func previewBackup(data: Data, passphrase: String) async -> BackupPreview? {
        isWorking = true; defer { isWorking = false }
        return try? await store.previewBackup(data: data, backupPassphrase: passphrase)
    }

    /// Guarded restore — caller must have confirmed the destructive replace.
    @discardableResult
    func restoreFromBackup(data: Data, passphrase: String) async -> Bool {
        guard lockState == .unlocked else { return false }
        isWorking = true; defer { isWorking = false }
        do {
            try await store.restoreBackup(data: data, backupPassphrase: passphrase)
            await refresh()
            return true
        } catch { return false }
    }

    // MARK: Auto-lock (background idle)

    func appDidEnterBackground() { backgroundedAt = Date() }

    func appWillEnterForeground() {
        defer { backgroundedAt = nil }
        // `.never` → seconds is nil → no auto-lock. Otherwise lock if idle past the limit.
        guard lockState == .unlocked, let since = backgroundedAt, let limit = autoLock.seconds else { return }
        if Date().timeIntervalSince(since) >= limit {
            Task { await lock() }
        }
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

    var insights: [Insight] {
        InsightEngine.analyze(
            incomes: incomes, fixedCosts: fixedCosts, variableBudgets: variableBudgets,
            bills: bills, savingsGoals: savingsGoals, availability: availability, asOf: selectedMonth)
    }

    // MARK: Debts (overdue bills flow in automatically, as of today)

    var overdueBills: [OneOffBill] {
        bills.filter { BillClassifier.state(of: $0, asOf: Date()) == .overdue }
    }
    var totalOverdueBills: Money { overdueBills.map(\.amount).total() }
    var totalManualDebt: Money { debts.map(\.amount).total() }
    var totalDebt: Money { totalOverdueBills + totalManualDebt }
    var hasAnyDebt: Bool { !overdueBills.isEmpty || !debts.isEmpty }

    // MARK: CRUD — every change is persisted, encrypted, via the shared store.

    private func mutate(_ block: @Sendable @escaping (inout AppDataset) -> Void) async {
        guard lockState == .unlocked else { return }
        try? await store.mutate(block)
        await refresh()
    }

    func upsertIncome(_ income: Income) async {
        await mutate { ds in
            if let i = ds.incomes.firstIndex(where: { $0.id == income.id }) { ds.incomes[i] = income }
            else { ds.incomes.append(income) }
        }
    }
    func deleteIncome(_ id: UUID) async { await mutate { $0.incomes.removeAll { $0.id == id } } }

    func upsertFixedCost(_ item: RecurringFixedExpense) async {
        await mutate { ds in
            if let i = ds.fixedCosts.firstIndex(where: { $0.id == item.id }) { ds.fixedCosts[i] = item }
            else { ds.fixedCosts.append(item) }
        }
    }
    func deleteFixedCost(_ id: UUID) async { await mutate { $0.fixedCosts.removeAll { $0.id == id } } }

    func upsertVariableBudget(_ item: VariableMonthlyBudget) async {
        await mutate { ds in
            if let i = ds.variableBudgets.firstIndex(where: { $0.id == item.id }) { ds.variableBudgets[i] = item }
            else { ds.variableBudgets.append(item) }
        }
    }
    func deleteVariableBudget(_ id: UUID) async { await mutate { $0.variableBudgets.removeAll { $0.id == id } } }

    func upsertSavingsGoal(_ item: SavingsGoal) async {
        await mutate { ds in
            if let i = ds.savingsGoals.firstIndex(where: { $0.id == item.id }) { ds.savingsGoals[i] = item }
            else { ds.savingsGoals.append(item) }
        }
    }
    func deleteSavingsGoal(_ id: UUID) async { await mutate { $0.savingsGoals.removeAll { $0.id == id } } }

    func upsertBill(_ bill: OneOffBill) async {
        await mutate { ds in
            if let i = ds.bills.firstIndex(where: { $0.id == bill.id }) { ds.bills[i] = bill }
            else { ds.bills.append(bill) }
        }
    }
    func deleteBill(_ id: UUID) async { await mutate { $0.bills.removeAll { $0.id == id } } }

    func upsertDebt(_ debt: DebtItem) async {
        await mutate { ds in
            if let i = ds.debts.firstIndex(where: { $0.id == debt.id }) { ds.debts[i] = debt }
            else { ds.debts.append(debt) }
        }
    }
    func deleteDebt(_ id: UUID) async { await mutate { $0.debts.removeAll { $0.id == id } } }

    // Reordering (display order only — the maths is order-independent).
    func moveIncomes(from: IndexSet, to: Int) async { await mutate { $0.incomes.move(fromOffsets: from, toOffset: to) } }
    func moveFixedCosts(from: IndexSet, to: Int) async { await mutate { $0.fixedCosts.move(fromOffsets: from, toOffset: to) } }
    func moveVariableBudgets(from: IndexSet, to: Int) async { await mutate { $0.variableBudgets.move(fromOffsets: from, toOffset: to) } }
    func moveSavingsGoals(from: IndexSet, to: Int) async { await mutate { $0.savingsGoals.move(fromOffsets: from, toOffset: to) } }
}
