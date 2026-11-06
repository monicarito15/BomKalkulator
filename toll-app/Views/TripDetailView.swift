import SwiftUI

struct TripDetailView: View {
    let trip: WorkTrip
    @ObservedObject private var lang = LanguageManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var showPDF = false

    private var cardBackground: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.white)
    }

    private var tripDateLabel: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "nb_NO")
        f.dateFormat = "d. MMMM yyyy"
        return f.string(from: trip.startTime)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                dateHeader
                statsCards
                if !trip.passages.isEmpty {
                    tollStations
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(Color(colorScheme == .dark ? .black : .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(lang.t(nb: "Kjøretur", en: "Trip"))
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                showPDF = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.fill")
                    Text(lang.t(nb: "Last ned PDF", en: "Download PDF"))
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
        .sheet(isPresented: $showPDF) {
            PeriodReportView(
                trips: [trip],
                periodLabel: tripDateLabel,
                driverName: trip.driverName,
                company: trip.company
            )
        }
    }

    private var dateHeader: some View {
        VStack(spacing: 4) {
            Text(trip.startTime.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(.title2)
                .fontWeight(.semibold)

            if let end = trip.endTime {
                Text("\(trip.startTime.formatted(.dateTime.hour().minute()))–\(end.formatted(.dateTime.hour().minute()))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    private var statsCards: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(lang.t(nb: "DISTANSE", en: "DISTANCE"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(trip.distanceKm > 0 ? String(format: "%.1f km", trip.distanceKm) : "—")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 6) {
                    Text(lang.t(nb: "VARIGHET", en: "DURATION"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(trip.formattedDuration)
                        .font(.title2)
                        .fontWeight(.bold)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            HStack {
                Text(lang.t(nb: "BOMPENGER", en: "TOLL COST"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(trip.totalTollCost > 0 ? String(format: "%.2f kr", trip.totalTollCost) : "0,00 kr")
                    .font(.title2)
                    .fontWeight(.bold)
            }
            .padding(16)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var tollStations: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(lang.t(nb: "BOMSTASJONER", en: "TOLL STATIONS"))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(Array(trip.passages.enumerated()), id: \.element.id) { index, passage in
                    HStack(spacing: 12) {
                        Text(passage.passedAt.formatted(.dateTime.hour().minute()))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(width: 44, alignment: .leading)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(passage.stationName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(lang.t(nb: "AutoPass registrert", en: "AutoPass registered"))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }

                        Spacer()

                        Text(String(format: "%.2f kr", passage.price))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    if index < trip.passages.count - 1 {
                        Divider()
                            .padding(.leading, 72)
                    }
                }
            }
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
