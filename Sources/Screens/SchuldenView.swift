import SwiftUI
import KontivaCore

/// Schulden (debts): a calm, supportive overview of what the household owes.
/// Overdue bills flow in automatically from Rechnungen; the user can record formal
/// Swiss debt-enforcement stages (Betreibung, Pfändung, Verlustschein) and other
/// debts. Information, not legal advice. Ported from the desktop for iOS.
struct SchuldenView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var loc: Localizer
    @State private var editing: DebtSheet?

    enum DebtSheet: Identifiable {
        case edit(DebtItem?)
        var id: String { if case .edit(let d) = self { return d?.id.uuidString ?? "new" }; return "new" }
    }

    private var debtsByType: [(type: DebtType, items: [DebtItem])] {
        Dictionary(grouping: model.debts, by: \.type)
            .sorted { $0.key.severityRank < $1.key.severityRank }
            .map { (type: $0.key, items: $0.value.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }) }
    }

    // No NavigationStack here — this screen is pushed inside the "Mehr" tab's stack.
    var body: some View {
        Group {
            if !model.hasAnyDebt {
                ScreenScroll {
                    KontivaCard {
                        EmptyState(systemImage: "checkmark.seal",
                                   title: loc(.navSchulden),
                                   message: loc(.schuldenEmpty),
                                   actionTitle: loc(.schuldenAddCta)) { editing = .edit(nil) }
                    }
                }
            } else {
                ScreenScroll {
                    summaryCard
                    if !model.overdueBills.isEmpty { overdueBillsCard }
                    ForEach(debtsByType, id: \.type) { group in
                        typeCard(group.type, group.items)
                    }
                    guidanceCard
                }
                .animation(.snappy, value: model.dataset)
            }
        }
        .background(KontivaTheme.pageGradient.ignoresSafeArea())
        .navigationTitle(loc(.navSchulden))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { editing = .edit(nil) } label: { Image(systemName: "plus") }
                    .tint(KontivaTheme.accent)
                    .symbolEffect(.bounce, value: model.debts.count)
            }
        }
        .sheet(item: $editing) { route in
            if case .edit(let debt) = route {
                DebtFormSheet(existing: debt).environmentObject(model).environmentObject(loc)
            }
        }
    }

    private var summaryCard: some View {
        KontivaCard {
            VStack(alignment: .leading, spacing: KontivaTheme.Space.md) {
                HStack(spacing: KontivaTheme.Space.sm) {
                    KontivaIconTile("creditcard")
                    VStack(alignment: .leading, spacing: 1) {
                        CardTitle(loc(.schuldenTotal))
                        Text(model.totalDebt.formattedCHF())
                            .font(.title2.weight(.semibold)).monospacedDigit()
                            .contentTransition(.numericText()).foregroundStyle(KontivaTheme.textPrimary)
                    }
                    Spacer(minLength: 0)
                }
                Divider()
                HStack(spacing: KontivaTheme.Space.lg) {
                    SummaryStat(loc(.schuldenOverdueBills), value: model.totalOverdueBills.formattedCHF(),
                                color: model.totalOverdueBills.isZero ? KontivaTheme.textSecondary : KontivaTheme.swissRed)
                    SummaryStat(loc(.schuldenRecorded), value: model.totalManualDebt.formattedCHF(),
                                color: model.totalManualDebt.isZero ? KontivaTheme.textSecondary : KontivaTheme.textPrimary)
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var overdueBillsCard: some View {
        let items = model.overdueBills.sorted { $0.dueDate < $1.dueDate }
        return KontivaCard {
            VStack(alignment: .leading, spacing: KontivaTheme.Space.md) {
                HStack(spacing: KontivaTheme.Space.sm) {
                    KontivaIconTile("doc.text.fill", color: KontivaTheme.swissRed)
                    Text(loc(.schuldenOverdueBills)).font(.title3.weight(.semibold)).foregroundStyle(KontivaTheme.textPrimary)
                    CountBadge(items.count, color: KontivaTheme.swissRed)
                    Spacer(minLength: KontivaTheme.Space.sm)
                    Text(model.totalOverdueBills.formattedCHF())
                        .font(.title3.weight(.semibold)).monospacedDigit().foregroundStyle(KontivaTheme.textPrimary)
                }
                Divider()
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { idx, bill in
                        if idx > 0 { Divider().background(KontivaTheme.softBorder.opacity(0.4)) }
                        row(icon: "doc.text.fill", color: KontivaTheme.swissRed,
                            title: bill.provider,
                            subtitle: SwissDate.medium(bill.dueDate, locale: loc.language.locale),
                            amount: bill.amount)
                            .contentShape(Rectangle())
                            .onTapGesture { model.selectedTab = 2 }   // managed in Rechnungen
                    }
                }
                Text(loc(.schuldenManagedInBills)).font(.caption).foregroundStyle(KontivaTheme.textTertiary)
            }
        }
    }

    private func typeCard(_ type: DebtType, _ items: [DebtItem]) -> some View {
        let sum = items.map(\.amount).total()
        return KontivaCard {
            VStack(alignment: .leading, spacing: KontivaTheme.Space.md) {
                HStack(spacing: KontivaTheme.Space.sm) {
                    KontivaIconTile(type.systemImage, color: type.color)
                    Text(type.localizedName(loc.localization)).font(.title3.weight(.semibold)).foregroundStyle(KontivaTheme.textPrimary)
                    CountBadge(items.count, color: type.color)
                    Spacer(minLength: KontivaTheme.Space.sm)
                    Text(sum.formattedCHF())
                        .font(.title3.weight(.semibold)).monospacedDigit().foregroundStyle(KontivaTheme.textPrimary)
                }
                Divider()
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { idx, debt in
                        if idx > 0 { Divider().background(KontivaTheme.softBorder.opacity(0.4)) }
                        row(icon: type.systemImage, color: type.color,
                            title: debt.creditor, subtitle: debtSubtitle(debt), amount: debt.amount)
                            .contentShape(Rectangle())
                            .onTapGesture { editing = .edit(debt) }
                            .contextMenu {
                                Button(loc(.commonEdit), systemImage: "pencil") { editing = .edit(debt) }
                                Button(loc(.commonDelete), systemImage: "trash", role: .destructive) {
                                    Task { await model.deleteDebt(debt.id) }
                                }
                            }
                    }
                }
            }
        }
    }

    private func debtSubtitle(_ debt: DebtItem) -> String? {
        var parts: [String] = []
        if let date = debt.date { parts.append(SwissDate.medium(date, locale: loc.language.locale)) }
        if let ref = debt.reference, !ref.isEmpty { parts.append(ref) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func row(icon: String, color: Color, title: String, subtitle: String?, amount: Money) -> some View {
        HStack(spacing: KontivaTheme.Space.sm) {
            KontivaIconTile(icon, color: color, size: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).foregroundStyle(KontivaTheme.textPrimary)
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(KontivaTheme.textTertiary).lineLimit(1)
                }
            }
            Spacer(minLength: KontivaTheme.Space.md)
            Text(amount.formattedCHF()).font(.body.weight(.medium)).monospacedDigit().foregroundStyle(KontivaTheme.textPrimary)
        }
        .padding(.vertical, KontivaTheme.Space.xs)
        .accessibilityElement(children: .combine)
    }

    // MARK: Guidance (help clearing debt)

    private struct Tip { let icon: String; let title: L10nKey; let body: L10nKey }
    private let tips: [Tip] = [
        Tip(icon: "bubble.left.and.bubble.right.fill", title: .schuldenTipContactTitle, body: .schuldenTipContactBody),
        Tip(icon: "calendar.badge.exclamationmark", title: .schuldenTipBetreibungTitle, body: .schuldenTipBetreibungBody),
        Tip(icon: "shield.fill", title: .schuldenTipExistenzminimumTitle, body: .schuldenTipExistenzminimumBody),
        Tip(icon: "scroll.fill", title: .schuldenTipVerlustscheinTitle, body: .schuldenTipVerlustscheinBody),
        Tip(icon: "heart.fill", title: .schuldenTipCounselingTitle, body: .schuldenTipCounselingBody),
    ]

    private var guidanceCard: some View {
        KontivaCard {
            VStack(alignment: .leading, spacing: KontivaTheme.Space.md) {
                HStack(spacing: KontivaTheme.Space.sm) {
                    KontivaIconTile("lightbulb.fill")
                    Text(loc(.schuldenGuidanceTitle)).font(.title3.weight(.semibold)).foregroundStyle(KontivaTheme.textPrimary)
                    Spacer(minLength: 0)
                }
                Divider()
                VStack(alignment: .leading, spacing: KontivaTheme.Space.md) {
                    ForEach(Array(tips.enumerated()), id: \.offset) { _, tip in
                        HStack(alignment: .top, spacing: KontivaTheme.Space.sm) {
                            Image(systemName: tip.icon)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(KontivaTheme.accent).frame(width: 22)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(loc(tip.title)).font(.subheadline.weight(.semibold)).foregroundStyle(KontivaTheme.textPrimary)
                                Text(loc(tip.body)).font(.caption).foregroundStyle(KontivaTheme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
                Divider()
                Text(loc(.schuldenDisclaimer)).font(.caption2).foregroundStyle(KontivaTheme.textTertiary)
            }
        }
    }
}
