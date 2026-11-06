import SwiftUI
import PDFKit
import UIKit

struct PDFReportView: View {
    let trip: WorkTrip
    @ObservedObject private var lang = LanguageManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var pdfURL: URL? = nil

    var body: some View {
        NavigationView {
            Group {
                if let url = pdfURL {
                    PDFKitView(url: url)
                } else {
                    ProgressView(lang.t(nb: "Genererer rapport...", en: "Generating report..."))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle(lang.t(nb: "Rapport", en: "Report"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(lang.t(nb: "Lukk", en: "Close")) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if let url = pdfURL {
                        ShareLink(
                            item: url,
                            preview: SharePreview(LanguageManager.shared.t(nb: "Kjørerapport", en: "Driving report"), image: Image(systemName: "doc.fill"))
                        ) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
        }
        .task {
            let data = TripPDFGenerator.generate(trip: trip)
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let filename = "kjorerapport-\(formatter.string(from: trip.startTime)).pdf"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try? data.write(to: url)
            pdfURL = url
        }
    }
}

struct PDFKitView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.backgroundColor = .systemGroupedBackground
        return view
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        pdfView.document = PDFDocument(url: url)
    }
}

struct TripPDFGenerator {
    private static let pageWidth: CGFloat = 595.2
    private static let pageHeight: CGFloat = 841.8
    private static let margin: CGFloat = 56

    static func generate(trip: WorkTrip) -> Data {
        let bounds = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)

        return renderer.pdfData { ctx in
            ctx.beginPage()
            var y: CGFloat = margin
            y = drawHeader(trip: trip, y: y)
            y = drawStats(trip: trip, y: y)
            if !trip.passages.isEmpty {
                drawPassages(trip: trip, y: y)
            }
            drawFooter()
        }
    }

    private static func drawHeader(trip: WorkTrip, y: CGFloat) -> CGFloat {
        var y = y
        let contentWidth = pageWidth - 2 * margin

        // App name + date
        let metaAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.secondaryLabel
        ]
        "BomKalkulator".draw(at: CGPoint(x: margin, y: y), withAttributes: metaAttrs)

        let dateStr = trip.startTime.formatted(.dateTime.day().month(.wide).year())
        let dateSize = (dateStr as NSString).size(withAttributes: metaAttrs)
        dateStr.draw(at: CGPoint(x: pageWidth - margin - dateSize.width, y: y), withAttributes: metaAttrs)
        y += 22

        // Title
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 26, weight: .bold),
            .foregroundColor: UIColor.label
        ]
        LanguageManager.shared.t(nb: "Kjørerapport", en: "Driving report").draw(at: CGPoint(x: margin, y: y), withAttributes: titleAttrs)
        y += 38

        // Divider
        drawDivider(y: y, alpha: 1.0)
        y += 16

        // Driver / Company
        let hasDriver = !trip.driverName.isEmpty
        let hasCompany = !trip.company.isEmpty
        if hasDriver || hasCompany {
            let colW = contentWidth / 2
            if hasDriver {
                drawLabelValue(LanguageManager.shared.t(nb: "Sjåfør", en: "Driver"), value: trip.driverName, x: margin, y: y)
            }
            if hasCompany {
                drawLabelValue(LanguageManager.shared.t(nb: "Selskap", en: "Company"), value: trip.company, x: margin + colW, y: y)
            }
            y += 44
        }

        return y
    }

    private static func drawStats(trip: WorkTrip, y: CGFloat) -> CGFloat {
        var y = y
        let contentWidth = pageWidth - 2 * margin
        let colW = contentWidth / 3

        // Start–end time
        var timeRange = trip.startTime.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))
        if let end = trip.endTime {
            timeRange += "  \(trip.startTime.formatted(.dateTime.hour().minute()))–\(end.formatted(.dateTime.hour().minute()))"
        }
        drawStat(LanguageManager.shared.t(nb: "Dato", en: "Date"), value: timeRange, x: margin, y: y, width: contentWidth)
        y += 44

        // Distance / Duration / Toll
        drawStat(LanguageManager.shared.t(nb: "Distanse", en: "Distance"),
                 value: trip.distanceKm > 0 ? String(format: "%.1f km", trip.distanceKm) : "—",
                 x: margin, y: y, width: colW)
        drawStat(LanguageManager.shared.t(nb: "Varighet", en: "Duration"), value: trip.formattedDuration, x: margin + colW, y: y, width: colW)
        drawStat(LanguageManager.shared.t(nb: "Bompenger", en: "Toll"),
                 value: String(format: "%.2f kr", trip.totalTollCost),
                 x: margin + colW * 2, y: y, width: colW)
        y += 48

        drawDivider(y: y, alpha: 1.0)
        y += 20

        return y
    }

    private static func drawPassages(trip: WorkTrip, y: CGFloat) {
        var y = y

        // Section header
        let sectionAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: UIColor.secondaryLabel
        ]
        LanguageManager.shared.t(nb: "BOMSTASJONER", en: "TOLL STATIONS").draw(at: CGPoint(x: margin, y: y), withAttributes: sectionAttrs)
        y += 20

        // Table column headers
        let colHeaderAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: UIColor.secondaryLabel
        ]
        LanguageManager.shared.t(nb: "Tid", en: "Time").draw(at: CGPoint(x: margin, y: y), withAttributes: colHeaderAttrs)
        LanguageManager.shared.t(nb: "Bomstasjon", en: "Toll station").draw(at: CGPoint(x: margin + 56, y: y), withAttributes: colHeaderAttrs)
        let belopHeader = LanguageManager.shared.t(nb: "Beløp", en: "Amount")
        let belopHeaderSize = (belopHeader as NSString).size(withAttributes: colHeaderAttrs)
        belopHeader.draw(at: CGPoint(x: pageWidth - margin - belopHeaderSize.width, y: y), withAttributes: colHeaderAttrs)
        y += 18

        drawDivider(y: y, alpha: 0.5)
        y += 10

        // Rows
        let nameAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.label
        ]
        let subAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.secondaryLabel
        ]

        for passage in trip.passages {
            let timeStr = passage.passedAt.formatted(.dateTime.hour().minute())
            let priceStr = String(format: "%.2f kr", passage.price)

            timeStr.draw(at: CGPoint(x: margin, y: y), withAttributes: nameAttrs)
            passage.stationName.draw(at: CGPoint(x: margin + 56, y: y), withAttributes: nameAttrs)

            let priceSize = (priceStr as NSString).size(withAttributes: nameAttrs)
            priceStr.draw(at: CGPoint(x: pageWidth - margin - priceSize.width, y: y), withAttributes: nameAttrs)
            y += 17

            LanguageManager.shared.t(nb: "AutoPass registrert", en: "AutoPass registered").draw(at: CGPoint(x: margin + 56, y: y), withAttributes: subAttrs)
            y += 18

            drawDivider(y: y, alpha: 0.3)
            y += 8
        }
    }

    private static func drawFooter() {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9),
            .foregroundColor: UIColor.tertiaryLabel
        ]
        let text = LanguageManager.shared.t(nb: "Generert av BomKalkulator", en: "Generated by BomKalkulator")
        let size = (text as NSString).size(withAttributes: attrs)
        text.draw(at: CGPoint(x: (pageWidth - size.width) / 2, y: pageHeight - margin), withAttributes: attrs)
    }

    private static func drawDivider(y: CGFloat, alpha: CGFloat) {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: margin, y: y))
        path.addLine(to: CGPoint(x: pageWidth - margin, y: y))
        UIColor.separator.withAlphaComponent(alpha).setStroke()
        path.lineWidth = 0.5
        path.stroke()
    }

    private static func drawLabelValue(_ label: String, value: String, x: CGFloat, y: CGFloat) {
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.secondaryLabel
        ]
        let valueAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: UIColor.label
        ]
        label.draw(at: CGPoint(x: x, y: y), withAttributes: labelAttrs)
        value.draw(at: CGPoint(x: x, y: y + 14), withAttributes: valueAttrs)
    }

    private static func drawStat(_ label: String, value: String, x: CGFloat, y: CGFloat, width: CGFloat) {
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.secondaryLabel
        ]
        let valueAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16, weight: .bold),
            .foregroundColor: UIColor.label
        ]
        label.draw(at: CGPoint(x: x, y: y), withAttributes: labelAttrs)
        value.draw(at: CGPoint(x: x, y: y + 14), withAttributes: valueAttrs)
    }
}
