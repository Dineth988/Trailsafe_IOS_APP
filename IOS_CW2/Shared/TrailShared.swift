import Foundation
import ActivityKit

/// Used only by the Home Screen widget. Must match the App Group you add under
/// Signing & Capabilities on BOTH targets (see the widget commit).
enum AppGroup {
    static let id = "group.com.yourname.trailsafe"
    static let snapshotKey = "widget.snapshot"
    static var defaults: UserDefaults? { UserDefaults(suiteName: id) }
}

// MARK: Live Activity

struct TrailActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var distanceMeters: Double
        var elapsedSeconds: Double
        var isPaused: Bool
        /// "Now minus elapsed", so the system can run a live timer without updates every second.
        var timerStart: Date
    }

    var startedAt: Date
}

// MARK: Home Screen widget data

enum SharedTrailState: String, Codable {
    case idle, recording, paused
}

struct WidgetSnapshot: Codable, Equatable {
    var state: SharedTrailState = .idle
    var distanceMeters: Double = 0
    var elapsedSeconds: Double = 0
    var timerStart: Date = Date()
    var weekDistanceMeters: Double = 0
    var weekTrails: Int = 0
    var liveShareActive: Bool = false
    var updatedAt: Date = Date()

    static let sample = WidgetSnapshot(
        state: .recording, distanceMeters: 2340, elapsedSeconds: 1260,
        timerStart: Date().addingTimeInterval(-1260),
        weekDistanceMeters: 18400, weekTrails: 4, liveShareActive: true
    )

    static func load() -> WidgetSnapshot {
        guard
            let data = AppGroup.defaults?.data(forKey: AppGroup.snapshotKey),
            let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
        else { return WidgetSnapshot() }
        return snapshot
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            AppGroup.defaults?.set(data, forKey: AppGroup.snapshotKey)
        }
    }
}
