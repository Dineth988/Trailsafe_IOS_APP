import CoreLocation
import Combine

@MainActor
final class LocationService: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published private(set) var isUpdating = false

    /// Called on the main actor with each batch of new locations.
    var onLocations: (@MainActor ([CLLocation]) -> Void)?

    private let manager = CLLocationManager()
    private var didRequestAlways = false

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
        manager.distanceFilter = 10                  // metres between updates (saves battery)
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

    /// iOS only shows the "Always" upgrade prompt once, so we ask a single time.
    func requestAlwaysUpgradeIfNeeded() {
        guard authorizationStatus == .authorizedWhenInUse, !didRequestAlways else { return }
        didRequestAlways = true
        manager.requestAlwaysAuthorization()
    }

    // MARK: Tracking

    func startTracking() {
        guard isAuthorized else {
            requestPermissionIfNeeded()
            return
        }
        manager.allowsBackgroundLocationUpdates = true      // needs Background Modes → Location updates
        manager.showsBackgroundLocationIndicator = true
        manager.startUpdatingLocation()
        isUpdating = true
    }

    func stopTracking() {
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
        manager.showsBackgroundLocationIndicator = false
        isUpdating = false
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in self.authorizationStatus = status }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in self.onLocations?(locations) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
}
