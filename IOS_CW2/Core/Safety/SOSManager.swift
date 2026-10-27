import CoreLocation
import UIKit

struct SOSEvent {
    let date: Date
    let coordinate: CLLocationCoordinate2D?
}

@MainActor
final class SOSManager: ObservableObject {
    enum Phase: Equatable { case idle, countdown(Int), triggered }

    static let countdownSeconds = 5

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var lastEvent: SOSEvent?

    /// Day 4 hook: send the SOS to Live Share and trusted contacts.
    var onTriggered: ((SOSEvent) -> Void)?

    private let location: LocationService
    private let notifications: NotificationService
    private var timer: Timer?

    init(location: LocationService, notifications: NotificationService) {
        self.location = location
        self.notifications = notifications
    }

    func begin() {
        guard phase == .idle else { return }
        location.requestSingleLocation()               // refresh the fix while counting down
        phase = .countdown(Self.countdownSeconds)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        startTimer()
    }

    func cancel() {
        stopTimer()
        phase = .idle
    }

    func triggerNow() {
        guard phase != .triggered else { return }
        fire()
    }

    /// "I'm safe": closes the triggered screen.
    func acknowledge() {
        stopTimer()
        phase = .idle
    }

    // MARK: Internals

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard case .countdown(let remaining) = phase else { return }
        if remaining <= 1 {
            fire()
        } else {
            phase = .countdown(remaining - 1)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    private func fire() {
        stopTimer()
        let event = SOSEvent(date: Date(), coordinate: location.lastLocation?.coordinate)
        lastEvent = event
        phase = .triggered
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        notifications.post(
            title: "SOS triggered",
            body: "Your SOS was triggered at \(event.date.formatted(date: .omitted, time: .shortened))."
        )
        onTriggered?(event)
    }
}
