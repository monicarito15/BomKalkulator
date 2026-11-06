import SwiftUI
import SwiftData

struct HistoryView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var purchaseManager: PurchaseManager
    @ObservedObject private var lang = LanguageManager.shared

    @State private var showPaywall = false
    @State private var historyTab: Int = 0

    @Query(sort: \SearchHistoryItem.searchDate, order: .reverse)
    var searchHistory: [SearchHistoryItem]

    @Query(sort: \WorkTrip.startTime, order: .reverse)
    var allWorkTrips: [WorkTrip]

    var onSelectSearch: (SearchHistoryItem) -> Void

    private var completedTrips: [WorkTrip] {
        allWorkTrips.filter { $0.status == .completed }
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
            let sectionTitle = getSectionTitle(for: item.searchDate, relativeTo: now, calendar: calendar)
            groups[sectionTitle, default: []].append(item)
        }

        return groups.sorted { first, second in
            let firstDate = first.value.first?.searchDate ?? Date.distantPast
            let secondDate = second.value.first?.searchDate ?? Date.distantPast
            return firstDate > secondDate
        }
    }

    private var groupedTrips: [(String, [WorkTrip])] {
        var groups: [String: [WorkTrip]] = [:]
        for trip in completedTrips {
            groups[trip.weekLabel, default: []].append(trip)
        }
        return groups.sorted { first, second in
            let firstDate = first.value.first?.startTime ?? Date.distantPast
            let secondDate = second.value.first?.startTime ?? Date.distantPast
            return firstDate > secondDate
        }
    }

    private func getSectionTitle(for date: Date, relativeTo now: Date, calendar: Calendar) -> String {
        let daysDifference = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0

        if daysDifference == 0 {
            return lang.t(nb: "I dag", en: "Today")
        } else if daysDifference == 1 {
            return lang.t(nb: "I går", en: "Yesterday")
        } else if daysDifference <= 7 {
            return lang.t(nb: "Siste uke", en: "Last Week")
        } else if daysDifference <= 30 {
            return lang.t(nb: "Siste måned", en: "Last Month")
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: date)
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("", selection: $historyTab) {
                    Text(lang.t(nb: "Søk", en: "Searches")).tag(0)
                    Text(lang.t(nb: "Turer", en: "Trips")).tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(colorScheme == .dark ? .black : .systemGroupedBackground))

                ScrollView {
                    if historyTab == 0 {
                        searchesContent
                    } else {
                        tripsContent
                    }
                }
                .background(
                    Color(colorScheme == .dark ? .black : .systemGroupedBackground)
                        .ignoresSafeArea()
                )
            }
            .background(
                Color(colorScheme == .dark ? .black : .systemGroupedBackground)
                    .ignoresSafeArea()
            )
            .navigationTitle(lang.t(nb: "Historikk", en: "History"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if historyTab == 0 && !searchHistory.isEmpty {
                        Text("\(searchHistory.count) \(lang.t(nb: "søk", en: searchHistory.count == 1 ? "search" : "searches"))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if historyTab == 1 && !completedTrips.isEmpty {
                        Text("\(completedTrips.count) \(lang.t(nb: completedTrips.count == 1 ? "tur" : "turer", en: completedTrips.count == 1 ? "trip" : "trips"))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
                    .environmentObject(purchaseManager)
            }
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
                    Text(lang.t(nb: "Ingen historikk", en: "No History"))
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text(lang.t(nb: "Dine siste søk vises her", en: "Your recent searches will appear here"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(groupedHistory, id: \.0) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.0.uppercased())
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 20)
                                .padding(.top, section.0 == groupedHistory.first?.0 ? 0 : 8)

                            VStack(spacing: 0) {
                                ForEach(Array(section.1.enumerated()), id: \.element.id) { index, historyItem in
                                    Button {
                                        onSelectSearch(historyItem)
                                    } label: {
                                        historyItemRow(historyItem)
                                    }
                                    .buttonStyle(.plain)

                                    if index < section.1.count - 1 {
                                        Divider()
                                            .padding(.leading, 56)
                                    }
                                }
                            }
                            .background(cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                            .padding(.horizontal, 16)
                        }
                    }

                    if hiddenCount > 0 {
                        Button {
                            showPaywall = true
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.orange)
                                    .frame(width: 32)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(hiddenCount) \(lang.t(nb: "søk låst", en: hiddenCount == 1 ? "more search locked" : "more searches locked"))")
                                        .font(.subheadline.weight(.medium))
                                    Text(lang.t(nb: "Lås opp full historikk for 19 kr", en: "Unlock full history for 19 kr"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
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
            if completedTrips.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "steeringwheel")
                        .font(.system(size: 60))
                        .foregroundStyle(.gray)
                    Text(lang.t(nb: "Ingen turer ennå", en: "No Trips Yet"))
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text(lang.t(nb: "Fullførte kjøreturer vises her", en: "Completed work trips will appear here"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(groupedTrips, id: \.0) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.0.uppercased())
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 20)
                                .padding(.top, section.0 == groupedTrips.first?.0 ? 0 : 8)

                            VStack(spacing: 0) {
                                ForEach(Array(section.1.enumerated()), id: \.element.id) { index, trip in
                                    NavigationLink {
                                        TripDetailView(trip: trip)
                                    } label: {
                                        tripRow(trip)
                                    }
                                    .buttonStyle(.plain)

                                    if index < section.1.count - 1 {
                                        Divider()
                                            .padding(.leading, 56)
                                    }
                                }
                            }
                            .background(cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                            .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.vertical, 20)
            }
        }
    }

    @ViewBuilder
    private func historyItemRow(_ historyItem: SearchHistoryItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(.blue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 6) {
                Text(historyItem.routeDescription)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: historyItem.vehicleTypeEnum == .car ? "car.fill" : "motorcycle.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Image(systemName: historyItem.fuelTypeEnum == .gas ? "fuelpump.fill" : "bolt.fill")
                            .font(.caption2)
                            .foregroundStyle(historyItem.fuelTypeEnum == .gas ? .orange : .yellow)
                    }

                    if historyItem.tollCount > 0 {
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(historyItem.tollCount) \(lang.t(nb: historyItem.tollCount == 1 ? "bom" : "bommer", en: historyItem.tollCount == 1 ? "toll" : "tolls"))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if historyItem.totalPrice > 0 {
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.0f kr", historyItem.totalPrice))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(historyItem.timeAgo)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func tripRow(_ trip: WorkTrip) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "steeringwheel")
                .font(.system(size: 24))
                .foregroundStyle(.blue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 6) {
                Text(trip.startTime.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute()))
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                HStack(spacing: 8) {
                    Text(trip.formattedDuration)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if trip.distanceKm > 0 {
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.1f km", trip.distanceKm))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if trip.totalTollCost > 0 {
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.0f kr", trip.totalTollCost))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if !trip.company.isEmpty {
                    Text(trip.company)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}
