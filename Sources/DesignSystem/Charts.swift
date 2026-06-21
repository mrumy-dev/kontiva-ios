import SwiftUI
import Charts
import KontivaCore

/// Convert exact Rappen to CHF as a Double — **presentation only**, for plotting.
/// All real money math stays in Int64 Rappen.
private func chf(_ money: Money) -> Double { Double(money.rappen) / 100.0 }

/// One labelled slice of a donut.
struct DonutSlice: Identifiable {
    let id = UUID()
    let label: String
    let amount: Money
    let color: Color
}

/// A polished donut with a centred headline value and a legend. On the phone the
/// legend sits *below* the ring (full width) rather than beside it.
struct AllocationDonut: View {
    let slices: [DonutSlice]
    let centerLabel: String
    let centerValue: Money
    var centerCaption: String? = nil

    private var shown: [DonutSlice] { slices.filter { $0.amount.isPositive } }
    private var total: Money { shown.map(\.amount).total() }

    var body: some View {
        VStack(spacing: KontivaTheme.Space.md) {
            donut
            legend
        }
    }

    private var donut: some View {
        Chart(shown) { slice in
            SectorMark(angle: .value("CHF", chf(slice.amount)),
                       innerRadius: .ratio(0.72), angularInset: 1.6)
                .cornerRadius(6)
                .foregroundStyle(slice.color)
        }
        .frame(width: 200, height: 200)
        .shadow(color: .black.opacity(0.06), radius: 9, y: 3)
        .overlay {
            VStack(spacing: 2) {
                Text(centerLabel.uppercased())
                    .font(.system(size: 9, weight: .semibold)).tracking(0.6)
                    .foregroundStyle(KontivaTheme.textTertiary).multilineTextAlignment(.center)
                Text(centerValue.formattedCHF())
                    .font(.system(size: 21, weight: .bold)).monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(centerValue.isNegative ? KontivaTheme.swissRed : KontivaTheme.textPrimary)
                    .lineLimit(1).minimumScaleFactor(0.55)
                if let centerCaption {
                    Text(centerCaption).font(.system(size: 9.5))
                        .foregroundStyle(KontivaTheme.textTertiary).lineLimit(1)
                }
            }
            .frame(width: 128)
        }
    }

    private var legend: some View {
        VStack(spacing: 0) {
            ForEach(Array(shown.enumerated()), id: \.element.id) { index, slice in
                if index > 0 { Divider().opacity(0.4) }
                HStack(spacing: KontivaTheme.Space.sm) {
                    Circle().fill(slice.color).frame(width: 10, height: 10)
                    Text(slice.label).font(.system(size: 14))
                        .foregroundStyle(KontivaTheme.textSecondary).lineLimit(1)
                    Spacer(minLength: KontivaTheme.Space.md)
                    Text(slice.amount.formattedCHF())
                        .font(.system(size: 14, weight: .semibold)).monospacedDigit()
                        .foregroundStyle(KontivaTheme.textPrimary)
                    Text("\(slice.amount.percent(of: total))%")
                        .font(.system(size: 11, weight: .semibold)).monospacedDigit()
                        .foregroundStyle(slice.color)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(slice.color.opacity(0.14), in: Capsule())
                }
                .padding(.vertical, 9)
            }
        }
    }
}

/// Donut showing where this month's net income goes.
struct SpendingDonut: View {
    let availability: MonthlyAvailability
    let loc: Localization

    private var slices: [DonutSlice] {
        var result: [DonutSlice] = []
        func add(_ key: L10nKey, _ money: Money, _ color: Color) {
            if money.isPositive {
                result.append(DonutSlice(label: loc.string(key), amount: money, color: color))
            }
        }
        add(.overviewRecurringFixed, availability.recurringFixedCosts, KontivaTheme.chartFixed)
        add(.overviewPlannedVariable, availability.plannedVariableBudgets, KontivaTheme.chartVariable)
        add(.billsTitle, availability.openBillsDueThisMonth + availability.overdueOpenBills, KontivaTheme.chartBills)
        add(.overviewPlannedSavings, availability.plannedSavings, KontivaTheme.chartSavings)
        add(.overviewAvailableThisMonth, availability.available, KontivaTheme.chartAvailable)
        return result
    }

    private var centerCaption: String? {
        let income = availability.netIncomeThisMonth
        guard income.isPositive, !availability.available.isNegative else { return nil }
        return "\(availability.available.percent(of: income))% \(loc.string(.overviewAllocationOf))"
    }

    var body: some View {
        AllocationDonut(slices: slices,
                        centerLabel: loc.string(.overviewAvailableThisMonth),
                        centerValue: availability.available,
                        centerCaption: centerCaption)
    }
}

/// A line+area trend of a money value over months.
struct TrendChart: View {
    struct Point: Identifiable { let id = UUID(); let month: Date; let value: Money }
    let points: [Point]
    let locale: Locale
    var color: Color = KontivaTheme.chartAvailable

    var body: some View {
        Chart(points) { p in
            AreaMark(x: .value("Monat", p.month, unit: .month), y: .value("CHF", chf(p.value)))
                .interpolationMethod(.catmullRom)
                .foregroundStyle(.linearGradient(colors: [color.opacity(0.25), color.opacity(0.02)],
                                                 startPoint: .top, endPoint: .bottom))
            LineMark(x: .value("Monat", p.month, unit: .month), y: .value("CHF", chf(p.value)))
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2.5)).foregroundStyle(color)
            PointMark(x: .value("Monat", p.month, unit: .month), y: .value("CHF", chf(p.value)))
                .foregroundStyle(color).symbolSize(20)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .month)) { _ in
                AxisGridLine().foregroundStyle(KontivaTheme.softBorder.opacity(0.4))
                AxisValueLabel(format: .dateTime.month(.abbreviated).locale(locale)).font(.caption2)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine().foregroundStyle(KontivaTheme.softBorder.opacity(0.4))
                AxisValueLabel().font(.caption2)
            }
        }
        .frame(height: 170)
    }
}

/// A tiny, axis-less sparkline for an at-a-glance trend next to a headline.
struct Sparkline: View {
    let values: [Double]
    var color: Color = KontivaTheme.chartAvailable
    var width: CGFloat = 84
    var height: CGFloat = 30

    var body: some View {
        Chart(Array(values.enumerated()), id: \.offset) { index, value in
            LineMark(x: .value("i", index), y: .value("v", value))
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round)).foregroundStyle(color)
        }
        .chartXAxis(.hidden).chartYAxis(.hidden)
        .frame(width: width, height: height)
    }
}
