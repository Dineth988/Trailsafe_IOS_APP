import CoreLocation

/// Pure logic (easy to test): tracks how long the user has stayed within a small area.
struct StationaryDetector {
    var movementThreshold: CLLocationDistance = 30
    private(set) var anchor: CLLocation?
    private(set) var anchorTime = Date()

    mutating func reset(at date: Date = Date()) {
        anchor = nil
        anchorTime = date
    }

    mutating func record(_ location: CLLocation, at date: Date = Date()) {
        guard location.horizontalAccuracy >= 0, location.horizontalAccuracy <= 65 else { return }
        guard let anchor else {
            self.anchor = location
            anchorTime = date
            return
        }
        if location.distance(from: anchor) > movementThreshold {
            self.anchor = location
            anchorTime = date
        }
    }

    func stationaryDuration(at date: Date = Date()) -> TimeInterval {
        date.timeIntervalSince(anchorTime)
    }
}
