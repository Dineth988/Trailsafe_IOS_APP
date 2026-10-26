import CoreData

extension TrailSession {
    @nonobjc class func fetchRequest() -> NSFetchRequest<TrailSession> {
        NSFetchRequest<TrailSession>(entityName: "TrailSession")
    }

    static func make(in context: NSManagedObjectContext) -> TrailSession {
        NSEntityDescription.insertNewObject(forEntityName: "TrailSession", into: context) as! TrailSession
    }
}

extension LocationPoint {
    static func make(in context: NSManagedObjectContext) -> LocationPoint {
        NSEntityDescription.insertNewObject(forEntityName: "LocationPoint", into: context) as! LocationPoint
    }
}
