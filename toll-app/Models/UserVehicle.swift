import Foundation
import SwiftData

enum CarOwnership: String, Codable, CaseIterable, Identifiable {
    case privateOwned
    case company
    var id: String { rawValue }
}

@Model
final class UserVehicle {
    var name: String
    var registrationNumber: String
    var vehicleTypeRaw: String
    var fuelTypeRaw: String
    var ownershipRaw: String
    var isPrimary: Bool
    var hasAutopass: Bool
    var createdAt: Date

    var vehicleType: VehicleType {
        VehicleType(rawValue: vehicleTypeRaw) ?? .car
    }

    var fuelType: FuelType {
        FuelType(rawValue: fuelTypeRaw) ?? .gas
    }

    var ownership: CarOwnership {
        CarOwnership(rawValue: ownershipRaw) ?? .privateOwned
    }

    init(
        name: String,
        registrationNumber: String = "",
        vehicleType: VehicleType = .car,
        fuelType: FuelType = .gas,
        ownership: CarOwnership = .privateOwned,
        isPrimary: Bool = false,
        hasAutopass: Bool = true
    ) {
        self.name = name
        self.registrationNumber = registrationNumber
        self.vehicleTypeRaw = vehicleType.rawValue
        self.fuelTypeRaw = fuelType.rawValue
        self.ownershipRaw = ownership.rawValue
        self.isPrimary = isPrimary
        self.hasAutopass = hasAutopass
        self.createdAt = Date()
    }
}
