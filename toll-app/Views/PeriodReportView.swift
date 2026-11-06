import SwiftUI
import PDFKit
import UIKit

struct PeriodReportView: View {
    let trips: [WorkTrip]
    let periodLabel: String
    let driverName: String
    let company: String

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
            .navigationTitle(lang.t(nb: "Forhåndsvisning", en: "Preview"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(lang.t(nb: "Lukk", en: "Close")) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if let url = pdfURL {
                        ShareLink(
                            item: url,
                            preview: SharePreview(
                                lang.t(nb: "Kjørerapport", en: "Driving report"),
                                image: Image(systemName: "doc.fill")
                            )
                        ) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
        }
        .task {
            let data = PeriodPDFGenerator.generate(
                trips: trips,
                periodLabel: periodLabel,
                driverName: driverName,
                company: company
            )
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let startDate = trips.last?.startTime ?? Date()
            let filename = "kjorerapport-\(formatter.string(from: startDate)).pdf"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try? data.write(to: url)
            pdfURL = url
        }
    }
}

struct PeriodPDFGenerator {
    private static let pageWidth: CGFloat = 595.2
    private static let pageHeight: CGFloat = 841.8
    private static let margin: CGFloat = 56

    // Column x positions: Dato | Fra | Til | Km | Bompenger
    private static let xDato:   CGFloat = 56
    private static let xFra:    CGFloat = 56 + 52
    private static let xTil:    CGFloat = 56 + 52 + 100
    private static let xKm:     CGFloat = 56 + 52 + 100 + 100
    private static let xBom:    CGFloat = 56 + 52 + 100 + 100 + 60  // right-aligned to pageWidth-margin

    static func generate(trips: [WorkTrip], periodLabel: String, driverName: String, company: String) -> Data {
        let bounds = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)
        let sorted = trips.sorted { $0.startTime > $1.startTime }

        return renderer.pdfData { ctx in
            ctx.beginPage()
            var y: CGFloat = margin
            y = drawHeader(y: y)
            y = drawInfoRow(driverName: driverName, company: company, periodLabel: periodLabel, y: y)
            y = drawTable(trips: sorted, y: y)
            drawTotals(trips: sorted, y: y)
            drawFooter()
        }
    }

    // MARK: - Header

    private static func drawHeader(y: CGFloat) -> CGFloat {
        var y = y
        let boxSize: CGFloat = 36

        // BK logo box
        let logoPath = UIBezierPath(roundedRect: CGRect(x: margin, y: y, width: boxSize, height: boxSize), cornerRadius: 8)
        UIColor.systemBlue.setFill()
        logoPath.fill()

        let bkAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        let bkSize = ("BK" as NSString).size(withAttributes: bkAttrs)
        "BK".draw(at: CGPoint(x: margin + (boxSize - bkSize.width) / 2,
                              y: y + (boxSize - bkSize.height) / 2), withAttributes: bkAttrs)

        // "BomKalkulator" next to logo
        let appAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 17, weight: .bold),
            .foregroundColor: UIColor.systemBlue
        ]
        let appSize = ("BomKalkulator" as NSString).size(withAttributes: appAttrs)
        "BomKalkulator".draw(at: CGPoint(x: margin + boxSize + 10,
                                        y: y + (boxSize - appSize.height) / 2), withAttributes: appAttrs)

        // "Kjørerapport" right-aligned
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 24, weight: .regular),
            .foregroundColor: UIColor.label
        ]
        let titleStr = LanguageManager.shared.t(nb: "Kjørerapport", en: "Driving report")
        let titleSize = (titleStr as NSString).size(withAttributes: titleAttrs)
        titleStr.draw(at: CGPoint(x: pageWidth - margin - titleSize.width,
                                  y: y + (boxSize - titleSize.height) / 2), withAttributes: titleAttrs)

        y += boxSize + 12

        // Gray divider
        drawHLine(y: y, alpha: 0.6)
        y += 16

        return y
    }

    // MARK: - Info row

    private static func drawInfoRow(driverName: String, company: String, periodLabel: String, y: CGFloat) -> CGFloat {
        var y = y
        let contentWidth = pageWidth - 2 * margin
        let colW = contentWidth / 3

        let capAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8, weight: .semibold),
            .foregroundColor: UIColor.secondaryLabel
        ]
        let valAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.label
        ]

        let cols: [(String, String)] = [
            (LanguageManager.shared.t(nb: "SJÅFØR", en: "DRIVER"),  driverName.isEmpty ? "—" : driverName),
            (LanguageManager.shared.t(nb: "SELSKAP", en: "COMPANY"), company.isEmpty ? "—" : company),
            (LanguageManager.shared.t(nb: "PERIODE", en: "PERIOD"),  periodLabel)
        ]
        for (i, col) in cols.enumerated() {
            let x = margin + CGFloat(i) * colW
            col.0.draw(at: CGPoint(x: x, y: y), withAttributes: capAttrs)
            col.1.draw(at: CGPoint(x: x, y: y + 13), withAttributes: valAttrs)
        }
        y += 38

        // Divider before table
        drawHLine(y: y, alpha: 0.4)
        y += 2

        return y
    }

    // MARK: - Table

    private static func drawTable(trips: [WorkTrip], y: CGFloat) -> CGFloat {
        var y = y
        let contentWidth = pageWidth - 2 * margin
        let headerRowH: CGFloat = 26
        let rowH: CGFloat = 28

        let hdrAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: UIColor.secondaryLabel
        ]
        let rowAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor.label
        ]

        // Header background
        UIColor(white: 0.95, alpha: 1).setFill()
        UIBezierPath(rect: CGRect(x: margin, y: y, width: contentWidth, height: headerRowH)).fill()

        // Header labels
        let hdrs: [(String, CGFloat, Bool)] = [
            (LanguageManager.shared.t(nb: "Dato",      en: "Date"),     xDato, false),
            (LanguageManager.shared.t(nb: "Fra",       en: "From"),     xFra,  false),
            (LanguageManager.shared.t(nb: "Til",       en: "To"),       xTil,  false),
            (LanguageManager.shared.t(nb: "Km",        en: "Km"),       xKm,   false),
            (LanguageManager.shared.t(nb: "Bompenger", en: "Toll"),     pageWidth - margin, true)
        ]
        for (text, x, right) in hdrs {
            if right {
                let w = (text as NSString).size(withAttributes: hdrAttrs).width
                text.draw(at: CGPoint(x: x - w, y: y + (headerRowH - 12) / 2), withAttributes: hdrAttrs)
            } else {
                text.draw(at: CGPoint(x: x, y: y + (headerRowH - 12) / 2), withAttributes: hdrAttrs)
            }
        }
        y += headerRowH

        // Rows — no dividers, just spacing
        let dateFmt = DateFormatter()
        dateFmt.locale = Locale(identifier: "nb_NO")
        dateFmt.dateFormat = "dd.MM"

        for (index, trip) in trips.enumerated() {
            let rowY = y + (rowH - 14) / 2
            let dateStr = dateFmt.string(from: trip.startTime)
            let fraStr  = trip.startCity.isEmpty ? "—" : trip.startCity
            let tilStr  = trip.endCity.isEmpty ? "—" : trip.endCity
            let kmStr   = trip.distanceKm > 0 ? String(format: "%.1f", trip.distanceKm).replacingOccurrences(of: ".", with: ",") : "—"
            let tollStr = String(format: "%.2f kr", trip.totalTollCost).replacingOccurrences(of: ".", with: ",")

            dateStr.draw(at: CGPoint(x: xDato, y: rowY), withAttributes: rowAttrs)
            fraStr.draw(at: CGPoint(x: xFra, y: rowY), withAttributes: rowAttrs)
            tilStr.draw(at: CGPoint(x: xTil, y: rowY), withAttributes: rowAttrs)
            kmStr.draw(at: CGPoint(x: xKm, y: rowY), withAttributes: rowAttrs)

            let tollW = (tollStr as NSString).size(withAttributes: rowAttrs).width
            tollStr.draw(at: CGPoint(x: pageWidth - margin - tollW, y: rowY), withAttributes: rowAttrs)

            y += rowH

            if index < trips.count - 1 {
                let div = UIBezierPath()
                div.move(to: CGPoint(x: margin, y: y))
                div.addLine(to: CGPoint(x: pageWidth - margin, y: y))
                UIColor.separator.withAlphaComponent(0.3).setStroke()
                div.lineWidth = 0.3
                div.stroke()
            }
        }

        y += 12
        return y
    }

    // MARK: - Totals

    private static func drawTotals(trips: [WorkTrip], y: CGFloat) {
        var y = y
        let totalKm   = trips.reduce(0.0) { $0 + $1.distanceKm }
        let totalToll = trips.reduce(0.0) { $0 + $1.totalTollCost }
        let rightEdge = pageWidth - margin
        let labelX: CGFloat = pageWidth * 0.52

        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor.label
        ]
        let valueAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: UIColor.label
        ]
        let labelBoldAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: UIColor.label
        ]
        let valueBoldAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .bold),
            .foregroundColor: UIColor.label
        ]

        // Total distanse
        LanguageManager.shared.t(nb: "Total distanse", en: "Total distance")
            .draw(at: CGPoint(x: labelX, y: y), withAttributes: labelAttrs)
        let kmStr = String(format: "%.1f km", totalKm).replacingOccurrences(of: ".", with: ",")
        let kmW = (kmStr as NSString).size(withAttributes: valueAttrs).width
        kmStr.draw(at: CGPoint(x: rightEdge - kmW, y: y), withAttributes: valueAttrs)
        y += 22

        // Thin line before totale bompenger
        let p = UIBezierPath()
        p.move(to: CGPoint(x: labelX, y: y))
        p.addLine(to: CGPoint(x: rightEdge, y: y))
        UIColor.label.withAlphaComponent(0.5).setStroke()
        p.lineWidth = 0.5
        p.stroke()
        y += 8

        // Totale bompenger
        LanguageManager.shared.t(nb: "Totale bompenger", en: "Total toll")
            .draw(at: CGPoint(x: labelX, y: y), withAttributes: labelBoldAttrs)
        let tollStr = String(format: "%.2f kr", totalToll).replacingOccurrences(of: ".", with: ",")
        let tollW = (tollStr as NSString).size(withAttributes: valueBoldAttrs).width
        tollStr.draw(at: CGPoint(x: rightEdge - tollW, y: y), withAttributes: valueBoldAttrs)
    }

    // MARK: - Footer

    private static func drawFooter() {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9),
            .foregroundColor: UIColor.tertiaryLabel
        ]
        let today = Date().formatted(.dateTime.day().month(.wide).year())
        let text = "\(LanguageManager.shared.t(nb: "Generert av BomKalkulator", en: "Generated by BomKalkulator")) · \(today)"
        text.draw(at: CGPoint(x: margin, y: pageHeight - margin), withAttributes: attrs)
    }

    // MARK: - Helpers

    private static func drawHLine(y: CGFloat, alpha: CGFloat) {
        let p = UIBezierPath()
        p.move(to: CGPoint(x: margin, y: y))
        p.addLine(to: CGPoint(x: pageWidth - margin, y: y))
        UIColor.separator.withAlphaComponent(alpha).setStroke()
        p.lineWidth = 0.5
        p.stroke()
    }
}
