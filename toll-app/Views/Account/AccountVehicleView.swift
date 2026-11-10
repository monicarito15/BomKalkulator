import SwiftUI
import SwiftData

struct AccountVehicleView: View {
    @ObservedObject private var lang = LanguageManager.shared
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserVehicle.createdAt) private var vehicles: [UserVehicle]
    @AppStorage("defaultVehicle") private var defaultVehicle: String = VehicleType.car.rawValue
    @AppStorage("defaultFuel") private var defaultFuel: String = FuelType.gas.rawValue
    @State private var showAddSheet = false

    var body: some View {
        List {
            if vehicles.isEmpty {
                Section(lang.t(nb: "MINE KJØRETØY", en: "MY VEHICLES")) {
                    HStack {
                        Spacer()
                        Text(lang.t(nb: "Ingen kjøretøy registrert", en: "No vehicles registered"))
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                        Spacer()
                    }
                }
            } else {
                ForEach(vehicles) { vehicle in
                    if vehicles.first?.persistentModelID == vehicle.persistentModelID {
                        Section(lang.t(nb: "MINE KJØRETØY", en: "MY VEHICLES")) {
                            vehicleHeaderRow(vehicle)
                            autoPassRow(vehicle)
                            tollClassRow(vehicle)
                        }
                    } else {
                        Section {
                            vehicleHeaderRow(vehicle)
                            autoPassRow(vehicle)
                            tollClassRow(vehicle)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(lang.t(nb: "Kjøretøy", en: "Vehicles"))
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                showAddSheet = true
            } label: {
                Text("+ \(lang.t(nb: "Legg til kjøretøy", en: "Add vehicle"))")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue, lineWidth: 1.5)
                    )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(.systemGroupedBackground))
        }
        .sheet(isPresented: $showAddSheet) {
            AddVehicleSheet()
        }
    }

    private func vehicleHeaderRow(_ vehicle: UserVehicle) -> some View {
        NavigationLink(destination: EditVehicleView(vehicle: vehicle)) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(vehicle.isPrimary ? Color.blue.opacity(0.12) : Color(.systemGray5))
                        .frame(width: 40, height: 40)
                    Image(systemName: "car.fill")
                        .foregroundStyle(vehicle.isPrimary ? Color.blue : Color(.systemGray2))
                        .font(.system(size: 18))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(vehicle.name)
                        .font(.headline)
                        .foregroundStyle(vehicle.isPrimary ? .primary : .secondary)
                    Text([vehicle.registrationNumber, fuelLabel(vehicle.fuelType), ownershipLabel(vehicle.ownership)]
                        .filter { !$0.isEmpty }
                        .joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(vehicle.isPrimary ? .secondary : .tertiary)
                }
                Spacer()
                if vehicle.isPrimary {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.system(size: 22))
                }
            }
            .padding(.vertical, 4)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                delete(vehicle)
            } label: {
                Label(lang.t(nb: "Slett", en: "Delete"), systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if !vehicle.isPrimary {
                Button {
                    makePrimary(vehicle)
                } label: {
                    Label(lang.t(nb: "Gjør primær", en: "Make primary"), systemImage: "star.fill")
                }
                .tint(.green)
            }
        }
    }

    private func autoPassRow(_ vehicle: UserVehicle) -> some View {
        HStack {
            Text("AutoPass")
                .foregroundStyle(vehicle.isPrimary ? .primary : .secondary)
            Spacer()
            Text(vehicle.hasAutopass
                 ? lang.t(nb: "Aktiv", en: "Active")
                 : lang.t(nb: "Inaktiv", en: "Inactive"))
                .foregroundStyle(vehicle.isPrimary
                    ? (vehicle.hasAutopass ? Color.blue : Color.secondary)
                    : Color(.tertiaryLabel))
        }
    }

    private func tollClassRow(_ vehicle: UserVehicle) -> some View {
        HStack {
            Text(lang.t(nb: "Takstgruppe", en: "Toll class"))
                .foregroundStyle(vehicle.isPrimary ? .primary : .secondary)
            Spacer()
            Text(vehicle.vehicleType == .car
                 ? lang.t(nb: "Personbil", en: "Personal car")
                 : lang.t(nb: "Stor bil", en: "Large vehicle"))
                .foregroundStyle(vehicle.isPrimary ? Color.blue : Color(.tertiaryLabel))
        }
    }

    private func fuelLabel(_ fuelType: FuelType) -> String {
        fuelType == .electric
            ? lang.t(nb: "Elektrisk", en: "Electric")
            : "Bensin/Diesel"
    }

    private func ownershipLabel(_ ownership: CarOwnership) -> String {
        ownership == .company
            ? lang.t(nb: "Firmabil", en: "Company car")
            : lang.t(nb: "Privatbil", en: "Private car")
    }

    private func delete(_ vehicle: UserVehicle) {
        let wasPrimary = vehicle.isPrimary
        let remaining = vehicles.filter { $0.persistentModelID != vehicle.persistentModelID }
        modelContext.delete(vehicle)
        if wasPrimary, let newPrimary = remaining.first {
            newPrimary.isPrimary = true
            defaultVehicle = newPrimary.vehicleTypeRaw
            defaultFuel = newPrimary.fuelTypeRaw
        }
        try? modelContext.save()
    }

    private func makePrimary(_ vehicle: UserVehicle) {
        vehicles.forEach { $0.isPrimary = false }
        vehicle.isPrimary = true
        defaultVehicle = vehicle.vehicleTypeRaw
        defaultFuel = vehicle.fuelTypeRaw
        try? modelContext.save()
    }
}
