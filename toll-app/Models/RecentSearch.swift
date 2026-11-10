//
//  RecentSaerch.swift
//  toll-app
//
//  Created by Carolina Mera  on 21/10/2025.
//

import Foundation
import SwiftData

enum VehicleType: String, Codable, CaseIterable, Identifiable {
    case car
    var id: String {rawValue}
}

enum FuelType: String, Codable, CaseIterable, Identifiable {
    case electric
    case diesel
    case gas
    var id: String {rawValue}
}

@Model
final class RecentSearch {
    var name: String
    var address: String
    var createdAt: Date
    var vehicleType: VehicleType?
    var fuelType: FuelType?
    
    init(name: String, address: String,createdAt: Date = Date(),vehicleType: VehicleType = .car, fuelType: FuelType = .gas) {
        self.name = name
        self.address = address
        self.createdAt = createdAt
        self.vehicleType = vehicleType
        self.fuelType = fuelType
    }
    
}




