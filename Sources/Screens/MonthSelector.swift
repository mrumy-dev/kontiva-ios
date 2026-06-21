import SwiftUI
import KontivaCore

/// Compact ◀ Month Year ▶ control for navigation toolbars, with a "Heute" jump
/// when not on the current month. Drives `AppModel.selectedMonth`.
struct MonthSelector: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var loc: Localizer

    var body: some View {
        HStack(spacing: KontivaTheme.Space.xs) {
            Button { withAnimation(.snappy) { model.shiftMonth(by: -1) } } label: {
                Image(systemName: "chevron.left")
            }
            Text(monthLabel)
                .font(.subheadline.weight(.semibold)).monospacedDigit()
                .contentTransition(.numericText())
            Button { withAnimation(.snappy) { model.shiftMonth(by: 1) } } label: {
                Image(systemName: "chevron.right")
            }
            if !model.isCurrentMonth {
                Button { withAnimation(.snappy) { model.goToCurrentMonth() } } label: {
                    Text(loc(.monthToday)).font(.caption.weight(.semibold))
                }
                .padding(.leading, KontivaTheme.Space.xxs)
            }
        }
        .tint(KontivaTheme.accent)
    }

    private var monthLabel: String {
        let f = DateFormatter()
        f.locale = loc.language.locale
        f.calendar = .swiss
        f.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return f.string(from: model.selectedMonth)
    }
}
