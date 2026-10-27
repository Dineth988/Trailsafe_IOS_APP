import Foundation

@MainActor
final class SafetySettings: ObservableObject {
    private enum Keys {
        static let zoneAlerts = "zoneAlertsEnabled"
        static let stationaryAlerts = "stationaryAlertsEnabled"
        static let stationaryMinutes = "stationaryMinutes"
        static let sessionComplete = "sessionCompleteAlertsEnabled"
        static let checkInEnabled = "dailyCheckInEnabled"
        static let checkInMinutes = "checkInMinutes"
    }

    private let defaults: UserDefaults

    @Published var zoneAlertsEnabled: Bool {
        didSet { defaults.set(zoneAlertsEnabled, forKey: Keys.zoneAlerts) }
    }
    @Published var stationaryAlertsEnabled: Bool {
        didSet { defaults.set(stationaryAlertsEnabled, forKey: Keys.stationaryAlerts) }
    }
    @Published var stationaryMinutes: Int {
        didSet { defaults.set(stationaryMinutes, forKey: Keys.stationaryMinutes) }
    }
    @Published var sessionCompleteAlertsEnabled: Bool {
        didSet { defaults.set(sessionCompleteAlertsEnabled, forKey: Keys.sessionComplete) }
    }
    @Published var dailyCheckInEnabled: Bool {
        didSet { defaults.set(dailyCheckInEnabled, forKey: Keys.checkInEnabled) }
    }
    /// Minutes after midnight (default 20:00).
    @Published var checkInMinutes: Int {
        didSet { defaults.set(checkInMinutes, forKey: Keys.checkInMinutes) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        zoneAlertsEnabled = defaults.object(forKey: Keys.zoneAlerts) as? Bool ?? true
        stationaryAlertsEnabled = defaults.object(forKey: Keys.stationaryAlerts) as? Bool ?? true
        stationaryMinutes = defaults.object(forKey: Keys.stationaryMinutes) as? Int ?? 10
        sessionCompleteAlertsEnabled = defaults.object(forKey: Keys.sessionComplete) as? Bool ?? true
        dailyCheckInEnabled = defaults.object(forKey: Keys.checkInEnabled) as? Bool ?? false
        checkInMinutes = defaults.object(forKey: Keys.checkInMinutes) as? Int ?? 20 * 60
    }

    /// Bridges the stored minutes to a Date for DatePicker.
    var checkInTime: Date {
        get {
            Calendar.current.date(bySettingHour: checkInMinutes / 60, minute: checkInMinutes % 60,
                                  second: 0, of: Date()) ?? Date()
        }
        set {
            let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            checkInMinutes = (parts.hour ?? 20) * 60 + (parts.minute ?? 0)
        }
    }
}
