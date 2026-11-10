import SwiftUI
import SwiftData

struct EditVehicleView: View {
    @Bindable var vehicle: UserVehicle
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var vehicles: [UserVehicle]
    @ObservedObject private var lang = LanguageManager.shared
    @AppStorage("defaultVehicle") private var defaultVehicle: String = VehicleType.car.rawValue
    @AppStorage("defaultFuel") private var defaultFuel: String = FuelType.gas.rawValue
    @State private var showDeleteAlert = false

    private var vehicleTypeBinding: Binding<VehicleType> {
        Binding(get: { vehicle.vehicleType }, set: { vehicle.vehicleTypeRaw = $0.rawValue })
    }
    private var fuelTypeBinding: Binding<FuelType> {
        Binding(get: { vehicle.fuelType }, set: { vehicle.fuelTypeRaw = $0.rawValue })
    }
    private var ownershipBinding: Binding<CarOwnership> {
        Binding(get: { vehicle.ownership }, set: { vehicle.ownershipRaw = $0.rawValue })
    }

    var body: some View {
        List {
            Section {
                LabeledContent(lang.t(nb: "Navn", en: "Name")) {
                    TextField(lang.t(nb: "f.eks. Tesla Model Y", en: "e.g. Tesla Model Y"), text: $vehicle.name)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent(lang.t(nb: "Regnr.", en: "Reg. no.")) {
                    TextField("EV 12345", text: $vehicle.registrationNumber)
                        .multilineTextAlignment(.trailing)
                        .textInputAutocapitalization(.characters)
                }
            } header: {
                Text(lang.t(nb: "INFORMASJON", en: "INFORMATION"))
            }

            Section {
                Picker(lang.t(nb: "Type", en: "Type"), selection: vehicleTypeBinding) {
                    Text(lang.t(nb: "Personbil", en: "Personal car")).tag(VehicleType.car)
                    Text(lang.t(nb: "Stor bil", en: "Large vehicle")).tag(VehicleType.largeCar)
                }
                Picker(lang.t(nb: "Drivstoff", en: "Fuel"), selection: fuelTypeBinding) {
                    Text(lang.t(nb: "Elektrisk", en: "Electric")).tag(FuelType.electric)
                    Text("Bensin/Diesel").tag(FuelType.gas)
                }
                Picker(lang.t(nb: "Eierskap", en: "Ownership"), selection: ownershipBinding) {
                    Text(lang.t(nb: "Privatbil", en: "Private car")).tag(CarOwnership.privateOwned)
                    Text(lang.t(nb: "Firmabil", en: "Company car")).tag(CarOwnership.company)
                }
                Toggle("AutoPass", isOn: $vehicle.hasAutopass)
            } header: {
                Text(lang.t(nb: "SPESIFIKASJON", en: "SPECIFICATION"))
            }

            if !vehicle.isPrimary {
                Section {
                    Button {
                        makePrimary()
                    } label: {
                        Label(lang.t(nb: "Gjør til primær", en: "Set as primary"), systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Label(lang.t(nb: "Slett kjøretøy", en: "Delete vehicle"), systemImage: "trash")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(vehicle.name.isEmpty ? lang.t(nb: "Rediger", en: "Edit") : vehicle.name)
        .navigationBarTitleDisplayMode(.inline)
        .alert(lang.t(nb: "Slett kjøretøy", en: "Delete vehicle"), isPresented: $showDeleteAlert) {
            Button(lang.t(nb: "Slett", en: "Delete"), role: .destructive) { deleteAndDismiss() }
            Button(lang.t(nb: "Avbryt", en: "Cancel"), role: .cancel) {}
        } message: {
            Text(lang.t(
                nb: "Er du sikker på at du vil slette \(vehicle.name)?",
                en: "Are you sure you want to delete \(vehicle.name)?"
            ))
        }
        .onDisappear {
            try? modelContext.save()
        }
    }

    private func makePrimary() {
        vehicles.forEach { $0.isPrimary = false }
        vehicle.isPrimary = true
        defaultVehicle = vehicle.vehicleTypeRaw
        defaultFuel = vehicle.fuelTypeRaw
        try? modelContext.save()
    }

    private func deleteAndDismiss() {
        let wasPrimary = vehicle.isPrimary
        let remaining = vehicles.filter { $0.persistentModelID != vehicle.persistentModelID }
        modelContext.delete(vehicle)
        if wasPrimary, let newPrimary = remaining.first {
            newPrimary.isPrimary = true
            defaultVehicle = newPrimary.vehicleTypeRaw
            defaultFuel = newPrimary.fuelTypeRaw
        }
        try? modelContext.save()
        dismiss()
    }
}
