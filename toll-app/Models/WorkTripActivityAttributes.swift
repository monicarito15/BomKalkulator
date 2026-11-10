import ActivityKit
import Foundation

struct WorkTripActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var tripState: String    // "active" | "paused"
        var timerStart: Date     // adjusted Date so Text(.timer) shows correct elapsed
        var elapsedSeconds: Int  // snapshot used when paused
        var tollCount: Int
        var totalTollCost: Double
    }
    var driverName: String
}
