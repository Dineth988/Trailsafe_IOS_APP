import UserNotifications

@MainActor
final class NotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let center = UNUserNotificationCenter.current()
    private let checkInID = "daily-checkin"

    override init() {
        super.init()
        center.delegate = self
        Task { await refreshStatus() }
    }

    var isAllowed: Bool {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral: return true
        default: return false
        }
    }

    func refreshStatus() async {
        authorizationStatus = await center.notificationSettings().authorizationStatus
    }

    @discardableResult
    func requestAuthorizationIfNeeded() async -> Bool {
        await refreshStatus()
        if authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
            await refreshStatus()
        }
        return isAllowed
    }

    /// Shows a notification immediately.
    func post(title: String, body: String, id: String = UUID().uuidString) {
        guard isAllowed else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        Task { try? await center.add(request) }
    }

    // MARK: Daily check-in

    func scheduleDailyCheckIn(hour: Int, minute: Int) {
        cancelDailyCheckIn()
        let content = UNMutableNotificationContent()
        content.title = "Daily check-in"
        content.body = "Time to check in. Open TrailSafe and make sure your safety settings are ready."
        content.sound = .default

        var parts = DateComponents()
        parts.hour = hour
        parts.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: true)
        let request = UNNotificationRequest(identifier: checkInID, content: content, trigger: trigger)
        Task { try? await center.add(request) }
    }

    func cancelDailyCheckIn() {
        center.removePendingNotificationRequests(withIdentifiers: [checkInID])
    }

    // MARK: UNUserNotificationCenterDelegate

    /// Without this, iOS hides notifications while the app is open.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
