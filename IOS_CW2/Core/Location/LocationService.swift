import CoreLocation
import Combine

@MainActor
final class LocationService: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published private(set) var isUpdating = false
    @Published private(set) var lastLocation: CLLocation?

    /// Broadcasts every batch of fixes to any number of listeners.
    let locationUpdates = PassthroughSubject<[CLLocation], Never>()

    /// Used by TrailRecorder (kept from Day 2).
    var onLocations: (@MainActor ([CLLocation]) -> Void)?

    private let manager = CLLocationManager()
    private var didRequestAlways = false
    private var consumers = Set<String>()

    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    var isDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 10
        manager.activityType = .fitness
        manager.pausesLocationUpdatesAutomatically = false
        authorizationStatus = manager.authorizationStatus
    }

    // MARK: Permissions

    func requestPermissionIfNeeded() {
        if authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }

    func requestAlwaysUpgradeIfNeeded() {
        guard authorizationStatus == .authorizedWhenInUse, !didRequestAlways else { return }
        didRequestAlways = true
        manager.requestAlwaysAuthorization()
    }

    // MARK: Tracking

    func startTracking(for consumer: String = "trail") {
        consumers.insert(consumer)
        guard isAuthorized else {
            requestPermissionIfNeeded()     // tracking begins once permission is granted
            return
        }
        beginUpdatesIfNeeded()
    }

    func stopTracking(for consumer: String = "trail") {
        consumers.remove(consumer)
        guard consumers.isEmpty else { return }    // someone else still needs GPS
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
        manager.showsBackgroundLocationIndicator = false
        isUpdating = false
    }
    
    private func beginUpdatesIfNeeded() {
        guard !isUpdating else { return }
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        manager.startUpdatingLocation()
        isUpdating = true
    }

    /// One-off fix (used by the safe zone screen and SOS). Does nothing without permission.
    func requestSingleLocation() {
        guard isAuthorized else { return }
        manager.requestLocation()
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            if self.isAuthorized, !self.consumers.isEmpty { self.beginUpdatesIfNeeded() }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            self.lastLocation = locations.last
            self.locationUpdates.send(locations)
            self.onLocations?(locations)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
}
