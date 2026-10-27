import CoreLocation
import CoreData

@MainActor
final class SafeZoneMonitor: ObservableObject {
    enum Status: Equatable { case noZone, unknown, inside, outside }

    @Published private(set) var status: Status = .noZone
    @Published private(set) var zoneName: String?
    @Published private(set) var zoneCenter: CLLocationCoordinate2D?
    @Published private(set) var zoneRadius: Double = 0
    @Published private(set) var distanceFromCenter: Double?

    /// Fired only when the user really crosses the boundary (never for the first reading).
    var onTransition: ((Status, String) -> Void)?

    private var region: CLCircularRegion?
    private var pendingState: Status?
    private var pendingCount = 0

    private let confirmations = 2          // consecutive fixes needed to confirm a crossing
    private let maxAccuracy: CLLocationAccuracy = 50

    /// Loads the user's active zone from Core Data.
    func reload(ownerID: UUID?, context: NSManagedObjectContext) {
        pendingState = nil
        pendingCount = 0
        distanceFromCenter = nil

        if let zone = SafeZoneStore.activeZone(ownerID: ownerID, in: context) {
            let center = CLLocationCoordinate2D(latitude: zone.centerLatitude, longitude: zone.centerLongitude)
            region = CLCircularRegion(center: center, radius: zone.radiusMeters,
                                      identifier: zone.id?.uuidString ?? "safe-zone")
            zoneName = zone.name ?? "Safe zone"
            zoneCenter = center
            zoneRadius = zone.radiusMeters
            status = .unknown
        } else {
            region = nil
            zoneName = nil
            zoneCenter = nil
            zoneRadius = 0
            status = .noZone
        }
    }

    /// Call when a trail starts or resumes so the first fix becomes the new baseline.
    func reset() {
        pendingState = nil
        pendingCount = 0
        distanceFromCenter = nil
        if region != nil { status = .unknown }
    }

    func process(_ fixes: [CLLocation]) {
        guard let region else { return }
        let center = CLLocation(latitude: region.center.latitude, longitude: region.center.longitude)

        for fix in fixes where fix.horizontalAccuracy >= 0 && fix.horizontalAccuracy <= maxAccuracy {
            distanceFromCenter = fix.distance(from: center)
            apply(region.contains(fix.coordinate) ? .inside : .outside)
        }
    }

    private func apply(_ observed: Status) {
        if status == .unknown {
            status = observed           // first reading: set baseline, no alert
            return
        }
        if observed == status {
            pendingState = nil
            pendingCount = 0
            return
        }
        if pendingState == observed {
            pendingCount += 1
        } else {
            pendingState = observed
            pendingCount = 1
        }
        if pendingCount >= confirmations {
            status = observed
            pendingState = nil
            pendingCount = 0
            onTransition?(observed, zoneName ?? "Safe zone")
        }
    }
}
