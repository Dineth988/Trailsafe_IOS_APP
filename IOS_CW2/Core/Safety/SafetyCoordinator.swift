import CoreLocation
import Combine

/// Connects location fixes and recorder state to safety alerts.
@MainActor
final class SafetyCoordinator: ObservableObject {
    private let location: LocationService
    private let recorder: TrailRecorder
    private let zones: SafeZoneMonitor
    private let notifications: NotificationService
    private let settings: SafetySettings

    private var detector = StationaryDetector()
    private var nextStationaryAlert = Date.distantPast
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()

    init(
        location: LocationService,
        recorder: TrailRecorder,
        zones: SafeZoneMonitor,
        notifications: NotificationService,
        settings: SafetySettings
    ) {
        self.location = location
        self.recorder = recorder
        self.zones = zones
        self.notifications = notifications
        self.settings = settings

        location.locationUpdates
            .sink { [weak self] fixes in self?.handle(fixes) }
            .store(in: &cancellables)

        recorder.$state
            .sink { [weak self] state in self?.recordingStateChanged(state) }
            .store(in: &cancellables)

        recorder.$completedSession
            .compactMap { $0 }
            .sink { [weak self] session in self?.sessionCompleted(session) }
            .store(in: &cancellables)

        zones.onTransition = { [weak self] status, name in
            self?.zoneTransition(status, name: name)
        }
    }

    // MARK: Location

    private func handle(_ fixes: [CLLocation]) {
        guard recorder.state == .recording else { return }
        zones.process(fixes)
        for fix in fixes { detector.record(fix) }
    }

    // MARK: Recorder state

    private func recordingStateChanged(_ state: TrailRecorder.State) {
        if state == .recording {
            detector.reset()
            zones.reset()
            nextStationaryAlert = .distantPast
            startTimer()
        } else {
            stopTimer()
        }
    }

    private func startTimer() {
        stopTimer()
        // GPS stops sending updates when you stand still, so a timer does the checking.
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkStationary() }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: Alerts

    private func checkStationary() {
        guard recorder.state == .recording, settings.stationaryAlertsEnabled else { return }
        let limit = TimeInterval(settings.stationaryMinutes * 60)
        let stationary = detector.stationaryDuration()
        guard stationary >= limit, Date() >= nextStationaryAlert else { return }

        nextStationaryAlert = Date().addingTimeInterval(limit)   // don't repeat until another full interval
        let minutes = max(Int(stationary / 60), 1)
        notifications.post(
            title: "Are you okay?",
            body: "You haven't moved for \(minutes) minute\(minutes == 1 ? "" : "s"). Open TrailSafe if you need help."
        )
    }

    private func zoneTransition(_ status: SafeZoneMonitor.Status, name: String) {
        guard settings.zoneAlertsEnabled else { return }
        switch status {
        case .outside:
            notifications.post(title: "You left your safe zone",
                               body: "You're now outside \"\(name)\". Stay safe.")
        case .inside:
            notifications.post(title: "Back in your safe zone",
                               body: "You're inside \"\(name)\" again.")
        default:
            break
        }
    }

    private func sessionCompleted(_ session: TrailSession) {
        guard settings.sessionCompleteAlertsEnabled else { return }
        notifications.post(
            title: "Trail complete",
            body: "\(Fmt.distance(session.distanceMeters)) in \(Fmt.duration(session.durationSeconds)). Nice work!"
        )
    }
}
