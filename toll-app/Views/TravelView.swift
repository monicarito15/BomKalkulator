
// Este es el parent de calculatorView
import SwiftUI
import MapKit
import SwiftData
import StoreKit

struct TravelView: View {

    @Binding var showSheet: Bool
    @Binding var currentDetent : PresentationDetent

    @Binding var selectedHistoryItem: SearchHistoryItem?

    @Environment(\.modelContext) private var modelContext
    @StateObject private var vm = MapViewModel()
    @EnvironmentObject var purchaseManager: PurchaseManager
    @Environment(\.requestReview) private var requestReview
    @State private var showPaywall = false
    
    @State private var from = ""
    @State private var to = ""
    @State private var fromCoordinate: CLLocationCoordinate2D?
    @State private var toCoordinate: CLLocationCoordinate2D?
    @AppStorage("defaultVehicle") private var defaultVehicle: String = VehicleType.car.rawValue
    @AppStorage("defaultFuel") private var defaultFuel: String = FuelType.gas.rawValue
    @AppStorage("defaultAutopass") private var defaultAutopass: Bool = false

    @State private var vehicleType: VehicleType = VehicleType(rawValue: UserDefaults.standard.string(forKey: "defaultVehicle") ?? "") ?? .car
    @State private var fuelType: FuelType = FuelType(rawValue: UserDefaults.standard.string(forKey: "defaultFuel") ?? "") ?? .gas
    @State private var dateTime: Date = Date()
    @State private var hasAutopass: Bool = UserDefaults.standard.bool(forKey: "defaultAutopass")
    
 
    
    var body: some View {
        MapView(
            from: from,
            to: to,
            fromCoordinate: fromCoordinate,
            toCoordinate: toCoordinate,
            vehicleType: vehicleType,
            fuelType: fuelType,
            dateTime: dateTime,
            hasAutopass: hasAutopass,
            mapVM: vm
        )
        .safeAreaInset(edge: .bottom) {
            if !showSheet {
                calculateCard
            }
        }
        .sheet(isPresented: $showSheet) {
            VStack {
                CalculatorView(
                    mapVM: vm,
                    from: $from,
                    to: $to,
                    fromCoordinate: $fromCoordinate,
                    toCoordinate: $toCoordinate,
                    autopassOn: $hasAutopass,
                    currentDetent: $currentDetent,
                    selectedFuelType: $fuelType,
                    selectedVehicleType: $vehicleType,
                    selectedDateTime: $dateTime,
                    onCalculate: {
                        guard purchaseManager.canSearch else {
                            showPaywall = true
                            return
                        }
                        purchaseManager.recordSearch()
                        vm.resetResult()
                        Task { @MainActor in
                            await vm.getDirectionsFromAddresses(
                                fromAddress: from,
                                toAddress: to,
                                fromCoordinate: fromCoordinate,
                                toCoordinate: toCoordinate
                            )
                        }
                    }
                )
        }
            .presentationDetents([.height(520), .large], selection: $currentDetent)
            .presentationDragIndicator(.visible)
            .onAppear {
                currentDetent = .height(520)
            }
        }
      
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environmentObject(purchaseManager)
        }
        .onChange(of: defaultVehicle) { _, newValue in
            if from.isEmpty && to.isEmpty {
                vehicleType = VehicleType(rawValue: newValue) ?? .car
            }
        }
        .onChange(of: defaultFuel) { _, newValue in
            if from.isEmpty && to.isEmpty {
                fuelType = FuelType(rawValue: newValue) ?? .gas
            }
        }
        .onChange(of: defaultAutopass) { _, newValue in
            if from.isEmpty && to.isEmpty {
                hasAutopass = newValue
            }
        }
        .onChange(of: purchaseManager.reviewRequested) { _, requested in
            if requested {
                requestReview()
                purchaseManager.reviewRequested = false
            }
        }
        .onChange(of: vm.tollsOnRoute) { _, tolls in
            guard vm.hasResult else { return }
            let existing = (try? modelContext.fetch(FetchDescriptor<SearchHistoryItem>(
                sortBy: [SortDescriptor(\.searchDate, order: .reverse)]
            ))) ?? []
            guard let latest = existing.first else { return }
            latest.tollCount = tolls.count
            try? modelContext.save()
        }
        .onChange(of: vm.hasResult) { _, hasResult in
            if hasResult { showSheet = false }
        }
        .onChange(of: selectedHistoryItem) { _, newValue in
            // Cuando se selecciona un item del historial, rellenar los campos
            if let historyItem = newValue {
                from = historyItem.fromAddress
                to = historyItem.toAddress
                vehicleType = historyItem.vehicleTypeEnum
                fuelType = historyItem.fuelTypeEnum
                dateTime = historyItem.dateTime
                hasAutopass = historyItem.hasAutopass
                
                // Abrir el sheet con los datos precargados
                showSheet = true
                
                // Limpiar la selección
                selectedHistoryItem = nil
            }
        }
    }

    private var calculateCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Calculate toll costs")
                        .font(.headline)
                    Text("Find price, time and toll stations for your route.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Button {
                showSheet = true
            } label: {
                Text("Calculate route")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: -2)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

