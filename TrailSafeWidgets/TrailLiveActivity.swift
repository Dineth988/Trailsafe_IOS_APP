import ActivityKit
import WidgetKit
import SwiftUI

// MARK: Formatting helpers (shared with the Home Screen widget)

func wDistance(_ meters: Double) -> String {
    meters < 1000
        ? "\(Int(meters.rounded())) m"
        : String(format: "%.2f km", meters / 1000)
}

func wDuration(_ seconds: Double) -> String {
    let total = Int(max(seconds, 0))
    let h = total / 3600, m = (total % 3600) / 60, s = total % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
}

/// A ticking timer while recording, a frozen time while paused.
struct ElapsedLabel: View {
    let isPaused: Bool
    let elapsed: Double
    let timerStart: Date
    var alignment: Alignment = .leading

    var body: some View {
        Group {
            if isPaused {
                Text(wDuration(elapsed))
            } else {
                Text(timerInterval: timerStart...Date.distantFuture, countsDown: false)
            }
        }
        .monospacedDigit()
        .frame(maxWidth: 100, alignment: alignment)
    }
}

// MARK: Live Activity

struct TrailLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TrailActivityAttributes.self) { context in
            LockScreenView(state: context.state)
                .activityBackgroundTint(Color(red: 0.176, green: 0.353, blue: 0.239))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Distance").font(.caption2).foregroundStyle(.secondary)
                        Text(wDistance(context.state.distanceMeters))
                            .font(.title3.weight(.bold))
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Time").font(.caption2).foregroundStyle(.secondary)
                        ElapsedLabel(isPaused: context.state.isPaused,
                                     elapsed: context.state.elapsedSeconds,
                                     timerStart: context.state.timerStart,
                                     alignment: .trailing)
                            .font(.title3.weight(.bold))
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Label(context.state.isPaused ? "Trail paused" : "Recording your trail",
                          systemImage: context.state.isPaused ? "pause.circle.fill" : "record.circle")
                        .font(.footnote)
                        .foregroundStyle(context.state.isPaused ? .orange : .green)
                }
            } compactLeading: {
                Image(systemName: context.state.isPaused ? "pause.fill" : "figure.hiking")
                    .foregroundStyle(.green)
            } compactTrailing: {
                Text(wDistance(context.state.distanceMeters)).font(.caption2.weight(.semibold))
            } minimal: {
                Image(systemName: "figure.hiking").foregroundStyle(.green)
            }
        }
    }
}

private struct LockScreenView: View {
    let state: TrailActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: state.isPaused ? "pause.circle.fill" : "figure.hiking")
                .font(.system(size: 34))
                .foregroundStyle(state.isPaused ? .orange : .white)

            VStack(alignment: .leading, spacing: 2) {
                Text(state.isPaused ? "Trail paused" : "Trail in progress")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                Text(wDistance(state.distanceMeters))
                    .font(.system(.title, design: .rounded, weight: .bold))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Time").font(.caption).foregroundStyle(.white.opacity(0.8))
                ElapsedLabel(isPaused: state.isPaused, elapsed: state.elapsedSeconds,
                             timerStart: state.timerStart, alignment: .trailing)
                    .font(.system(.title2, design: .rounded, weight: .bold))
            }
        }
        .foregroundStyle(.white)
        .padding()
    }
}
