import SwiftData
import Foundation

enum TripStatus: String, Codable {
    case active
    case paused
    case completed
}

struct TollPassage: Codable, Identifiable {
    var id: UUID = UUID()
    var stationName: String
    var price: Double
    var passedAt: Date
}

@Model
final class WorkTrip {
    var id: UUID
    var driverName: String
    var company: String
    var startTime: Date
    var endTime: Date?
    var distanceKm: Double
    var totalTollCost: Double
    var passagesJSON: Data
    var statusRaw: String

    init(driverName: String, company: String) {
        self.id = UUID()
        self.driverName = driverName
        self.company = company
        self.startTime = Date()
        self.endTime = nil
        self.distanceKm = 0.0
        self.totalTollCost = 0.0
        self.passagesJSON = Data()
        self.statusRaw = TripStatus.active.rawValue
    }

    var status: TripStatus {
        get { TripStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    var passages: [TollPassage] {
        get { (try? JSONDecoder().decode([TollPassage].self, from: passagesJSON)) ?? [] }
        set { passagesJSON = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var duration: TimeInterval {
        (endTime ?? Date()).timeIntervalSince(startTime)
    }

    var formattedDuration: String {
        let total = Int(duration)
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 { return "\(h) h \(m) min" }
        return "\(m) min"
    }

    var weekLabel: String {
        let calendar = Calendar.current
        let week = calendar.component(.weekOfYear, from: startTime)
        let year = calendar.component(.year, from: startTime)
        return "Week \(week), \(year)"
    }
}
