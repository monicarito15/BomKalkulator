import SwiftUI
import CoreLocation
import SwiftData
import CoreLocation

struct CalculatorView: View {
    
    @ObservedObject var mapVM: MapViewModel
    
    @Binding var from: String
    @Binding var to: String
    @Binding var fromCoordinate: CLLocationCoordinate2D?
    @Binding var toCoordinate: CLLocationCoordinate2D?
    @State private var showMap = false
    
    @State private var showFromDirections = false
    @State private var showToDirections = false
    @State private var isFromCurrentLocation: Bool = false
    @State private var isToCurrentLocation: Bool = false
    @State private var showHistory = false
    @State private var shouldApplyLocationToFrom = true
    @Binding var autopassOn: Bool
    
    @Binding var currentDetent: PresentationDetent
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    
    @FocusState private var focus: FormFieldFocus?
    
    @Binding var selectedFuelType: FuelType
    @Binding var selectedVehicleType: VehicleType
    @Binding var selectedDateTime: Date
    
    @StateObject private var locationManager = LocationManager()
    
    
    let fuelTypes: [FuelType] = [.gas, .electric, .diesel]
    let vehicleTypes: [VehicleType] = [.car, .motorcycle]

    
    
    // Callback: le avisa al padre que calcule la ruta (los valores ya están compartidos via Binding)
    let onCalculate: () -> Void
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    routeAndTimeSection

                    // Rush Hour Warning (if applicable)
                    if selectedDateTime.isRushHour() {
                        RushHourWarningView(date: selectedDateTime)
                    }

                    autopassSection
                    calculateButton
                    nearbyTollsSection
                }
                .padding(.top, 10)
                .padding(.bottom, 30)
                .frame(maxWidth: .infinity)
            }
            .background(
                Color(colorScheme == .dark ? .black : .systemGroupedBackground)
                    .ignoresSafeArea()
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Calculate Toll")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
            }
        }
        .fullScreenCover(isPresented: $showFromDirections) {
            FromDirectionsView(
                searchText: $from,
                selectedCoordinate: $fromCoordinate,
                isFromCurrentLocation: $isFromCurrentLocation
            )
        }
        .fullScreenCover(isPresented: $showToDirections) {
            ToDirectionsView(
                searchText: $to,
                selectedCoordinate: $toCoordinate,
                isFromCurrentLocation: $isToCurrentLocation
            )
        }
        .onAppear {
            focus = .from
            if from.isEmpty {
                shouldApplyLocationToFrom = true
                isFromCurrentLocation = true
                locationManager.requestLocation()
            }
            
            else {
                shouldApplyLocationToFrom = false
                isFromCurrentLocation = false
            }
            Task {
                await mapVM.fetchTolls()
                mapVM.updateUserLocation()
                mapVM.updateNearbyTolls()
            }
        }
        .onDisappear {
            shouldApplyLocationToFrom = false
        }
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.white)
    }
    
    
    // Route & Time Section
    private var routeAndTimeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ROUTE & TIME")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
            
            VStack(spacing: 0) {
                fromField

                ZStack(alignment: .trailing) {
                    Divider()
                        .padding(.leading, 56)
                    swapButton
                        .padding(.trailing, 12)
                }

                toField
                
                Divider()
                    .padding(.leading, 56)
                
                datePickerField
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
    
    private var swapButton: some View {
        Button {
            swapFromTo()
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.blue))
                .shadow(color: Color.blue.opacity(0.3), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
        
        private func swapFromTo() {
            // Intercambiar textos
            let tempFrom = from
            from = to
            to = tempFrom
            
            // Intercambiar coordenadas
            let tempFromCoord = fromCoordinate
            fromCoordinate = toCoordinate
            toCoordinate = tempFromCoord
            
            // Intercambiar estados de ubicación actual
            let tempIsFromCurrentLocation = isFromCurrentLocation
            isFromCurrentLocation = isToCurrentLocation
            isToCurrentLocation = tempIsFromCurrentLocation
            
            // Evita que la LocationManager sobrescriba from inmediatamente
            shouldApplyLocationToFrom = false
            
            focus = .to
        }
    
    
    private var fromField: some View {
        HStack(spacing: 12) {
            Image(systemName: "circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(.green)
                .frame(width: 24)
            
            Button {
                currentDetent = .large
                showFromDirections = true
                shouldApplyLocationToFrom = false
                isFromCurrentLocation = false
            } label: {
                HStack {
                    if isFromCurrentLocation {
                        Image(systemName: "location.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.blue)
                        Text("Your location")
                            .foregroundStyle(.blue)
                            .lineLimit(1)
                    } else {
                        Text(from.isEmpty ? "From" : from)
                            .foregroundStyle(from.isEmpty ? .tertiary : .primary)
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(colorScheme == .dark ? Color(.systemGray6) : .white)
        .onReceive(locationManager.$currentAddress) { address in
            guard let address, !address.isEmpty,
                  shouldApplyLocationToFrom else { return }
            from = address
            shouldApplyLocationToFrom = false
        }
    }
    
    private var toField: some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(.red)
                .frame(width: 24)
            
            Button {
                currentDetent = .large
                showToDirections = true
            } label: {
                HStack {
                    if isToCurrentLocation {
                        Image(systemName: "location.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.blue)
                        Text("Your location")
                            .foregroundStyle(.blue)
                            .lineLimit(1)
                    } else {
                        Text(to.isEmpty ? "To" : to)
                            .foregroundStyle(to.isEmpty ? .tertiary : .primary)
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(colorScheme == .dark ? Color(.systemGray6) : .white)
    }




    private var datePickerField: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar")
                .foregroundStyle(.secondary)
                .frame(width: 24)
            
            DatePicker(
                "Date and Time",
                selection: $selectedDateTime,
                displayedComponents: [.date, .hourAndMinute]
            )
            .labelsHidden()
            .datePickerStyle(.compact)
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(colorScheme == .dark ? Color(.systemGray6) : .white)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // Chips Section
    private var selectionChipsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Vehicle row
            HStack(spacing: 8) {
                Image(systemName: "car.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)

                chip(icon: "car.fill", label: "Car", isSelected: selectedVehicleType == .car) {
                    selectedVehicleType = .car
                }
                chip(icon: "motorcycle.fill", label: "Motorcycle", isSelected: selectedVehicleType == .motorcycle) {
                    selectedVehicleType = .motorcycle
                }
            }
            .padding(.horizontal, 16)

            // Fuel row
            HStack(spacing: 8) {
                Image(systemName: "fuelpump.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)

                chip(icon: "fuelpump.fill", label: "Gas", isSelected: selectedFuelType == .gas) {
                    selectedFuelType = .gas
                }
                chip(icon: "bolt.fill", label: "Electric", isSelected: selectedFuelType == .electric) {
                    selectedFuelType = .electric
                }
                chip(icon: "fuelpump.fill", label: "Diesel", isSelected: selectedFuelType == .diesel) {
                    selectedFuelType = .diesel
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func chip(icon: String, label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                Text(label)
                    .font(.system(size: 14, weight: .medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(.systemGray5))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // Vehicle Details Section
    private var autopassSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("VEHICLE DETAILS")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)

            VStack(spacing: 0) {
                // Vehicle chips row
                HStack(spacing: 8) {
                    Image(systemName: "car.fill")
                        .foregroundStyle(.secondary)
                        .frame(width: 24)
                    chip(icon: "car.fill", label: "Car", isSelected: selectedVehicleType == .car) {
                        selectedVehicleType = .car
                    }
                    chip(icon: "motorcycle.fill", label: "Motorcycle", isSelected: selectedVehicleType == .motorcycle) {
                        selectedVehicleType = .motorcycle
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(colorScheme == .dark ? Color(.systemGray6) : .white)

                Divider()
                    .padding(.leading, 56)

                // Fuel chips row
                HStack(spacing: 8) {
                    Image(systemName: "fuelpump.fill")
                        .foregroundStyle(.secondary)
                        .frame(width: 24)
                    chip(icon: "fuelpump.fill", label: "Gas", isSelected: selectedFuelType == .gas) {
                        selectedFuelType = .gas
                    }
                    chip(icon: "bolt.fill", label: "Electric", isSelected: selectedFuelType == .electric) {
                        selectedFuelType = .electric
                    }
                    chip(icon: "fuelpump.fill", label: "Diesel", isSelected: selectedFuelType == .diesel) {
                        selectedFuelType = .diesel
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(colorScheme == .dark ? Color(.systemGray6) : .white)

            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
            .padding(.horizontal, 16)

            HStack(spacing: 6) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.caption)
                    .foregroundStyle(.blue)
                Text("All prices are AutoPASS rates")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
        }
    }

    // Calculate Button
    private var calculateButton: some View {
        Button {
            // Determinar la dirección "From" a usar
            let fromAddress: String
            if isFromCurrentLocation {
                // Si es ubicación actual, usar la dirección del locationManager
                fromAddress = locationManager.currentAddress ?? ""
            } else {
                fromAddress = from.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            // Determinar la dirección "To" a usar
            let toAddress: String
            if isToCurrentLocation {
                // Si es ubicación actual, usar la dirección del locationManager
                toAddress = locationManager.currentAddress ?? ""
            } else {
                toAddress = to.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            guard !toAddress.isEmpty else { return }
            
            // Guardar en el historial
            saveToHistory(
                fromAddress: fromAddress,
                toAddress: toAddress,
                vehicleType: selectedVehicleType.rawValue,
                fuelType: selectedFuelType.rawValue,
                hasAutopass: autopassOn,
                dateTime: selectedDateTime
            )
            
            // Actualizar los bindings con las direcciones resueltas
            from = fromAddress
            to = toAddress
            
            onCalculate()
            dismiss()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                Text("Calculate Route")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(.white)
            .background(Color.blue)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .disabled(to.isEmpty && !isToCurrentLocation)
        .opacity((to.isEmpty && !isToCurrentLocation) ? 0.5 : 1.0)
    }
    
// Nearby Tolls Section
    private var nearbyTollsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NEARBY TOLLS")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
            
            // Crear una instancia para verificar si hay peajes
            let nearbyTollsView = NearbyTolls(mapVm: mapVM) { selectedToll in
                handleTollSelection(selectedToll)
            }
            
            nearbyTollsView
                .padding(.horizontal, 16)
        }
    }
    
    // Helper para verificar si hay peajes cercanos
    private var hasNearbyTollsInRange: Bool {
        guard let userLocation = mapVM.userLocation else { return false }
        let userCLLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        let maxDistance: Double = 50_000
        
        return mapVM.toll.contains { toll in
            guard let coordinates = toll.lokasjon?.coordinates else { return false }
            let tollLocation = CLLocation(latitude: coordinates.latitude, longitude: coordinates.longitude)
            let distance = userCLLocation.distance(from: tollLocation)
            return distance <= maxDistance
        }
    }
    
    // Helper function to apply card styling
    private func cardStyle<Content: View>(_ content: Content) -> some View {
        content
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
    }
    
    
    private func handleTollSelection(_ selectedToll: Vegobjekt) {
        guard let tollCoords = selectedToll.lokasjon?.coordinates else { return }
        
        let tollDisplayName = selectedToll.displayName

        let location = CLLocation(latitude: tollCoords.latitude, longitude: tollCoords.longitude)
        let capturedUserLocation = mapVM.userLocation
        CLGeocoder().reverseGeocodeLocation(location) { placemarks, _ in
            let tollAddress = placemarks?.first?.name ?? tollDisplayName

            // Si FROM está vacío y no es "Your location", poner la ubicación del usuario
            if from.isEmpty && !isFromCurrentLocation {
                if let userLoc = capturedUserLocation {
                    let userLocation = CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
                    CLGeocoder().reverseGeocodeLocation(userLocation) { placemarks, _ in
                        let fromAddress = placemarks?.first?.name ?? locationManager.currentAddress ?? ""
                        from = fromAddress
                        isFromCurrentLocation = false
                    }
                }
            }
            
            // Siempre poner el toll en TO
            to = tollAddress
            isToCurrentLocation = false
        }
    }
    
    // Save to History — deduplicates same route on the same day
    private func saveToHistory(
        fromAddress: String,
        toAddress: String,
        vehicleType: String,
        fuelType: String,
        hasAutopass: Bool,
        dateTime: Date
    ) {
        let existing = (try? modelContext.fetch(FetchDescriptor<SearchHistoryItem>())) ?? []
        let calendar = Calendar.current

        if let duplicate = existing.first(where: {
            $0.fromAddress == fromAddress &&
            $0.toAddress == toAddress &&
            calendar.isDateInToday($0.searchDate)
        }) {
            duplicate.searchDate = Date()
            duplicate.vehicleType = vehicleType
            duplicate.fuelType = fuelType
            duplicate.hasAutopass = hasAutopass
            duplicate.dateTime = dateTime
        } else {
            let history = SearchHistoryItem(
                fromAddress: fromAddress,
                toAddress: toAddress,
                vehicleType: VehicleType(rawValue: vehicleType) ?? .car,
                fuelType: FuelType(rawValue: fuelType) ?? .gas,
                dateTime: dateTime,
                hasAutopass: hasAutopass
            )
            modelContext.insert(history)
        }

        do {
            try modelContext.save()
        } catch {
            #if DEBUG
            print("Error saving route: \(error.localizedDescription)")
            #endif
        }
    }
    
    enum FormFieldFocus: Hashable {
        case from
        case to
    }
}
