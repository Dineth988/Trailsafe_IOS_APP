import CoreData

@objc(UserProfile)
final class UserProfile: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var name: String?
    @NSManaged var email: String?
    @NSManaged var createdAt: Date?

    @nonobjc class func fetchRequest() -> NSFetchRequest<UserProfile> {
        NSFetchRequest<UserProfile>(entityName: "UserProfile")
    }

    static func make(in context: NSManagedObjectContext) -> UserProfile {
        NSEntityDescription.insertNewObject(forEntityName: "UserProfile", into: context) as! UserProfile
    }
}

@objc(TrailSession)
final class TrailSession: NSManagedObject {
    enum Status: String { case active, paused, completed }

    @NSManaged var id: UUID?
    @NSManaged var ownerID: UUID?
    @NSManaged var startedAt: Date?
    @NSManaged var endedAt: Date?
    @NSManaged var distanceMeters: Double
    @NSManaged var durationSeconds: Double
    @NSManaged var statusRaw: String?
    @NSManaged var points: NSSet?

    var status: Status {
        get { Status(rawValue: statusRaw ?? "") ?? .active }
        set { statusRaw = newValue.rawValue }
    }
}

@objc(LocationPoint)
final class LocationPoint: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var latitude: Double
    @NSManaged var longitude: Double
    @NSManaged var altitude: Double
    @NSManaged var accuracy: Double
    @NSManaged var timestamp: Date?
    @NSManaged var session: TrailSession?
}

@objc(TrustedContact)
final class TrustedContact: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var ownerID: UUID?
    @NSManaged var name: String?
    @NSManaged var phone: String?
    @NSManaged var email: String?
    @NSManaged var createdAt: Date?
}

@objc(SafeZone)
final class SafeZone: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var ownerID: UUID?
    @NSManaged var name: String?
    @NSManaged var centerLatitude: Double
    @NSManaged var centerLongitude: Double
    @NSManaged var radiusMeters: Double
    @NSManaged var isActive: Bool
}
