import Foundation
import CoreLocation
import Combine

@MainActor
final class WeatherService: ObservableObject {
    @Published private(set) var snapshot: WeatherSnapshot?
    @Published private(set) var isLoading = false
    @Published private(set) var isOfflineCopy = false
    @Published private(set) var errorMessage: String?

    var assessment: WeatherAssessment? { snapshot.map { WeatherHazard.assess($0) } }

    private static let cacheKey = "weather.cache.v1"

    private let client: OpenMeteoClient
    private let location: LocationService
    private let recorder: TrailRecorder
    private let notifications: NotificationService
    private let settings: SafetySettings
    private let defaults: UserDefaults

    private var timer: Timer?
    private var lastAlert: (level: WeatherAssessment.Level, date: Date)?
    private var cancellables = Set<AnyCancellable>()

    init(
        location: LocationService,
        recorder: TrailRecorder,
        notifications: NotificationService,
        settings: SafetySettings,
        client: OpenMeteoClient = OpenMeteoClient(),
        defaults: UserDefaults = .standard
    ) {
        self.location = location
        self.recorder = recorder
        self.notifications = notifications
        self.settings = settings
        self.client = client
        self.defaults = defaults

        if let data = defaults.data(forKey: Self.cacheKey),
           let cached = try? JSONDecoder().decode(WeatherSnapshot.self, from: data) {
            snapshot = cached
            isOfflineCopy = true
        }

        // The first GPS fix triggers the first forecast.
        location.$lastLocation
            .compactMap { $0 }
            .first()
            .sink { [weak self] fix in
                guard let self else { return }
                Task { await self.refresh(force: false, at: fix) }
            }
            .store(in: &cancellables)

        // While a trail is recording, refresh every 20 minutes.
        recorder.$state
            .removeDuplicates()
            .sink { [weak self] state in self?.recordingChanged(state) }
            .store(in: &cancellables)
    }

    // MARK: Public

    func refreshIfNeeded() { Task { await refresh(force: false) } }
    func refreshNow() { Task { await refresh(force: true) } }

    // MARK: Fetching

    private func refresh(force: Bool, at fix: CLLocation? = nil) async {
        guard let fix = fix ?? location.lastLocation else {
            location.requestSingleLocation()
            if snapshot == nil { errorMessage = "Waiting for your location…" }
            return
        }

        if !force, let current = snapshot, !isOfflineCopy,
           Date().timeIntervalSince(current.fetchedAt) < 15 * 60,
           CLLocation(latitude: current.latitude, longitude: current.longitude).distance(from: fix) < 5000 {
            return
        }
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let fresh = try await client.fetch(latitude: fix.coordinate.latitude,
                                               longitude: fix.coordinate.longitude)
            snapshot = fresh
            isOfflineCopy = false
            if let data = try? JSONEncoder().encode(fresh) { defaults.set(data, forKey: Self.cacheKey) }
            maybeAlert(for: fresh)
        } catch {
            if snapshot != nil {
                isOfflineCopy = true
                errorMessage = "Offline. Showing the last saved forecast."
            } else {
                errorMessage = "Couldn't load the weather. Check your connection."
            }
        }
    }

    private func recordingChanged(_ state: TrailRecorder.State) {
        timer?.invalidate()
        timer = nil
        guard state == .recording else { return }

        refreshIfNeeded()
        timer = Timer.scheduledTimer(withTimeInterval: 20 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshNow() }
        }
    }

    // MARK: Alerts

    private func maybeAlert(for snapshot: WeatherSnapshot) {
        guard settings.weatherAlertsEnabled else { return }
        let assessment = WeatherHazard.assess(snapshot)
        guard assessment.level >= .warning else { return }

        // Don't repeat the same warning more than once every 3 hours (unless it got worse).
        if let last = lastAlert,
           assessment.level <= last.level,
           Date().timeIntervalSince(last.date) < 3 * 3600 {
            return
        }
        lastAlert = (assessment.level, Date())
        notifications.post(
            title: assessment.title,
            body: "\(assessment.reasons.first ?? "Hazardous conditions"). \(assessment.tip)"
        )
    }
}
