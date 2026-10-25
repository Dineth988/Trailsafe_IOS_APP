import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "TrailSafe", managedObjectModel: CoreDataModel.model)

        if let description = container.persistentStoreDescriptions.first {
            if inMemory {
                description.type = NSInMemoryStoreType
            } else {
                // Lets the app keep recording trails while the phone is locked.
                description.setOption(
                    FileProtectionType.completeUntilFirstUserAuthentication as NSObject,
                    forKey: NSPersistentStoreFileProtectionKey
                )
            }
        }

        container.loadPersistentStores { _, error in
            if let error {
                fatalError("Core Data failed to load: \(error)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    func save() {
        let context = container.viewContext
        guard context.hasChanges else { return }
        do { try context.save() } catch { print("Core Data save error: \(error)") }
    }
}
