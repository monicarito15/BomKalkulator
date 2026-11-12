import ActivityKit
import Foundation

struct WorkTripActivityAttributes: ActivityAttributes, Sendable {
    struct ContentState: Codable, Hashable {
        var tripState: String
        var timerStart: Date
        var elapsedSeconds: Int
        var distanceKm: Double
        var tollCount: Int
        var totalTollCost: Double

        init(tripState: String, timerStart: Date, elapsedSeconds: Int,
             distanceKm: Double, tollCount: Int, totalTollCost: Double) {
            self.tripState = tripState
            self.timerStart = timerStart
            self.elapsedSeconds = elapsedSeconds
            self.distanceKm = distanceKm
            self.tollCount = tollCount
            self.totalTollCost = totalTollCost
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            tripState = try c.decode(String.self, forKey: .tripState)
            timerStart = try c.decode(Date.self, forKey: .timerStart)
            elapsedSeconds = try c.decode(Int.self, forKey: .elapsedSeconds)
            distanceKm = try c.decodeIfPresent(Double.self, forKey: .distanceKm) ?? 0.0
            tollCount = try c.decode(Int.self, forKey: .tollCount)
            totalTollCost = try c.decode(Double.self, forKey: .totalTollCost)
        }
    }
    var driverName: String
}
