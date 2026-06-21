import SwiftUI
import KontivaCore

/// A calm, bordered surface used for grouping content.
struct KontivaCard<Content: View>: View {
    private let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .padding(KontivaTheme.Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: KontivaTheme.Radius.card, style: .continuous)
                    .fill(KontivaTheme.cardSurface))
            .overlay(
                RoundedRectangle(cornerRadius: KontivaTheme.Radius.card, style: .continuous)
                    .strokeBorder(KontivaTheme.softBorder.opacity(0.5), lineWidth: 1))
            .shadow(color: KontivaTheme.charcoal.opacity(0.05), radius: 12, x: 0, y: 4)
    }
}

/// A small labelled section title inside cards.
struct CardTitle: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold)).tracking(0.6)
            .foregroundStyle(KontivaTheme.textTertiary)
    }
}

/// A label/value money row, with optional emphasis and sign-aware colour.
struct MoneyRow: View {
    let label: String
    let amount: Money
    var emphasised: Bool = false
    var subtractive: Bool = false

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(subtractive ? "− \(label)" : label)
                .font(emphasised ? .system(size: 15, weight: .semibold) : .system(size: 14))
                .foregroundStyle(emphasised ? KontivaTheme.textPrimary : KontivaTheme.textSecondary)
            Spacer(minLength: KontivaTheme.Space.md)
            Text(amount.formattedCHF())
                .font(.system(size: emphasised ? 16 : 14, weight: emphasised ? .semibold : .regular))
                .monospacedDigit().contentTransition(.numericText())
                .foregroundStyle(amount.isNegative ? KontivaTheme.swissRed : KontivaTheme.textPrimary)
        }
    }
}

/// A compact metric tile for the dashboard grid: optional accent icon, label, value.
struct MetricTile: View {
    let title: String
    let value: String
    var icon: String? = nil
    var iconColor: Color = KontivaTheme.accent
    var valueColor: Color = KontivaTheme.textPrimary
    var caption: String? = nil

    var body: some View {
        KontivaCard {
            VStack(alignment: .leading, spacing: KontivaTheme.Space.sm) {
                HStack(spacing: KontivaTheme.Space.sm) {
                    if let icon { KontivaIconTile(icon, color: iconColor, size: 30) }
                    CardTitle(title)
                    Spacer(minLength: 0)
                }
                Text(value)
                    .font(.system(size: 22, weight: .semibold)).monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(valueColor)
                    .lineLimit(1).minimumScaleFactor(0.6)
                if let caption {
                    Text(caption).font(.caption2).foregroundStyle(KontivaTheme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

/// A guiding empty state, optionally with a primary call-to-action.
struct EmptyState: View {
    let systemImage: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: KontivaTheme.Space.sm) {
            Image(systemName: systemImage)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(KontivaTheme.accent.opacity(0.85))
                .symbolEffect(.pulse, options: .repeating.speed(0.4))
            Text(title).font(.title3.weight(.semibold)).foregroundStyle(KontivaTheme.textPrimary)
            Text(message)
                .font(.callout).foregroundStyle(KontivaTheme.textSecondary)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            if let actionTitle, let action {
                Button(action: action) { Label(actionTitle, systemImage: "plus") }
                    .buttonStyle(.borderedProminent).tint(KontivaTheme.accent)
                    .controlSize(.large).padding(.top, KontivaTheme.Space.xs)
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, KontivaTheme.Space.xl)
    }
}

/// A circular progress ring with the percentage in the centre.
struct ProgressRing: View {
    let progress: Double
    var size: CGFloat = 46
    var lineWidth: CGFloat = 5
    var color: Color = KontivaTheme.accent

    var body: some View {
        let clamped = min(max(progress, 0), 1)
        ZStack {
            Circle().stroke(color.opacity(0.15), lineWidth: lineWidth)
            Circle().trim(from: 0, to: clamped)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90)).animation(.snappy, value: clamped)
            Text("\(Int((clamped * 100).rounded()))%")
                .font(.system(size: size * 0.26, weight: .semibold)).monospacedDigit()
                .foregroundStyle(KontivaTheme.textSecondary)
        }
        .frame(width: size, height: size)
    }
}

/// A rounded, tinted icon tile — the consistent glyph used in every card header/row.
struct KontivaIconTile: View {
    let systemImage: String
    var color: Color = KontivaTheme.accent
    var size: CGFloat = 38

    init(_ systemImage: String, color: Color = KontivaTheme.accent, size: CGFloat = 38) {
        self.systemImage = systemImage; self.color = color; self.size = size
    }

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
            .fill(color.opacity(0.12)).frame(width: size, height: size)
            .overlay(Image(systemName: systemImage)
                .font(.system(size: size * 0.45, weight: .semibold)).foregroundStyle(color))
    }
}

/// A small count pill shown next to a card's title.
struct CountBadge: View {
    let count: Int
    var color: Color = KontivaTheme.accent
    init(_ count: Int, color: Color = KontivaTheme.accent) { self.count = count; self.color = color }
    var body: some View {
        Text("\(count)")
            .font(.caption.weight(.semibold)).monospacedDigit().foregroundStyle(color)
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(color.opacity(0.12), in: Capsule())
    }
}

/// A labelled money statistic used in the summary cards (label above, value below).
struct SummaryStat: View {
    let title: String
    let value: String
    var color: Color = KontivaTheme.textPrimary
    init(_ title: String, value: String, color: Color = KontivaTheme.textPrimary) {
        self.title = title; self.value = value; self.color = color
    }
    var body: some View {
        VStack(alignment: .leading, spacing: KontivaTheme.Space.xxs) {
            Text(title).font(.caption).foregroundStyle(KontivaTheme.textTertiary).lineLimit(1)
            Text(value).font(.headline).monospacedDigit().contentTransition(.numericText())
                .foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.7)
        }
    }
}

/// A status pill (e.g. bill state, overview status).
struct StatusPill: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, KontivaTheme.Space.xs).padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule()).foregroundStyle(color)
    }
}

/// Standard scrolling container for a screen's content (phone-width padding).
struct ScreenScroll<Content: View>: View {
    private let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KontivaTheme.Space.md) {
                content
            }
            .padding(.horizontal, KontivaTheme.Space.md)
            .padding(.vertical, KontivaTheme.Space.md)
        }
    }
}
