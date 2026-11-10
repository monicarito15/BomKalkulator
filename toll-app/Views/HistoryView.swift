import SwiftUI
import SwiftData

struct HistoryView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var purchaseManager: PurchaseManager
    @ObservedObject private var lang = LanguageManager.shared

    @State private var showPaywall = false
    @State private var historyTab: Int = 0
    @State private var tripFilter: TripFilter = .alle
    @State private var filterFrom: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var filterTo: Date = Date()
    @State private var showPeriodSheet = false
    @State private var showPeriodReport = false
    @AppStorage("driverName") private var driverName: String = ""

    @Query(sort: \SearchHistoryItem.searchDate, order: .reverse)
    var searchHistory: [SearchHistoryItem]

    @Query(sort: \WorkTrip.startTime, order: .reverse)
    var allWorkTrips: [WorkTrip]

    var onSelectSearch: (SearchHistoryItem) -> Void

    enum TripFilter { case alle, denneUken, valgtPeriode }

    private var completedTrips: [WorkTrip] {
        allWorkTrips.filter { $0.status == .completed }
    }

    private var filteredTrips: [WorkTrip] {
        switch tripFilter {
        case .alle:
            return completedTrips
        case .denneUken:
            let cal = Calendar.current
            guard let startOfWeek = cal.dateInterval(of: .weekOfYear, for: Date())?.start else { return completedTrips }
            return completedTrips.filter { $0.startTime >= startOfWeek }
        case .valgtPeriode:
            let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: filterTo) ?? filterTo
            return completedTrips.filter { $0.startTime >= filterFrom && $0.startTime <= endOfDay }
        }
    }

    private var visibleHistory: [SearchHistoryItem] {
        purchaseManager.isPremium ? searchHistory : Array(searchHistory.prefix(PurchaseManager.freeSearchLimit))
    }

    private var hiddenCount: Int {
        purchaseManager.isPremium ? 0 : max(0, searchHistory.count - PurchaseManager.freeSearchLimit)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.white)
    }

    private var groupedHistory: [(String, [SearchHistoryItem])] {
        let calendar = Calendar.current
        let now = Date()
        var groups: [String: [SearchHistoryItem]] = [:]
        for item in visibleHistory {
            let key = getSectionTitle(for: item.searchDate, relativeTo: now, calendar: calendar)
            groups[key, default: []].append(item)
        }
        return groups.sorted { a, b in
            (a.value.first?.searchDate ?? .distantPast) > (b.value.first?.searchDate ?? .distantPast)
        }
    }

    private var groupedFilteredTrips: [(key: String, label: String, trips: [WorkTrip])] {
        var groups: [String: [WorkTrip]] = [:]
        for trip in filteredTrips {
            groups[weekSortKey(for: trip.startTime), default: []].append(trip)
        }
        return groups.map { (key: $0.key, label: weekDisplayLabel(trips: $0.value), trips: $0.value) }
            .sorted { $0.key > $1.key }
    }

    private func weekSortKey(for date: Date) -> String {
        let cal = Calendar.current
        let week = cal.component(.weekOfYear, from: date)
        let year = cal.component(.year, from: date)
        return String(format: "%04d-W%02d", year, week)
    }

    private func weekDisplayLabel(trips: [WorkTrip]) -> String {
        guard let first = trips.sorted(by: { $0.startTime < $1.startTime }).first else { return "" }
        let cal = Calendar.current
        let week = cal.component(.weekOfYear, from: first.startTime)
        guard let interval = cal.dateInterval(of: .weekOfYear, for: first.startTime) else { return "UKE \(week)" }
        let startDay = cal.component(.day, from: interval.start)
        let endDate = cal.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
        let endDay = cal.component(.day, from: endDate)
        let f = DateFormatter()
        f.locale = Locale(identifier: "nb_NO")
        f.dateFormat = "MMMM"
        let month = f.string(from: first.startTime).uppercased()
        return "UKE \(week) · \(startDay).–\(endDay). \(month)"
    }

    private var periodLabel: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "nb_NO")
        f.dateFormat = "d. MMMM"
        return "\(f.string(from: filterFrom))–\(f.string(from: filterTo))"
    }

    private var periodReportLabel: String {
        switch tripFilter {
        case .alle:
            guard let first = filteredTrips.last?.startTime, let last = filteredTrips.first?.startTime else {
                return lang.t(nb: "Alle turer", en: "All trips")
            }
            let f = DateFormatter()
            f.locale = Locale(identifier: "nb_NO")
            f.dateFormat = "d. MMMM yyyy"
            return "\(f.string(from: first))–\(f.string(from: last))"
        case .denneUken:
            return lang.t(nb: "Denne uken", en: "This week")
        case .valgtPeriode:
            let f = DateFormatter()
            f.locale = Locale(identifier: "nb_NO")
            f.dateFormat = "d. MMMM yyyy"
            return "\(f.string(from: filterFrom))–\(f.string(from: filterTo))"
        }
    }

    private func getSectionTitle(for date: Date, relativeTo now: Date, calendar: Calendar) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
        if days == 0 { return lang.t(nb: "I dag", en: "Today") }
        if days == 1 { return lang.t(nb: "I går", en: "Yesterday") }
        if days <= 7 { return lang.t(nb: "Siste uke", en: "Last week") }
        if days <= 30 { return lang.t(nb: "Siste måned", en: "Last month") }
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: date)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("", selection: $historyTab) {
                    Text(lang.t(nb: "Ruter", en: "Routes")).tag(0)
                    Text(lang.t(nb: "Kjøreturer", en: "Trips")).tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(colorScheme == .dark ? .black : .systemGroupedBackground))

                if historyTab == 1 {
                    tripFilterBar
                }

                ScrollView {
                    if historyTab == 0 {
                        searchesContent
                    } else {
                        tripsContent
                    }
                }
                .background(Color(colorScheme == .dark ? .black : .systemGroupedBackground).ignoresSafeArea())
            }
            .background(Color(colorScheme == .dark ? .black : .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(lang.t(nb: "Historikk", en: "History"))
            .navigationBarTitleDisplayMode(.large)
            .safeAreaInset(edge: .bottom) {
                if historyTab == 1 && !filteredTrips.isEmpty {
                    Button {
                        showPeriodReport = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.fill")
                            Text(lang.t(nb: "Forhåndsvisning", en: "Preview report"))
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(colorScheme == .dark ? .black : .systemGroupedBackground))
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView().environmentObject(purchaseManager)
            }
            .sheet(isPresented: $showPeriodSheet) {
                VelgPeriodeSheet(filterFrom: $filterFrom, filterTo: $filterTo) {
                    tripFilter = .valgtPeriode
                }
            }
            .sheet(isPresented: $showPeriodReport) {
                PeriodReportView(
                    trips: filteredTrips,
                    periodLabel: periodReportLabel,
                    driverName: driverName,
                    company: filteredTrips.first(where: { !$0.company.isEmpty })?.company ?? ""
                )
            }
        }
    }

    private var tripFilterBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                filterChip(lang.t(nb: "Alle", en: "All"), isSelected: tripFilter == .alle) {
                    tripFilter = .alle
                }
                filterChip(lang.t(nb: "Denne uken", en: "This week"), isSelected: tripFilter == .denneUken) {
                    tripFilter = .denneUken
                }
                Button {
                    showPeriodSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "clock").font(.caption)
                        Text(lang.t(nb: "Valgt periode", en: "Custom")).font(.subheadline)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(tripFilter == .valgtPeriode ? Color.clear : Color(.systemGray5))
                    .foregroundStyle(tripFilter == .valgtPeriode ? Color.blue : Color.primary)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(tripFilter == .valgtPeriode ? Color.blue : Color.clear, lineWidth: 1.5))
                }
            }
            .padding(.horizontal, 16)

            if tripFilter == .valgtPeriode {
                HStack {
                    Text(periodLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(lang.t(nb: "Nullstill", en: "Reset")) {
                        tripFilter = .alle
                    }
                    .font(.subheadline)
                    .foregroundStyle(.blue)
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 10)
        .background(Color(colorScheme == .dark ? .black : .systemGroupedBackground))
    }

    @ViewBuilder
    private func filterChip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Color(.systemGray5))
                .foregroundStyle(Color.primary)
                .clipShape(Capsule())
        }
    }

    // Searches tab
    private var searchesContent: some View {
        Group {
            if searchHistory.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 60))
                        .foregroundStyle(.gray)
                    Text(lang.t(nb: "Ingen ruter ennå", en: "No Routes Yet"))
                        .font(.title2).fontWeight(.semibold)
                    Text(lang.t(nb: "Dine siste søk vises her", en: "Your recent searches will appear here"))
                        .font(.subheadline).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center).padding(.horizontal)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(groupedHistory, id: \.0) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.0.uppercased())
                                .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                                .padding(.horizontal, 20)
                                .padding(.top, section.0 == groupedHistory.first?.0 ? 0 : 8)

                            VStack(spacing: 0) {
                                ForEach(Array(section.1.enumerated()), id: \.element.id) { index, item in
                                    Button { onSelectSearch(item) } label: { historyItemRow(item) }
                                        .buttonStyle(.plain)
                                    if index < section.1.count - 1 {
                                        Divider().padding(.leading, 56)
                                    }
                                }
                            }
                            .background(cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                            .padding(.horizontal, 16)
                        }
                    }

                    if hiddenCount > 0 {
                        Button { showPaywall = true } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "lock.fill").font(.system(size: 20)).foregroundStyle(.orange).frame(width: 32)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(hiddenCount) \(lang.t(nb: "søk låst", en: hiddenCount == 1 ? "more search locked" : "more searches locked"))")
                                        .font(.subheadline.weight(.medium))
                                    Text(lang.t(nb: "Lås opp full historikk for 19 kr", en: "Unlock full history for 19 kr"))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                        .background(cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.orange.opacity(0.4), lineWidth: 1))
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 20)
            }
        }
    }

    // Trips tab
    private var tripsContent: some View {
        Group {
            if filteredTrips.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "steeringwheel")
                        .font(.system(size: 60)).foregroundStyle(.gray)
                    Text(tripFilter == .alle
                         ? lang.t(nb: "Ingen turer ennå", en: "No Trips Yet")
                         : lang.t(nb: "Ingen turer i denne perioden", en: "No trips in this period"))
                        .font(.title2).fontWeight(.semibold)
                    Text(lang.t(nb: "Fullførte kjøreturer vises her", en: "Completed work trips will appear here"))
                        .font(.subheadline).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center).padding(.horizontal)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(groupedFilteredTrips, id: \.key) { group in
                        Text(group.label)
                            .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                            .padding(.horizontal, 20)
                            .padding(.top, group.key == groupedFilteredTrips.first?.key ? 20 : 16)
                            .padding(.bottom, 6)

                        VStack(spacing: 0) {
                            ForEach(Array(group.trips.enumerated()), id: \.element.id) { index, trip in
                                NavigationLink { TripDetailView(trip: trip) } label: { tripRow(trip) }
                                    .buttonStyle(.plain)
                                if index < group.trips.count - 1 {
                                    Divider().padding(.leading, 68)
                                }
                            }
                        }
                        .background(cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 32)
            }
        }
    }

    @ViewBuilder
    private func historyItemRow(_ item: SearchHistoryItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                .font(.system(size: 24)).foregroundStyle(.blue).frame(width: 32)
            VStack(alignment: .leading, spacing: 6) {
                Text(item.routeDescription)
                    .font(.body).fontWeight(.medium).foregroundStyle(.primary)
                    .lineLimit(2).multilineTextAlignment(.leading)
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "car.fill")
                            .font(.caption2).foregroundStyle(.secondary)
                        Image(systemName: item.fuelTypeEnum == .gas ? "fuelpump.fill" : "bolt.fill")
                            .font(.caption2).foregroundStyle(item.fuelTypeEnum == .gas ? .orange : .yellow)
                    }
                    if item.tollCount > 0 {
                        Text("·").font(.caption).foregroundStyle(.secondary)
                        Text("\(item.tollCount) \(lang.t(nb: item.tollCount == 1 ? "bom" : "bommer", en: item.tollCount == 1 ? "toll" : "tolls"))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if item.totalPrice > 0 {
                        Text("·").font(.caption).foregroundStyle(.secondary)
                        Text(String(format: "%.0f kr", item.totalPrice))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Text(item.timeAgo).font(.caption2).foregroundStyle(.tertiary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16).padding(.vertical, 12).contentShape(Rectangle())
    }

    @ViewBuilder
    private func tripRow(_ trip: WorkTrip) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: "steeringwheel")
                    .font(.system(size: 20))
                    .foregroundStyle(.blue)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(tripDayLabel(trip.startTime))
                    .font(.subheadline).fontWeight(.semibold).foregroundStyle(.primary)

                if !trip.company.isEmpty {
                    Text(trip.company)
                        .font(.subheadline).foregroundStyle(.secondary)
                }

                HStack(spacing: 4) {
                    if trip.distanceKm > 0 {
                        Text(String(format: "%.1f km", trip.distanceKm))
                    }
                    if trip.distanceKm > 0 {
                        Text("·")
                    }
                    Text(trip.formattedDuration)
                }
                .font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 4) {
                Text(String(format: "%.2f kr", trip.totalTollCost)
                    .replacingOccurrences(of: ".", with: ","))
                    .font(.subheadline).fontWeight(.medium)
                Image(systemName: "chevron.right")
                    .font(.caption).foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12).contentShape(Rectangle())
    }

    private func tripDayLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "nb_NO")
        f.dateFormat = "EEEE d. MMMM"
        let str = f.string(from: date)
        return str.prefix(1).uppercased() + str.dropFirst()
    }
}

struct VelgPeriodeSheet: View {
    @Binding var filterFrom: Date
    @Binding var filterTo: Date
    var onApply: () -> Void

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var lang = LanguageManager.shared
    @Environment(\.colorScheme) private var colorScheme

    @State private var tempFrom: Date
    @State private var tempTo: Date

    init(filterFrom: Binding<Date>, filterTo: Binding<Date>, onApply: @escaping () -> Void) {
        self._filterFrom = filterFrom
        self._filterTo = filterTo
        self.onApply = onApply
        self._tempFrom = State(initialValue: filterFrom.wrappedValue)
        self._tempTo = State(initialValue: filterTo.wrappedValue)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            ZStack {
                Text(lang.t(nb: "Velg periode", en: "Select period"))
                    .font(.headline)
                HStack {
                    Button(lang.t(nb: "Avbryt", en: "Cancel")) { dismiss() }
                        .foregroundStyle(.blue)
                    Spacer()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 6)

            Text(lang.t(nb: "Vis kjøreturer mellom valgte datoer.", en: "Show trips between selected dates."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.bottom, 20)

            VStack(spacing: 0) {
                HStack {
                    Text(lang.t(nb: "Fra dato", en: "From date"))
                        .font(.body)
                    Spacer()
                    DatePicker("", selection: $tempFrom, displayedComponents: .date)
                        .labelsHidden()
                        .tint(.blue)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground))

                Divider().padding(.leading, 16)

                HStack {
                    Text(lang.t(nb: "Til dato", en: "To date"))
                        .font(.body)
                    Spacer()
                    DatePicker("", selection: $tempTo, in: tempFrom..., displayedComponents: .date)
                        .labelsHidden()
                        .tint(.blue)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground))
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)

            Button {
                filterFrom = tempFrom
                filterTo = tempTo
                onApply()
                dismiss()
            } label: {
                Text(lang.t(nb: "Vis kjøreturer", en: "Show trips"))
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .background(Color(colorScheme == .dark ? .black : .systemGroupedBackground).ignoresSafeArea())
        .presentationDetents([.height(320)])
        .presentationDragIndicator(.visible)
    }
}
