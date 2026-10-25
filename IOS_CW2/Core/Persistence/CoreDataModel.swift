import CoreData

enum CoreDataModel {
    static let model: NSManagedObjectModel = makeModel()

    private static func makeModel() -> NSManagedObjectModel {
        let user = entity("UserProfile", UserProfile.self)
        user.properties = [
            attribute("id", .UUIDAttributeType),
            attribute("name", .stringAttributeType),
            attribute("email", .stringAttributeType),
            attribute("createdAt", .dateAttributeType)
        ]

        let session = entity("TrailSession", TrailSession.self)
        session.properties = [
            attribute("id", .UUIDAttributeType),
            attribute("ownerID", .UUIDAttributeType),
            attribute("startedAt", .dateAttributeType),
            attribute("endedAt", .dateAttributeType),
            attribute("distanceMeters", .doubleAttributeType, defaultValue: 0.0, optional: false),
            attribute("durationSeconds", .doubleAttributeType, defaultValue: 0.0, optional: false),
            attribute("statusRaw", .stringAttributeType, defaultValue: "active")
        ]

        let point = entity("LocationPoint", LocationPoint.self)
        point.properties = [
            attribute("id", .UUIDAttributeType),
            attribute("latitude", .doubleAttributeType, defaultValue: 0.0, optional: false),
            attribute("longitude", .doubleAttributeType, defaultValue: 0.0, optional: false),
            attribute("altitude", .doubleAttributeType, defaultValue: 0.0, optional: false),
            attribute("accuracy", .doubleAttributeType, defaultValue: 0.0, optional: false),
            attribute("timestamp", .dateAttributeType)
        ]

        let contact = entity("TrustedContact", TrustedContact.self)
        contact.properties = [
            attribute("id", .UUIDAttributeType),
            attribute("ownerID", .UUIDAttributeType),
            attribute("name", .stringAttributeType),
            attribute("phone", .stringAttributeType),
            attribute("email", .stringAttributeType),
            attribute("createdAt", .dateAttributeType)
        ]

        let zone = entity("SafeZone", SafeZone.self)
        zone.properties = [
            attribute("id", .UUIDAttributeType),
            attribute("ownerID", .UUIDAttributeType),
            attribute("name", .stringAttributeType),
            attribute("centerLatitude", .doubleAttributeType, defaultValue: 0.0, optional: false),
            attribute("centerLongitude", .doubleAttributeType, defaultValue: 0.0, optional: false),
            attribute("radiusMeters", .doubleAttributeType, defaultValue: 200.0, optional: false),
            attribute("isActive", .booleanAttributeType, defaultValue: true, optional: false)
        ]

        // TrailSession 1 ──< LocationPoint
        let points = NSRelationshipDescription()
        points.name = "points"
        points.destinationEntity = point
        points.minCount = 0
        points.maxCount = 0               // 0 = to-many
        points.isOptional = true
        points.deleteRule = .cascadeDeleteRule

        let owner = NSRelationshipDescription()
        owner.name = "session"
        owner.destinationEntity = session
        owner.minCount = 0
        owner.maxCount = 1
        owner.isOptional = true
        owner.deleteRule = .nullifyDeleteRule

        points.inverseRelationship = owner
        owner.inverseRelationship = points
        session.properties.append(points)
        point.properties.append(owner)

        let model = NSManagedObjectModel()
        model.entities = [user, session, point, contact, zone]
        return model
    }

    private static func entity(_ name: String, _ cls: NSManagedObject.Type) -> NSEntityDescription {
        let description = NSEntityDescription()
        description.name = name
        description.managedObjectClassName = NSStringFromClass(cls)
        return description
    }

    private static func attribute(
        _ name: String,
        _ type: NSAttributeType,
        defaultValue: Any? = nil,
        optional: Bool = true
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = optional
        attribute.defaultValue = defaultValue
        return attribute
    }
}
