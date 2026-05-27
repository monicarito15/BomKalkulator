import SwiftUI
import SwiftData

struct HistoryView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var purchaseManager: PurchaseManager

    @State private var showPaywall = false

    @Query(sort: \SearchHistoryItem.searchDate, order: .reverse)
    var searchHistory: [SearchHistoryItem]
    var onSelectSearch: (SearchHistoryItem) -> Void

    private var visibleHistory: [SearchHistoryItem] {
        purchaseManager.isPremium ? searchHistory : Array(searchHistory.prefix(PurchaseManager.freeSearchLimit))
    }

    private var hiddenCount: Int {
        purchaseManager.isPremium ? 0 : max(0, searchHistory.count - PurchaseManager.freeSearchLimit)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.white)
    }

    // Agrupar historial por período de tiempo
    private var groupedHistory: [(String, [SearchHistoryItem])] {
        let calendar = Calendar.current
        let now = Date()
        
        var groups: [String: [SearchHistoryItem]] = [:]
        
        for item in visibleHistory {
            let sectionTitle = getSectionTitle(for: item.searchDate, relativeTo: now, calendar: calendar)
            groups[sectionTitle, default: []].append(item)
        }
        
        // Ordenar las secciones por fecha más reciente
        return groups.sorted { first, second in
            let firstDate = first.value.first?.searchDate ?? Date.distantPast
            let secondDate = second.value.first?.searchDate ?? Date.distantPast
            return firstDate > secondDate
        }
    }
    
    // Determinar el título de la sección basado en la fecha
    private func getSectionTitle(for date: Date, relativeTo now: Date, calendar: Calendar) -> String {
        let daysDifference = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
        
        if daysDifference == 0 {
            return "Today"
        } else if daysDifference == 1 {
            return "Yesterday"
        } else if daysDifference <= 7 {
            return "Last Week"
        } else if daysDifference <= 30 {
            return "Last Month"
        } else {
            // Para fechas más antiguas, mostrar el mes y año
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: date)
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                if searchHistory.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 60))
                            .foregroundStyle(.gray)
                        
                        Text("No History")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Your recent searches will appear here")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // History items grouped by section
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(groupedHistory, id: \.0) { section in
                            VStack(alignment: .leading, spacing: 8) {
                                // Section header
                                Text(section.0.uppercased())
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 20)
                                    .padding(.top, section.0 == groupedHistory.first?.0 ? 0 : 8)

                                // Section items
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
                                        Text("\(hiddenCount) more search\(hiddenCount == 1 ? "" : "es") locked")
                                            .font(.subheadline.weight(.medium))
                                        Text("Unlock full history for 19 kr")
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
            .background(
                Color(colorScheme == .dark ? .black : .systemGroupedBackground)
                    .ignoresSafeArea()
            )
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !searchHistory.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Text("\(searchHistory.count) search\(searchHistory.count == 1 ? "" : "es")")
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
    
    // History Item Row
    @ViewBuilder
    private func historyItemRow(_ historyItem: SearchHistoryItem) -> some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(.blue)
                .frame(width: 32)
            
            // Content
            VStack(alignment: .leading, spacing: 6) {
                // Route description
                Text(historyItem.routeDescription)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // Details
                HStack(spacing: 8) {
                    // Vehicle & Fuel icons
                    HStack(spacing: 4) {
                        Image(systemName: historyItem.vehicleTypeEnum == .car ? "car.fill" : "motorcycle.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        
                        Image(systemName: historyItem.fuelTypeEnum == .gas ? "fuelpump.fill" : "bolt.fill")
                            .font(.caption2)
                            .foregroundStyle(historyItem.fuelTypeEnum == .gas ? .orange : .yellow)
                    }
                    
                    // Toll count
                    if historyItem.tollCount > 0 {
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text("\(historyItem.tollCount) toll\(historyItem.tollCount == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    // Price
                    if historyItem.totalPrice > 0 {
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text(String(format: "%.0f kr", historyItem.totalPrice))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Time ago
                Text(historyItem.timeAgo)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

//#Preview {
//    HistoryView(
//        searchHistory: [
//            SearchHistoryItem(
//                fromAddress: "Oslo",
//                toAddress: "Trondheim",
//                vehicleType: .car,
//                fuelType: .gas,
//                dateTime: Date(),
//                hasAutopass: true,
//                totalPrice: 450,
//                tollCount: 5
//            ),
//            SearchHistoryItem(
//                fromAddress: "Bergen",
//                toAddress: "Stavanger",
//                vehicleType: .car,
//                fuelType: .electric,
//                dateTime: Date().addingTimeInterval(-86400),
//                hasAutopass: false,
//                totalPrice: 320,
//                tollCount: 3
//            )
//        ],
//        onSelectSearch: { _ in }
//    )
//}


