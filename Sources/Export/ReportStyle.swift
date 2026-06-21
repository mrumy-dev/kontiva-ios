import SwiftUI
import KontivaCore

/// A fixed, print-oriented palette for the exported PDF. Unlike `KontivaTheme`
/// (which adapts to light/dark), a report is **always** a crisp white document,
/// so these colours are constant regardless of the app's current appearance.
enum ReportStyle {
    static let paper        = Color(hex: 0xFFFFFF)
    static let ink          = Color(hex: 0x1B232B)
    static let inkSecondary = Color(hex: 0x55606B)
    static let inkTertiary  = Color(hex: 0x97A0A9)
    static let hair         = Color(hex: 0xE4E7EA)
    static let zebra        = Color(hex: 0xF7F8F9)
    static let band         = Color(hex: 0xF4F3EF)   // warm light running-header band
    static let accent       = Color(hex: 0xE11D2E)   // Kontiva red, used sparingly
    static let positive     = Color(hex: 0x1F7A4D)
    static let warning      = Color(hex: 0xB26A00)

    /// A4 at 72 dpi.
    static let pageSize = CGSize(width: 595.28, height: 841.89)
    static let margin: CGFloat = 46
    static var contentWidth: CGFloat { pageSize.width - margin * 2 }

    // Chart palette (fixed, brand-aligned; red reserved for bills).
    static let chartFixed     = Color(hex: 0x3E5C76)
    static let chartVariable  = Color(hex: 0x8AA0B0)
    static let chartBills     = accent
    static let chartSavings   = Color(hex: 0x6A4C93)
    static let chartAvailable = positive
    static let categoryPalette: [Color] = [
        Color(hex: 0x3E5C76), Color(hex: 0x1F7A4D), Color(hex: 0xB26A00),
        Color(hex: 0x6A4C93), Color(hex: 0x2A8C9E), Color(hex: 0x8AA0B0),
        Color(hex: 0xC23B5A),
    ]
}

// MARK: - Table

/// One cell in a report table.
struct ReportCell {
    var text: String
    var trailing: Bool = false
    var bold: Bool = false
    var color: Color = ReportStyle.ink
}

/// A clean, zebra-striped table with a header row and an optional emphasised
/// footer (e.g. a "Total" line). Column widths are absolute and supplied by the
/// caller so the layout is fully deterministic when rendered off-screen.
struct ReportTable: View {
    let header: [ReportCell]
    let rows: [[ReportCell]]
    let widths: [CGFloat]
    var footerRow: [ReportCell]? = nil

    var body: some View {
        VStack(spacing: 0) {
            rowView(header, isHeader: true, zebra: false)
            ForEach(rows.indices, id: \.self) { i in
                Rectangle().fill(ReportStyle.hair).frame(height: 0.5)
                rowView(rows[i], isHeader: false, zebra: i % 2 == 1)
            }
            if let footerRow {
                Rectangle().fill(ReportStyle.ink.opacity(0.22)).frame(height: 1)
                rowView(footerRow, isHeader: false, zebra: false, emphasised: true)
            }
        }
        .background(ReportStyle.paper)
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(ReportStyle.hair, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func rowView(_ cells: [ReportCell], isHeader: Bool,
                         zebra: Bool, emphasised: Bool = false) -> some View {
        HStack(spacing: 0) {
            ForEach(cells.indices, id: \.self) { i in
                let c = cells[i]
                Text(c.text)
                    .font(.system(size: isHeader ? 9 : 10,
                                  weight: isHeader ? .semibold
                                                   : (emphasised || c.bold ? .semibold : .regular)))
                    .tracking(isHeader ? 0.4 : 0)
                    .monospacedDigit()
                    .foregroundStyle(isHeader ? ReportStyle.inkTertiary : c.color)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: widths[safe: i] ?? 0,
                           alignment: c.trailing ? .trailing : .leading)
                    .padding(.vertical, isHeader ? 7 : 6)
                    .padding(.horizontal, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isHeader ? ReportStyle.band : (zebra ? ReportStyle.zebra : Color.clear))
    }
}

// MARK: - Donut (drawn manually — no Charts dependency, so it always renders to PDF)

struct ReportDonut: View {
    struct Segment: Identifiable {
        let id = UUID()
        let label: String
        let value: Double
        let color: Color
    }

    let segments: [Segment]
    let centerTitle: String
    let centerValue: String
    let centerNegative: Bool
    var diameter: CGFloat = 150
    var thickness: CGFloat = 30

    private var total: Double { max(segments.reduce(0) { $0 + $1.value }, 0.000001) }

    private var arcs: [(seg: Segment, start: CGFloat, end: CGFloat)] {
        var acc: CGFloat = 0
        return segments.map { seg in
            let frac = CGFloat(seg.value / total)
            let item = (seg, acc, acc + frac)
            acc += frac
            return item
        }
    }

    var body: some View {
        HStack(spacing: 26) {
            ZStack {
                ForEach(arcs, id: \.seg.id) { a in
                    Circle()
                        .trim(from: a.start, to: max(a.start, a.end - 0.004))
                        .stroke(a.seg.color, style: StrokeStyle(lineWidth: thickness, lineCap: .butt))
                        .rotationEffect(.degrees(-90))
                }
                VStack(spacing: 1) {
                    Text(centerTitle)
                        .font(.system(size: 8, weight: .semibold)).tracking(0.3)
                        .foregroundStyle(ReportStyle.inkTertiary)
                        .multilineTextAlignment(.center)
                    Text(centerValue)
                        .font(.system(size: 15, weight: .bold)).monospacedDigit()
                        .foregroundStyle(centerNegative ? ReportStyle.accent : ReportStyle.ink)
                        .lineLimit(1).minimumScaleFactor(0.6)
                }
                .frame(width: diameter - thickness * 2 - 8)
            }
            .frame(width: diameter, height: diameter)

            VStack(alignment: .leading, spacing: 7) {
                ForEach(segments) { seg in
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 2).fill(seg.color).frame(width: 9, height: 9)
                        Text(seg.label).font(.system(size: 10)).foregroundStyle(ReportStyle.inkSecondary)
                            .lineLimit(1)
                        Spacer(minLength: 10)
                        Text(Money(rappen: Int64(seg.value * 100)).formattedCHF())
                            .font(.system(size: 10, weight: .medium)).monospacedDigit()
                            .foregroundStyle(ReportStyle.ink)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Horizontal bars (deterministic widths, no GeometryReader)

struct ReportBars: View {
    struct Bar: Identifiable {
        let id = UUID()
        let name: String
        let amount: Money
        let color: Color
    }

    let bars: [Bar]
    var labelWidth: CGFloat = 150
    var trackWidth: CGFloat = 250

    private var maxValue: Double {
        max(bars.map { Double($0.amount.rappen) }.max() ?? 1, 1)
    }

    var body: some View {
        VStack(spacing: 9) {
            ForEach(bars) { bar in
                HStack(spacing: 10) {
                    Text(bar.name)
                        .font(.system(size: 10)).foregroundStyle(ReportStyle.inkSecondary)
                        .frame(width: labelWidth, alignment: .leading).lineLimit(1)
                    RoundedRectangle(cornerRadius: 3).fill(bar.color)
                        .frame(width: max(3, trackWidth * CGFloat(Double(bar.amount.rappen) / maxValue)),
                               height: 13)
                    Text(bar.amount.formattedCHF(showSymbol: false))
                        .font(.system(size: 9, weight: .medium)).monospacedDigit()
                        .foregroundStyle(ReportStyle.inkTertiary)
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

// MARK: - Small primitives

/// A bordered content box with an optional small uppercase title.
struct ReportCardBox<Content: View>: View {
    var title: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .semibold)).tracking(0.6)
                    .foregroundStyle(ReportStyle.inkTertiary)
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(ReportStyle.paper))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(ReportStyle.hair, lineWidth: 1))
    }
}

/// A compact labelled metric used in the summary strip.
struct ReportMetricBox: View {
    let title: String
    let value: String
    var color: Color = ReportStyle.ink

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 8.5, weight: .semibold)).tracking(0.2)
                .foregroundStyle(ReportStyle.inkTertiary)
                .lineLimit(2).fixedSize(horizontal: false, vertical: true)
            Text(value)
                .font(.system(size: 14, weight: .semibold)).monospacedDigit()
                .foregroundStyle(color)
                .lineLimit(1).minimumScaleFactor(0.55)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 8).fill(ReportStyle.zebra))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(ReportStyle.hair, lineWidth: 1))
    }
}

/// A small bold subheading used inside a section body.
struct ReportSubheading: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(ReportStyle.inkSecondary)
    }
}

// MARK: - Page chrome

/// A content page: a slim running-header band, a red hairline, the section body
/// (with a large H1), and a footer rule carrying the generation date + page number.
struct ReportPage<Content: View>: View {
    let sectionTitle: String
    let period: String
    let pageIndex: Int
    let pageCount: Int
    let generatedOn: String
    let loc: Localization
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            band
            Rectangle().fill(ReportStyle.accent).frame(height: 2)
            VStack(alignment: .leading, spacing: 16) {
                Text(sectionTitle)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(ReportStyle.ink)
                content()
            }
            .padding(.horizontal, ReportStyle.margin)
            .padding(.top, 22)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .clipped()
            footer
        }
        .frame(width: ReportStyle.pageSize.width, height: ReportStyle.pageSize.height)
        .background(ReportStyle.paper)
    }

    private var band: some View {
        HStack(spacing: 6) {
            Text("Kontiva").font(.system(size: 11, weight: .bold)).foregroundStyle(ReportStyle.ink)
            Text("·").foregroundStyle(ReportStyle.inkTertiary)
            Text(period).font(.system(size: 10)).foregroundStyle(ReportStyle.inkSecondary)
            Spacer()
            Text(loc.string(.pdfConfidential).uppercased())
                .font(.system(size: 9, weight: .semibold)).tracking(0.8)
                .foregroundStyle(ReportStyle.inkTertiary)
        }
        .padding(.horizontal, ReportStyle.margin)
        .frame(height: 46)
        .background(ReportStyle.band)
    }

    private var footer: some View {
        VStack(spacing: 6) {
            Rectangle().fill(ReportStyle.hair).frame(height: 1)
            HStack {
                Text(generatedOn).font(.system(size: 8)).foregroundStyle(ReportStyle.inkTertiary)
                Spacer()
                Text("\(loc.string(.pdfPage)) \(pageIndex) / \(pageCount)")
                    .font(.system(size: 8)).foregroundStyle(ReportStyle.inkTertiary)
            }
            .padding(.horizontal, ReportStyle.margin)
        }
        .padding(.bottom, 16)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
