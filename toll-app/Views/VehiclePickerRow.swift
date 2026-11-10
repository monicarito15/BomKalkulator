import SwiftUI
import SwiftData

struct VehicleSelectionCard: View {
    let vehicle: UserVehicle?
    let isLocked: Bool
    let onTap: () -> Void
    @ObservedObject private var lang = LanguageManager.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: vehicleIcon)
                        .foregroundStyle(.blue)
                        .font(.system(size: 18))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(lang.t(nb: "VALGT KJØRETØY", en: "SELECTED VEHICLE"))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    if let vehicle {
                        Text(nameAndReg(vehicle))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(tollClassShort(vehicle))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(lang.t(nb: "Trykk for å velge kjøretøy", en: "Tap to select vehicle"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if isLocked {
                    Text(lang.t(nb: "Låst", en: "Locked"))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray5))
                        .clipShape(Capsule())
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .background(colorScheme == .dark ? Color(.systemGray6) : .white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
    }

    private var vehicleIcon: String {
        guard let vehicle else { return "car.fill" }
        return vehicle.vehicleType == .largeCar ? "steeringwheel" : "car.fill"
    }

    private func nameAndReg(_ vehicle: UserVehicle) -> String {
        [vehicle.name, vehicle.registrationNumber]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private func tollClassShort(_ vehicle: UserVehicle) -> String {
        let tollClass = vehicle.vehicleType == .car
            ? lang.t(nb: "Takstgruppe 1", en: "Toll class 1")
            : lang.t(nb: "Takstgruppe 2", en: "Toll class 2")
        let fuel = vehicle.fuelType == .electric
            ? lang.t(nb: "Elektrisk", en: "Electric")
            : "Bensin/Diesel"
        return "\(tollClass) · \(fuel)"
    }
}

struct VehiclePickerSheet: View {
    @Binding var selectedVehicle: UserVehicle?
    let onConfirm: (UserVehicle) -> Void
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \UserVehicle.createdAt) private var vehicles: [UserVehicle]
    @ObservedObject private var lang = LanguageManager.shared
    @State private var pendingSelection: UserVehicle?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text(lang.t(
                    nb: "Kjøretøyet bestemmer riktig takstgruppe for bompasseringene.",
                    en: "The vehicle determines the correct toll class for passages."
                ))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 8)

                List {
                    ForEach(vehicles) { vehicle in
                        Button {
                            pendingSelection = vehicle
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.blue.opacity(0.12))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: vehicle.vehicleType == .largeCar ? "steeringwheel" : "car.fill")
                                        .foregroundStyle(.blue)
                                        .font(.system(size: 17))
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(vehicle.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text([vehicle.registrationNumber, fuelLabel(vehicle.fuelType)]
                                        .filter { !$0.isEmpty }
                                        .joined(separator: " · "))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(tollClassFull(vehicle.vehicleType))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if pendingSelection?.persistentModelID == vehicle.persistentModelID {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.blue)
                                        .font(.system(size: 20))
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.plain)

                if let pending = pendingSelection {
                    Button {
                        onConfirm(pending)
                        dismiss()
                    } label: {
                        Text(lang.t(nb: "Bruk \(pending.name)", en: "Use \(pending.name)"))
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle(lang.t(nb: "Velg kjøretøy", en: "Select vehicle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(lang.t(nb: "Avbryt", en: "Cancel")) { dismiss() }
                }
            }
        }
        .onAppear {
            pendingSelection = selectedVehicle
                ?? vehicles.first(where: { $0.isPrimary })
                ?? vehicles.first
        }
    }

    private func fuelLabel(_ fuelType: FuelType) -> String {
        fuelType == .electric ? lang.t(nb: "Elektrisk", en: "Electric") : "Bensin/Diesel"
    }

    private func tollClassFull(_ vehicleType: VehicleType) -> String {
        vehicleType == .car
            ? lang.t(nb: "Takstgruppe 1 — Personbil ≤ 3 500 kg", en: "Toll class 1 — Car ≤ 3,500 kg")
            : lang.t(nb: "Takstgruppe 2 — Tungbil > 3 500 kg", en: "Toll class 2 — Heavy vehicle > 3,500 kg")
    }
}
