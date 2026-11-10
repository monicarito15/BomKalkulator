import ActivityKit
import SwiftUI
import WidgetKit

struct WorkTripLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkTripActivityAttributes.self) { context in
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        Image(systemName: "car.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Kjøretur")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.1f km", context.state.distanceKm))
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.primary)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("\(context.state.tollCount) bom")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.0f kr", context.state.totalTollCost))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.primary)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Image(systemName: "timer")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        if context.state.tripState == "active" {
                            Text(context.state.timerStart, style: .timer)
                                .font(.system(size: 28, weight: .bold, design: .rounded).monospacedDigit())
                                .foregroundStyle(.primary)
                        } else {
                            Text(formatElapsed(context.state.elapsedSeconds))
                                .font(.system(size: 28, weight: .bold, design: .rounded).monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if context.state.tripState == "paused" {
                            Label("Pauset", systemImage: "pause.fill")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: "location.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.green)
            } compactTrailing: {
                if context.state.tripState == "active" {
                    Text(context.state.timerStart, style: .timer)
                        .font(.system(size: 12, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.white)
                        .frame(minWidth: 42)
                } else {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                }
            } minimal: {
                Image(systemName: "location.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.green)
            }
        }
    }
}

private func lockScreenView(context: ActivityViewContext<WorkTripActivityAttributes>) -> some View {
    HStack(alignment: .center, spacing: 14) {
        ZStack {
            Circle()
                .fill(.white.opacity(0.2))
                .frame(width: 46, height: 46)
            Image(systemName: "car.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
        }

        VStack(alignment: .leading, spacing: 3) {
            Text(context.state.tripState == "paused" ? "Kjøretur pauset" : "Kjøretur pågår")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.8))

            if context.state.tripState == "active" {
                Text(context.state.timerStart, style: .timer)
                    .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
            } else {
                Text(formatElapsed(context.state.elapsedSeconds))
                    .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.6))
            }

            HStack(spacing: 6) {
                Text(String(format: "%.1f km", context.state.distanceKm))
                Text("·")
                Text("\(context.state.tollCount) \(context.state.tollCount == 1 ? "bom" : "bom")")
                if context.state.totalTollCost > 0 {
                    Text("·")
                    Text(String(format: "%.0f kr", context.state.totalTollCost))
                }
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(.white.opacity(0.75))
        }

        Spacer()
    }
    .padding(16)
    .activityBackgroundTint(Color(red: 0.05, green: 0.55, blue: 0.25))
}

private func formatElapsed(_ seconds: Int) -> String {
    let h = seconds / 3600
    let m = (seconds % 3600) / 60
    let s = seconds % 60
    if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
    return String(format: "%d:%02d", m, s)
}
