import ActivityKit
import SwiftUI
import WidgetKit

struct WorkTripLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkTripActivityAttributes.self) { context in
            HStack {
                Text("Kjøretur")
                    .foregroundStyle(.white)
                    .font(.headline)
                Spacer()
                Text("\(context.state.tollCount) bom")
                    .foregroundStyle(.white)
                    .font(.headline)
            }
            .padding()
            .activityBackgroundTint(.green)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Kjøretur aktiv")
                        .foregroundStyle(.white)
                }
            } compactLeading: {
                Image(systemName: "car.fill")
                    .foregroundStyle(.green)
            } compactTrailing: {
                Text("\(context.state.tollCount)")
                    .foregroundStyle(.white)
                    .font(.caption2.weight(.semibold))
            } minimal: {
                Image(systemName: "car.fill")
                    .foregroundStyle(.green)
            }
        }
    }
}
