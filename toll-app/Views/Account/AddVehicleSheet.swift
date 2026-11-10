import SwiftUI
import SwiftData

struct AddVehicleSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var vehicles: [UserVehicle]
    @ObservedObject private var lang = LanguageManager.shared
    @AppStorage("defaultVehicle") private var defaultVehicle: String = VehicleType.car.rawValue
    @AppStorage("defaultFuel") private var defaultFuel: String = FuelType.gas.rawValue

    @State private var name = ""
    @State private var registrationNumber = ""
    @State private var vehicleType: VehicleType = .car
    @State private var fuelType: FuelType = .gas
    @State private var ownership: CarOwnership = .privateOwned
    @State private var hasAutopass = true

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent(lang.t(nb: "Navn", en: "Name")) {
                        TextField(lang.t(nb: "f.eks. Tesla Model Y", en: "e.g. Tesla Model Y"), text: $name)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent(lang.t(nb: "Regnr.", en: "Reg. no.")) {
                        TextField("EV 12345", text: $registrationNumber)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.characters)
                    }
                } header: {
                    Text(lang.t(nb: "INFORMASJON", en: "INFORMATION"))
                }

                Section {
                    Picker(lang.t(nb: "Type", en: "Type"), selection: $vehicleType) {
                        Text(lang.t(nb: "Personbil", en: "Personal car")).tag(VehicleType.car)
                        Text(lang.t(nb: "Stor bil", en: "Large vehicle")).tag(VehicleType.largeCar)
                    }
                    Picker(lang.t(nb: "Drivstoff", en: "Fuel"), selection: $fuelType) {
                        Text(lang.t(nb: "Elektrisk", en: "Electric")).tag(FuelType.electric)
                        Text("Bensin/Diesel").tag(FuelType.gas)
                    }
                    Picker(lang.t(nb: "Eierskap", en: "Ownership"), selection: $ownership) {
                        Text(lang.t(nb: "Privatbil", en: "Private car")).tag(CarOwnership.privateOwned)
                        Text(lang.t(nb: "Firmabil", en: "Company car")).tag(CarOwnership.company)
                    }
                    Toggle("AutoPass", isOn: $hasAutopass)
                } header: {
                    Text(lang.t(nb: "SPESIFIKASJON", en: "SPECIFICATION"))
                }
            }
            .navigationTitle(lang.t(nb: "Legg til kjøretøy", en: "Add vehicle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(lang.t(nb: "Avbryt", en: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(lang.t(nb: "Lagre", en: "Save")) { saveVehicle() }
                        .disabled(name.isEmpty)
                }
            }
        }
    }

    private func saveVehicle() {
        let isFirst = vehicles.isEmpty
        let vehicle = UserVehicle(
            name: name,
            registrationNumber: registrationNumber,
            vehicleType: vehicleType,
            fuelType: fuelType,
            ownership: ownership,
            isPrimary: isFirst,
            hasAutopass: hasAutopass
        )
        modelContext.insert(vehicle)
        if isFirst {
            defaultVehicle = vehicleType.rawValue
            defaultFuel = fuelType.rawValue
        }
        try? modelContext.save()
        dismiss()
    }
}
