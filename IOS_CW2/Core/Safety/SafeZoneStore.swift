import CoreData
import CoreLocation

extension SafeZone {
    @nonobjc class func fetchRequest() -> NSFetchRequest<SafeZone> {
        NSFetchRequest<SafeZone>(entityName: "SafeZone")
    }

    static func make(in context: NSManagedObjectContext) -> SafeZone {
        NSEntityDescription.insertNewObject(forEntityName: "SafeZone", into: context) as! SafeZone
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: centerLatitude, longitude: centerLongitude)
    }
}

enum GeoMath {
    /// The point exactly `meters` east of `center` (used for the resize handle).
    static func edgeCoordinate(of center: CLLocationCoordinate2D, meters: Double) -> CLLocationCoordinate2D {
        let metersPerDegreeLon = 111_320 * max(cos(center.latitude * .pi / 180), 0.01)
        return CLLocationCoordinate2D(latitude: center.latitude,
                                      longitude: center.longitude + meters / metersPerDegreeLon)
    }
}

enum SafeZoneStore {
    static let maxZones = 10

    static func zones(ownerID: UUID?, in context: NSManagedObjectContext) -> [SafeZone] {
        guard let ownerID else { return [] }
        let request = SafeZone.fetchRequest()
        request.predicate = NSPredicate(format: "ownerID == %@", ownerID as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        return (try? context.fetch(request)) ?? []
    }

    static func zone(ownerID: UUID?, in context: NSManagedObjectContext) -> SafeZone? {
        zones(ownerID: ownerID, in: context).first
    }

    static func activeZones(ownerID: UUID?, in context: NSManagedObjectContext) -> [SafeZone] {
        zones(ownerID: ownerID, in: context).filter { $0.isActive }
    }

    static func canAddZone(ownerID: UUID?, in context: NSManagedObjectContext) -> Bool {
        zones(ownerID: ownerID, in: context).count < maxZones
    }

    @discardableResult
    static func save(
        existing: SafeZone?,
        ownerID: UUID?,
        name: String,
        center: CLLocationCoordinate2D,
        radius: Double,
        isActive: Bool,
        in context: NSManagedObjectContext
    ) -> SafeZone {
        let zone = existing ?? SafeZone.make(in: context)
        if zone.id == nil { zone.id = UUID() }
        zone.ownerID = ownerID
        zone.name = name
        zone.centerLatitude = center.latitude
        zone.centerLongitude = center.longitude
        zone.radiusMeters = max(radius, 50)
        zone.isActive = isActive
        try? context.save()
        return zone
    }

    static func delete(_ zone: SafeZone, in context: NSManagedObjectContext) {
        context.delete(zone)
        try? context.save()
    }
}
