import SwiftUI
import KontivaCore

/// Rechnungen: one-off bills, grouped by their state for the selected month
/// (overdue → due this month → upcoming → paid). Card-based, with a tap-to-tick
/// "mark paid" checkbox. Ported from the desktop for iOS.
struct BillsView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var loc: Localizer
    @State private var sheet: BillSheet?
    @State private var search = ""

    enum BillSheet: Identifiable {
        case edit(OneOffBill?)
        var id: String { if case .edit(let b) = self { return b?.id.uuidString ?? "new" }; return "new" }
    }

    private var month: Date { model.selectedMonth }

    private var filtered: [OneOffBill] {
        model.bills.filter { search.isEmpty || $0.provider.localizedCaseInsensitiveContains(search) }
    }

    private let order: [BillState] = [.overdue, .dueThisMonth, .future, .paid]

    private func bills(in state: BillState) -> [OneOffBill] {
        filtered.filter { BillClassifier.state(of: $0, asOf: month) == state }.sorted { $0.dueDate < $1.dueDate }
    }
    private func total(in state: BillState) -> Money {
        BillClassifier.amount(in: state, bills: model.bills, asOf: month)
    }

    var body: some View {
        NavigationStack {
            Group {
                if model.bills.isEmpty {
                    ScreenScroll {
                        KontivaCard {
                            EmptyState(systemImage: "doc.text",
                                       title: loc(.billsTitle),
                                       message: loc(.billsEmpty),
                                       actionTitle: loc(.billsAddCta)) { sheet = .edit(nil) }
                        }
                    }
                } else {
                    ScreenScroll {
                        MonthSelector().frame(maxWidth: .infinity, alignment: .center)
                        summaryCard
                        ForEach(order, id: \.self) { state in
                            let items = bills(in: state)
                            if !items.isEmpty { groupCard(state, items) }
                        }
                    }
                    .animation(.snappy, value: model.dataset)
                }
            }
            .background(KontivaTheme.pageGradient.ignoresSafeArea())
            .navigationTitle(loc(.billsTitle))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { sheet = .edit(nil) } label: { Image(systemName: "plus") }
                        .tint(KontivaTheme.accent)
                        .symbolEffect(.bounce, value: model.bills.count)
                }
            }
            .sheet(item: $sheet) { route in
                if case .edit(let bill) = route {
                    BillFormSheet(existing: bill).environmentObject(model).environmentObject(loc)
                }
            }
        }
    }

    private var summaryCard: some View {
        let overdue = total(in: .overdue)
        let due = total(in: .dueThisMonth)
        let paid = total(in: .paid)
        let open = overdue + due + total(in: .future)
        return KontivaCard {
            VStack(alignment: .leading, spacing: KontivaTheme.Space.md) {
                HStack(spacing: KontivaTheme.Space.sm) {
                    KontivaIconTile("doc.text.fill")
                    VStack(alignment: .leading, spacing: 1) {
                        CardTitle(loc(.billsOpenTotal))
                        Text(open.formattedCHF())
                            .font(.title2.weight(.semibold)).monospacedDigit()
                            .contentTransition(.numericText()).foregroundStyle(KontivaTheme.textPrimary)
                    }
                    Spacer(minLength: 0)
                }
                Divider()
                HStack(spacing: KontivaTheme.Space.md) {
                    SummaryStat(loc(.billsStateOverdue), value: overdue.formattedCHF(),
                                color: overdue.isZero ? KontivaTheme.textSecondary : KontivaTheme.swissRed)
                    SummaryStat(loc(.billsStateDueThisMonth), value: due.formattedCHF(),
                                color: due.isZero ? KontivaTheme.textSecondary : KontivaTheme.warning)
                    SummaryStat(loc(.billsStatusPaid), value: paid.formattedCHF(),
                                color: paid.isZero ? KontivaTheme.textSecondary : KontivaTheme.positive)
                }
            }
        }
    }

    private func groupCard(_ state: BillState, _ items: [OneOffBill]) -> some View {
        let display = BillStateDisplay(state)
        let sum = items.map(\.amount).total()
        return KontivaCard {
            VStack(alignment: .leading, spacing: KontivaTheme.Space.md) {
                HStack(spacing: KontivaTheme.Space.sm) {
                    KontivaIconTile(stateIcon(state), color: display.color)
                    Text(loc(display.labelKey)).font(.title3.weight(.semibold)).foregroundStyle(KontivaTheme.textPrimary)
                    CountBadge(items.count, color: display.color)
                    Spacer(minLength: KontivaTheme.Space.sm)
                    Text(sum.formattedCHF())
                        .font(.title3.weight(.semibold)).monospacedDigit()
                        .foregroundStyle(state == .paid ? KontivaTheme.textTertiary : KontivaTheme.textPrimary)
                }
                Divider()
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { idx, bill in
                        if idx > 0 { Divider().background(KontivaTheme.softBorder.opacity(0.4)) }
                        billRow(bill, state: state, accent: display.color)
                    }
                }
            }
        }
    }

    private func billRow(_ bill: OneOffBill, state: BillState, accent: Color) -> some View {
        let isPaid = bill.status == .paid
        return HStack(spacing: KontivaTheme.Space.sm) {
            Button { togglePaid(bill) } label: {
                Image(systemName: isPaid ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isPaid ? KontivaTheme.positive : accent.opacity(0.75))
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 1) {
                Text(bill.provider).foregroundStyle(KontivaTheme.textPrimary)
                    .strikethrough(isPaid, color: KontivaTheme.textTertiary)
                Text(SwissDate.medium(bill.dueDate, locale: loc.language.locale))
                    .font(.caption).foregroundStyle(KontivaTheme.textTertiary)
            }
            Spacer(minLength: KontivaTheme.Space.md)
            Text(bill.amount.formattedCHF())
                .font(.body.weight(.medium)).monospacedDigit()
                .foregroundStyle(isPaid ? KontivaTheme.textTertiary : KontivaTheme.textPrimary)
                .strikethrough(isPaid, color: KontivaTheme.textTertiary)
        }
        .padding(.vertical, KontivaTheme.Space.xs)
        .contentShape(Rectangle())
        .onTapGesture { sheet = .edit(bill) }
        .contextMenu {
            Button(loc(.commonEdit), systemImage: "pencil") { sheet = .edit(bill) }
            Button(loc(isPaid ? .billsMarkOpen : .billsMarkPaid),
                   systemImage: isPaid ? "arrow.uturn.backward" : "checkmark.circle") { togglePaid(bill) }
            Button(loc(.commonDelete), systemImage: "trash", role: .destructive) {
                Task { await model.deleteBill(bill.id) }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func stateIcon(_ state: BillState) -> String {
        switch state {
        case .overdue:      return "exclamationmark.triangle.fill"
        case .dueThisMonth: return "calendar.badge.clock"
        case .future:       return "calendar"
        case .paid:         return "checkmark.seal.fill"
        }
    }

    private func togglePaid(_ bill: OneOffBill) {
        var updated = bill
        updated.status = (bill.status == .paid) ? .open : .paid
        Task { await model.upsertBill(updated) }
    }
}
