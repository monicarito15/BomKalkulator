//
//  Vegobjekt.swift
//  toll-app
//
//  Created by Carolina Mera  on 12/09/2025.
//Data model for Vegobjekt API response

import Foundation
import CoreLocation
import ArcGIS
import SwiftData
 
@Model
class Vegobjekt: Identifiable {
    @Attribute(.unique)
    var id: Int
    var href: String
    @Relationship(deleteRule: .cascade)
    var egenskaper: [Egenskap]
    var lokasjon: Lokasjon?
    
    init(id: Int, href: String, egenskaper: [Egenskap], lokasjon: Lokasjon?) {
        self.id = id
        self.href = href
        self.egenskaper = egenskaper
        self.lokasjon = lokasjon
    }
    
    // Pricing from NVDB egenskaper
    var normalPriceCar: Double? {
        egenskaper.first(where: { $0.navn == "Takst liten bil" })
            .flatMap { Double($0.verdi ?? "") }
    }
    var rushPriceCar: Double? {
        egenskaper.first(where: { $0.navn == "Rushtidstakst liten bil" })
            .flatMap { Double($0.verdi ?? "") }
    }
    var normalPriceLargeCar: Double? {
        egenskaper.first(where: { $0.navn == "Takst stor bil" })
            .flatMap { Double($0.verdi ?? "") }
    }
    var rushPriceLargeCar: Double? {
        egenskaper.first(where: { $0.navn == "Rushtidstakst stor bil" })
            .flatMap { Double($0.verdi ?? "") }
    }

      var hasRushHourPricing: Bool {
          egenskaper.first(where: { $0.navn == "Tidsdifferensiert takst" })?.verdi == "Ja"
      }
    var stationName: String {
        egenskaper.first(where: { $0.navn == "Navn bomstasjon"})?.verdi ?? "No name toll"
    }
                                                                                                                                                                                                             
    var isOutdatedNVDBStation: Bool {
        return false
    }

    var timesregel: String? {
        egenskaper.first(where: { $0.navn == "Timesregel" })?.verdi
    }

    var timesregelVarighet: Int {
        egenskaper.first(where: { $0.navn == "Timesregel, varighet" })
            .flatMap { Int($0.verdi ?? "") } ?? 60
    }

    var timesregelGruppe: Int? {
        egenskaper.first(where: { $0.navn == "Timesregel, passeringsgruppe" })
            .flatMap { Int($0.verdi ?? "") }
    }

    private func rushMinutes(fraKey: String, tilKey: String) -> (start: Int, end: Int)? {
        let fra = egenskaper.first(where: { $0.navn == fraKey })?.verdi
        let til = egenskaper.first(where: { $0.navn == tilKey })?.verdi
        guard let f = parseTimeToMinutes(fra), let t = parseTimeToMinutes(til) else { return nil }
        return (f, t)
    }

    private func parseTimeToMinutes(_ time: String?) -> Int? {
        guard let time else { return nil }
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count >= 2 else { return nil }
        return parts[0] * 60 + parts[1]
    }

    func isRushHour(at date: Date) -> Bool {
        guard hasRushHourPricing else { return false }
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        guard weekday >= 2 && weekday <= 6 else { return false }

        let h = calendar.component(.hour, from: date)
        let m = calendar.component(.minute, from: date)
        let total = h * 60 + m

        let morning   = rushMinutes(fraKey: "Rushtid morgen, fra",      tilKey: "Rushtid morgen, til")
                     ?? (start: 6*60+30, end: 9*60)
        let afternoon = rushMinutes(fraKey: "Rushtid ettermiddag, fra", tilKey: "Rushtid ettermiddag, til")
                     ?? (start: 15*60,   end: 17*60)

        return (total >= morning.start   && total < morning.end) ||
               (total >= afternoon.start && total < afternoon.end)
    }

    // EV multiplier per operator (what fraction of normal price EV pays).
    // Norwegian law minimum: EV pays at most 70% (30% discount).
    // Source: NVDB API + elvio.no, verified Oct 2026.
    var evMultiplier: Double {
        guard let verdi = egenskaper.first(where: { $0.navn == "Operatør_Id" })?.verdi,
              let opId = Int(verdi) else { return 0.5 }
        switch opId {
        case 100140:                    // Fjellinjen AS — Oslo/Bærum
            return 0.30
        case 100126:                    // Ferde AS — Bomringen Bergen
            return 0.30
        case 100014:                    // Ferde AS — Bymiljøpakken Nord Jæren (Stavanger)
            return 0.30
        case 100107, 100120, 100122, 100124: // Vegamot AS — Trondheim + branches
            return 0.70
        default:
            return 0.50
        }
    }

    func price(vehicle: VehicleType, fuel: FuelType, date: Date) -> Double? {
        let isRush = isRushHour(at: date)

        var basePrice: Double
        switch vehicle {
        case .largeCar:
            guard let base = normalPriceLargeCar else { return nil }
            basePrice = isRush ? (rushPriceLargeCar ?? base) : base
        case .car:
            guard let base = normalPriceCar else { return nil }
            basePrice = isRush ? (rushPriceCar ?? base) : base
        }

        // Trondheim operators with outdated NVDB prices (not updated since Feb 2024)
        if isOutdatedNVDBStation {
            basePrice *= 1.12
        }

        switch fuel {
        case .electric:
            return basePrice * evMultiplier
        default:
            return basePrice
        }
    }
}

