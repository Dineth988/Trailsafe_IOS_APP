import CoreLocation
import CoreData

struct TrackedZone: Identifiable {
    let id: UUID
    let name: String
    let center: CLLocationCoordinate2D
    let radius: Double
    var state: SafeZoneMonitor.Status = .unknown
}

@MainActor
final class SafeZoneMonitor: ObservableObject {
    /// Used both for one zone's state and for the overall status (`.noZone` only applies overall).
    enum Status: Equatable { case noZone, unknown, inside, outside }

    @Published private(set) var zones: [TrackedZone] = []
    @Published private(set) var status: Status = .noZone
    @Published private(set) var currentZoneName: String?

    /// Fired only when the user really crosses a boundary (never for the first reading).
    var onTransition: ((Status, String) -> Void)?

    private var regions: [UUID: CLCircularRegion] = [:]
    private var pending: [UUID: (state: Status, count: Int)] = [:]

    private let confirmations = 2          // consecutive fixes needed to confirm a crossing
    private let maxAccuracy: CLLocationAccuracy = 50

    /// Loads the user's active zones from Core Data.
    func reload(ownerID: UUID?, context: NSManagedObjectContext) {
        pending.removeAll()
        regions.removeAll()

        var tracked: [TrackedZone] = []
        for zone in SafeZoneStore.activeZones(ownerID: ownerID, in: context) {
            guard let id = zone.id else { continue }
            regions[id] = CLCircularRegion(center: zone.coordinate, radius: zone.radiusMeters,
                                           identifier: id.uuidString)
            tracked.append(TrackedZone(id: id, name: zone.name ?? "Safe zone",
                                       center: zone.coordinate, radius: zone.radiusMeters))
        }
        zones = tracked
        recomputeStatus()
    }

    /// Call when a trail starts or resumes so the first fix becomes the new baseline.
    func reset() {
        pending.removeAll()
        for index in zones.indices { zones[index].state = .unknown }
        recomputeStatus()
    }

    func process(_ fixes: [CLLocation]) {
        guard !zones.isEmpty else { return }
        for fix in fixes where fix.horizontalAccuracy >= 0 && fix.horizontalAccuracy <= maxAccuracy {
            for index in zones.indices {
                guard let region = regions[zones[index].id] else { continue }
                apply(region.contains(fix.coordinate) ? .inside : .outside, at: index)
            }
        }
        recomputeStatus()
    }

    private func apply(_ observed: Status, at index: Int) {
        let id = zones[index].id
        let current = zones[index].state

        if current == .unknown {
            zones[index].state = observed        // first reading: baseline, no alert
            return
        }
        if observed == current {
            pending[id] = nil
            return
        }

        let previousCount = pending[id]?.state == observed ? (pending[id]?.count ?? 0) : 0
        let count = previousCount + 1
        if count >= confirmations {
            zones[index].state = observed
            pending[id] = nil
            onTransition?(observed, zones[index].name)
        } else {
            pending[id] = (observed, count)
        }
    }

    private func recomputeStatus() {
        if zones.isEmpty {
            status = .noZone
            currentZoneName = nil
        } else if let inside = zones.first(where: { $0.state == .inside }) {
            status = .inside
            currentZoneName = inside.name
        } else if zones.contains(where: { $0.state == .outside }) {
            status = .outside
            currentZoneName = nil
        } else {
            status = .unknown
            currentZoneName = nil
        }
    }
}
