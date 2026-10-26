import CoreLocation
import MapKit

enum RouteBuilder {
    static func sortedPoints(of session: TrailSession) -> [LocationPoint] {
        let set = (session.points as? Set<LocationPoint>) ?? []
        return set.sorted { ($0.timestamp ?? .distantPast) < ($1.timestamp ?? .distantPast) }
    }

    /// Splits a route where the user clearly jumped (paused, then moved a long way).
    static func segments(
        from points: [LocationPoint],
        gapSeconds: TimeInterval = 60,
        gapMeters: CLLocationDistance = 100
    ) -> [[CLLocationCoordinate2D]] {
        var result: [[CLLocationCoordinate2D]] = []
        var current: [CLLocationCoordinate2D] = []
        var previous: LocationPoint?

        for point in points {
            let coordinate = CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)
            if let previous,
               let t1 = previous.timestamp, let t2 = point.timestamp,
               t2.timeIntervalSince(t1) > gapSeconds {
                let a = CLLocation(latitude: previous.latitude, longitude: previous.longitude)
                let b = CLLocation(latitude: point.latitude, longitude: point.longitude)
                if a.distance(from: b) > gapMeters, !current.isEmpty {
                    result.append(current)
                    current = []
                }
            }
            current.append(coordinate)
            previous = point
        }
        if !current.isEmpty { result.append(current) }
        return result
    }

    static func boundingRect(for segments: [[CLLocationCoordinate2D]]) -> MKMapRect? {
        let coordinates = segments.flatMap { $0 }
        guard !coordinates.isEmpty else { return nil }
        var rect = MKMapRect.null
        for coordinate in coordinates {
            let p = MKMapPoint(coordinate)
            rect = rect.union(MKMapRect(x: p.x, y: p.y, width: 0, height: 0))
        }
        let padding = max(max(rect.width, rect.height) * 0.3, 1000)
        return rect.insetBy(dx: -padding, dy: -padding)
    }
}
