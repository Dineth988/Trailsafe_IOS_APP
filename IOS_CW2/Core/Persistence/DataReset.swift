import CoreData

enum DataReset {
    /// Deletes the user's trails (and their GPS points), contacts and safe zones. The account stays.
    static func eraseUserData(ownerID: UUID?, in context: NSManagedObjectContext) {
        guard let ownerID else { return }
        for entity in ["TrailSession", "TrustedContact", "SafeZone"] {
            let request = NSFetchRequest<NSManagedObject>(entityName: entity)
            request.predicate = NSPredicate(format: "ownerID == %@", ownerID as CVarArg)
            (try? context.fetch(request))?.forEach(context.delete)   // sessions cascade-delete their points
        }
        try? context.save()
    }
}
