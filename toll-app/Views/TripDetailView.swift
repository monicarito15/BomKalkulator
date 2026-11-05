import SwiftUI

struct TripDetailView: View {
    let trip: WorkTrip
    @Environment(\.colorScheme) private var colorScheme
    @State private var showPDF = false

    private var cardBackground: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.white)
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
        .navigationTitle("Trip")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                showPDF = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.fill")
                    Text("Last ned PDF")
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
            PDFReportView(trip: trip)
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
                    Text("DISTANSE")
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
                    Text("VARIGHET")
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
                Text("BOMPENGER")
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
            Text("BOMSTASJONER")
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
                            Text("AutoPass registrert")
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
