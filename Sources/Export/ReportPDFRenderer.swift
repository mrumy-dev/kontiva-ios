import SwiftUI
import Foundation
import CoreGraphics

/// Renders an array of fixed-size SwiftUI pages into a single multi-page PDF.
///
/// Each page is drawn through `ImageRenderer` into a `CGContext` backed PDF, so
/// text stays vector (crisp at any zoom) rather than rasterised. Everything runs
/// locally — no network, no temp files; the bytes are returned in memory for the
/// caller to write to a user-chosen location.
@MainActor
enum ReportPDFRenderer {

    static func render(_ pages: [AnyView]) -> Data? {
        guard !pages.isEmpty else { return nil }
        let size = ReportStyle.pageSize

        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData) else { return nil }
        var mediaBox = CGRect(origin: .zero, size: size)
        guard let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return nil }

        for page in pages {
            let renderer = ImageRenderer(content:
                page
                    .frame(width: size.width, height: size.height)
                    .environment(\.colorScheme, .light)
            )
            renderer.proposedSize = ProposedViewSize(size)
            renderer.render { _, drawInContext in
                ctx.beginPDFPage(nil)
                drawInContext(ctx)
                ctx.endPDFPage()
            }
        }

        ctx.closePDF()
        return pdfData as Data
    }
}
