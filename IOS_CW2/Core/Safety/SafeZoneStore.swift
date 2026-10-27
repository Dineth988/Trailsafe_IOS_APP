import CoreData
import CoreLocation

extension SafeZone {
    @nonobjc class func fetchRequest() -> NSFetchRequest<SafeZone> {
        NSFetchRequest<SafeZone>(entityName: "SafeZone")
    }

    static func make(in context: NSManagedObjectContext) -> SafeZone {
        NSEntityDescription.insertNewObject(forEntityName: "SafeZone", into: context) as! SafeZone
    }
}

/// The MVP supports one safe zone per user (multi-zone arrives on Day 5).
enum SafeZoneStore {
    static func zone(ownerID: UUID?, in context: NSManagedObjectContext) -> SafeZone? {
        guard let ownerID else { return nil }
        let request = SafeZone.fetchRequest()
        request.predicate = NSPredicate(format: "ownerID == %@", ownerID as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    static func activeZone(ownerID: UUID?, in context: NSManagedObjectContext) -> SafeZone? {
        guard let zone = zone(ownerID: ownerID, in: context), zone.isActive else { return nil }
        return zone
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
