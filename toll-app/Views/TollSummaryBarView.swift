import SwiftUI
import MapKit

struct TollSummaryBar: View {
    let tollCount: Int
    let total: Double
    let isEstimated: Bool
    let isLoadingPrices: Bool
    let vehicleType: VehicleType
    let fuelType: FuelType
    let hasAutopass: Bool
    let originCoordinate: CLLocationCoordinate2D?
    let destinationCoordinate: CLLocationCoordinate2D?
    let fromAddress: String
    let toAddress: String
    let route: AppRoute?
    let onTap: () -> Void
    
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

    private var hasFerry: Bool {
        route?.hasFerry ?? false
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // Top line: toll count and price
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        if isLoadingPrices {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Calculating...")
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(.secondary)
                            }
                        } else if total == 0 && isEstimated {
                            Text("Price not available")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.orange)
                        } else if total == 0 {
                            Text("No toll charges")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.blue)
                        } else {
                            Text(String(format: "%.2f kr", total))
                                .font(.title2.weight(.bold))
                        }

                        Text("\(tollCount) tolls")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Details")
                            .font(.subheadline.weight(.semibold))
                        Image(systemName: "chevron.up")
                            .font(.caption)
                    }
                }
                
                // Middle line: distance and travel time
                if route != nil {
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "road.lanes")
                                .font(.caption)
                                .foregroundStyle(.blue)
                            Text(distanceText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Divider()
                            .frame(height: 12)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.caption)
                                .foregroundStyle(.blue)
                            Text(travelTimeText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                    }
                }
                
                // Ferry warning
                if hasFerry {
                    HStack(spacing: 6) {
                        Image(systemName: "ferry.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)
                        Text("Ferry prices not included")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }

                // Bottom line: vehicle details
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: vehicleType == .car ? "car.fill" : "bicycle")
                            .font(.caption)
                            .foregroundStyle(.blue)
                        Text(vehicleType.rawValue.capitalized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Divider()
                        .frame(height: 12)
                    
                    HStack(spacing: 4) {
                        Image(systemName: fuelType == .electric ? "bolt.fill" : "fuelpump.fill")
                            .font(.caption)
                            .foregroundStyle(fuelType == .electric ? .green : fuelType == .diesel ? .gray : .orange)
                        Text(fuelType.rawValue.capitalized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Divider()
                        .frame(height: 12)

                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)
                        Text("AutoPASS")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(radius: 6)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: 500)
        .padding(.horizontal, 60)
        .padding(.top, 80)
    }
}




#Preview("TollSummaryBar") {
    VStack {
        Spacer()
        TollSummaryBar(
            tollCount: 8,
            total: 191.20,
            isEstimated: false,
            isLoadingPrices: false,
            vehicleType: .car,
            fuelType: .electric,
            hasAutopass: true,
            originCoordinate: CLLocationCoordinate2D(latitude: 59.9139, longitude: 10.7522),
            destinationCoordinate: CLLocationCoordinate2D(latitude: 60.3913, longitude: 5.3221),
            fromAddress: "Oslo",
            toAddress: "Bergen",
            route: nil
        ) {
            print("Tapped details")
        }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.gray.opacity(0.2))
}



