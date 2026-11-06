import SwiftUI
import SwiftData
import Charts

struct OversiktView: View {
    var onShowHistory: (() -> Void)? = nil

    @ObservedObject private var lang = LanguageManager.shared
    @AppStorage("driverName") private var driverName: String = ""
    @Environment(\.colorScheme) private var colorScheme

    @Query(sort: \WorkTrip.startTime, order: .reverse)
    private var allWorkTrips: [WorkTrip]

    private var cardBackground: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.white)
    }

    private var monthTrips: [WorkTrip] {
        let calendar = Calendar.current
        let now = Date()
        return allWorkTrips.filter {
            $0.status == .completed &&
            calendar.isDate($0.startTime, equalTo: now, toGranularity: .month)
        }
    }

    private var allPassages: [TollPassage] {
        monthTrips.flatMap { $0.passages }
    }

    private var paidPassages: [TollPassage] {
        allPassages.filter { $0.price > 0 }
    }

    private var freePassages: [TollPassage] {
        allPassages.filter { $0.price == 0 }
    }

    private var totalCost: Double {
        paidPassages.reduce(0) { $0 + $1.price }
    }

    private var lastTripDistance: Double? {
        guard let d = monthTrips.first?.distanceKm, d > 0 else { return nil }
        return d
    }

    private var avgCostPerPassage: Double? {
        guard !paidPassages.isEmpty else { return nil }
        return totalCost / Double(paidPassages.count)
    }

    private var recentPassages: [(passage: TollPassage, trip: WorkTrip)] {
        let sorted = monthTrips
            .flatMap { trip in trip.passages.map { (passage: $0, trip: trip) } }
            .sorted { $0.passage.passedAt > $1.passage.passedAt }
        return Array(sorted.prefix(5))
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 6..<12: return lang.t(nb: "God morgen", en: "Good morning")
        case 12..<18: return lang.t(nb: "God ettermiddag", en: "Good afternoon")
        case 18..<22: return lang.t(nb: "God kveld", en: "Good evening")
        default: return lang.t(nb: "God natt", en: "Good night")
        }
    }

    private var dateLabel: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "nb_NO")
        f.dateFormat = "EEEE d. MMMM"
        return f.string(from: Date()).uppercased()
    }

    private var monthLabel: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "nb_NO")
        f.dateFormat = "MMMM yyyy"
        return f.string(from: Date()).capitalized
    }

    private func formatKr(_ amount: Double) -> String {
        String(format: "%.2f", amount).replacingOccurrences(of: ".", with: ",") + " kr"
    }

    private func formatKm(_ km: Double) -> String {
        String(format: "%.1f", km).replacingOccurrences(of: ".", with: ",") + " km"
    }

    private func passageTimeLabel(_ date: Date) -> String {
        let cal = Calendar.current
        let timeStr = date.formatted(.dateTime.hour().minute())
        if cal.isDateInToday(date) { return "\(lang.t(nb: "I dag", en: "Today")), \(timeStr)" }
        if cal.isDateInYesterday(date) { return "\(lang.t(nb: "I går", en: "Yesterday")), \(timeStr)" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "nb_NO")
        f.dateFormat = "d. MMM"
        return "\(f.string(from: date)), \(timeStr)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    periodSelector
                    oversiktCard
                    if !recentPassages.isEmpty {
                        sistePasseringerSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 32)
            }
            .background(Color(colorScheme == .dark ? .black : .systemGroupedBackground).ignoresSafeArea())
        }
    }

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(dateLabel)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Text(driverName.isEmpty ? greeting : "\(greeting), \(driverName)")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            Spacer()
            Button { } label: {
                Image(systemName: "bell")
                    .font(.system(size: 18))
                    .foregroundStyle(.primary)
                    .padding(10)
                    .background(cardBackground)
                    .clipShape(Circle())
            }
        }
    }

    private var periodSelector: some View {
        HStack {
            Text(lang.t(nb: "Denne måneden", en: "This month"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(monthLabel)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.blue)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var oversiktCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(lang.t(nb: "OVERSIKT", en: "OVERVIEW"))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
                Button { } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.blue)
                }
            }

            Text(lang.t(nb: "Mine bompasseringer", en: "My toll passages"))
                .font(.title3)
                .fontWeight(.semibold)

            HStack(spacing: 0) {
                Spacer()
                donutChart
                    .padding(.top, 8)
                Spacer().frame(width: 32)
                legendView
                Spacer()
            }

            totalCard
                .padding(.top, 8)

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(lastTripDistance.map { formatKm($0) } ?? "—")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text(lang.t(nb: "Siste kjøretur", en: "Last trip"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider().frame(height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(avgCostPerPassage.map { formatKr($0) } ?? "—")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text(lang.t(nb: "Snitt per passering", en: "Avg per passage"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 12)
            }
        }
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var donutChart: some View {
        if allPassages.isEmpty {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 18)
                .frame(width: 110, height: 110)
                .overlay {
                    VStack(spacing: 2) {
                        Text("0")
                            .font(.title2).fontWeight(.bold)
                        Text(lang.t(nb: "passeringer", en: "passages"))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
        } else {
            Chart {
                if !paidPassages.isEmpty {
                    SectorMark(angle: .value("Belastet", paidPassages.count),
                               innerRadius: .ratio(0.62),
                               angularInset: 2)
                    .foregroundStyle(Color.green)
                }
                if !freePassages.isEmpty {
                    SectorMark(angle: .value("Gratis", freePassages.count),
                               innerRadius: .ratio(0.62),
                               angularInset: 2)
                    .foregroundStyle(Color.purple.opacity(0.5))
                }
            }
            .frame(width: 110, height: 110)
            .overlay {
                VStack(spacing: 2) {
                    Text("\(allPassages.count)")
                        .font(.title2).fontWeight(.bold)
                    Text(lang.t(nb: "passeringer", en: "passages"))
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var legendView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle().fill(Color.green).frame(width: 10, height: 10)
                Text("\(paidPassages.count) \(lang.t(nb: "belastet", en: "charged"))")
                    .font(.subheadline)
            }
            HStack(spacing: 8) {
                Circle().fill(Color.purple.opacity(0.5)).frame(width: 10, height: 10)
                Text("\(freePassages.count) \(lang.t(nb: "gratis", en: "free"))")
                    .font(.subheadline)
            }
        }
    }

    private var totalCard: some View {
        VStack(spacing: 4) {
            Text(lang.t(nb: "Total denne måneden", en: "Total this month"))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(formatKr(totalCost))
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.blue)
            Text(lang.t(nb: "inkl. AutoPass-rabatt", en: "incl. AutoPass discount"))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.blue.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var sistePasseringerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(lang.t(nb: "Siste passeringer", en: "Recent passages"))
                .font(.title3)
                .fontWeight(.semibold)

            VStack(spacing: 0) {
                ForEach(Array(recentPassages.enumerated()), id: \.offset) { index, item in
                    NavigationLink(destination: TripDetailView(trip: item.trip)) {
                        passageRow(item.passage)
                    }
                    .buttonStyle(.plain)
                    if index < recentPassages.count - 1 {
                        Divider().padding(.leading, 60)
                    }
                }
            }
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    @ViewBuilder
    private func passageRow(_ passage: TollPassage) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: "car.fill")
                    .foregroundStyle(.blue)
                    .font(.system(size: 15))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(passageTimeLabel(passage.passedAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(passage.stationName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(lang.t(nb: "AutoPass registrert", en: "AutoPass registered"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(formatKr(passage.price))
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
