import SwiftUI
import MapKit

struct TollPassedListView: View {
    
    let tollCharges: [TollCharge]
    let route: AppRoute?
    let fromAddress: String
    let toAddress: String
    let vehicleType: VehicleType
    let isEstimatedPrice: Bool = false // Default value for backward compatibility
    var selectedDetent: PresentationDetent = .medium
    
    @Environment(\.colorScheme) private var colorScheme
    var onSelectSearch: (SearchHistoryItem) -> Void = { _ in }
    
    private var displayFrom: String {
        fromAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Unknown origin" : fromAddress
    }
    
    private var displayTo: String {
        toAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Unknown destination" : toAddress
    }
    
    private var totalPrice: Double {
        tollCharges.reduce(0) { $0 + $1.price }
    }
    
    private var distanceText: String {
        guard let route else { return "" }
        let km = route.distance / 1000
        return String(format: "%.0f km", km)
    }
    
    private var travelTimeText: String {
        guard let route else { return "" }
        let totalSeconds = Int(route.expectedTravelTime)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)min"
        }
        return "\(minutes) min"
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.white)
    }
    


    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Route Section
                    routeSection

                    // Route Info (Distance & Time)
                    if route != nil {
                        routeInfoSection
                    }

                    // Toll Stations Section
                    tollStationsSection

                    // Total Section
                    totalSection
                }
                .padding(.vertical, 20)
            }
            .scrollDisabled(selectedDetent != .large)
            .background(
                Color(colorScheme == .dark ? .black : .systemGroupedBackground)
                    .ignoresSafeArea()
            )
            .navigationTitle("Tolls on Route")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - Route Section
    private var routeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ROUTE")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
            
            VStack(spacing: 12) {
                // From
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "location.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.green)
                        
                        Text("Origin")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text(displayFrom)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.green.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.green.opacity(0.2), lineWidth: 1)
                )
                
                // Arrow indicator
                HStack {
                    Spacer()
                    Image(systemName: "arrow.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                
                // To
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.blue)

                        Text("Destination")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    }

                    Text(displayTo)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.blue.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.blue.opacity(0.2), lineWidth: 1)
                )
            }
            .padding(16)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Route Info Section
    private var routeInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ROUTE INFO")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
            
            HStack(spacing: 16) {
                // Distance
                HStack(spacing: 8) {
                    Image(systemName: "road.lanes")
                        .font(.system(size: 20))
                        .foregroundStyle(.blue)
                        .frame(width: 32)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Distance")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(distanceText)
                            .font(.headline)
                    }
                    
                    Spacer()
                }
                
                Divider()
                    .frame(height: 40)
                
                // Travel Time
                HStack(spacing: 8) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.orange)
                        .frame(width: 32)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Time")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(travelTimeText)
                            .font(.headline)
                    }
                    
                    Spacer()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
            .padding(.horizontal, 16)
        }
    }
    
    // Toll Stations Section
    private var tollStationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TOLL STATIONS")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
            
            VStack(spacing: 0) {
                // Warning banner if prices are estimated
                if isEstimatedPrice {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.orange)
                        
                        Text("Individual prices are estimated. Total is accurate.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.orange.opacity(0.08))
                    
                    Divider()
                }
                
                ForEach(Array(tollCharges.enumerated()), id: \.element.id) { index, charge in
                    HStack(spacing: 12) {
                        Image(systemName: "car.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.purple)
                            .frame(width: 24)
                        
                        Text(charge.toll)
                            .font(.body)
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            if isEstimatedPrice {
                                Text("~")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                            Text(String(format: "kr. %.2f", charge.price))
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    
                    if index < tollCharges.count - 1 {
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
    
    //Total Section
    private var totalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SUMMARY")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
            
            HStack(spacing: 12) {
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.green)
                    .frame(width: 32)
                
                Text("Total Cost")
                    .font(.headline)
                
                Spacer()
                
                Text(String(format: "kr. %.2f", totalPrice))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [
                        Color.green.opacity(0.1),
                        Color.blue.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.green.opacity(0.3), lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)

            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.caption2)
                Text("Prices are based on NVDB data and may not reflect the latest AutoPASS rates.")
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 20)
        }
    }
}

