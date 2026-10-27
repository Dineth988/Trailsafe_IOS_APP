import CoreData

extension TrustedContact {
    @nonobjc class func fetchRequest() -> NSFetchRequest<TrustedContact> {
        NSFetchRequest<TrustedContact>(entityName: "TrustedContact")
    }

    static func make(in context: NSManagedObjectContext) -> TrustedContact {
        NSEntityDescription.insertNewObject(forEntityName: "TrustedContact", into: context) as! TrustedContact
    }
}

enum ContactValidationError: LocalizedError, Equatable {
    case emptyName, noContactMethod, invalidPhone, invalidEmail

    var errorDescription: String? {
        switch self {
        case .emptyName: return "Please enter a name."
        case .noContactMethod: return "Add a phone number or an email address."
        case .invalidPhone: return "That phone number looks too short."
        case .invalidEmail: return "That email address doesn't look right."
        }
    }
}

enum ContactStore {
    static func validate(name: String, phone: String, email: String) throws {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let phone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !name.isEmpty else { throw ContactValidationError.emptyName }
        guard !phone.isEmpty || !email.isEmpty else { throw ContactValidationError.noContactMethod }
        if !phone.isEmpty, phone.filter(\.isNumber).count < 7 { throw ContactValidationError.invalidPhone }
        if !email.isEmpty, email.range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#, options: .regularExpression) == nil {
            throw ContactValidationError.invalidEmail
        }
    }

    static func save(
        existing: TrustedContact?,
        ownerID: UUID?,
        name: String,
        phone: String,
        email: String,
        in context: NSManagedObjectContext
    ) throws {
        try validate(name: name, phone: phone, email: email)
        let contact = existing ?? TrustedContact.make(in: context)
        if contact.id == nil {
            contact.id = UUID()
            contact.createdAt = Date()
        }
        contact.ownerID = ownerID
        contact.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        contact.phone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        contact.email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        try context.save()
    }

    static func delete(_ contact: TrustedContact, in context: NSManagedObjectContext) {
        context.delete(contact)
        try? context.save()
    }

    static func phoneNumbers(ownerID: UUID?, in context: NSManagedObjectContext) -> [String] {
        guard let ownerID else { return [] }
        let request = TrustedContact.fetchRequest()
        request.predicate = NSPredicate(format: "ownerID == %@", ownerID as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        let contacts = (try? context.fetch(request)) ?? []
        return contacts.compactMap {
            let phone = $0.phone?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return phone.isEmpty ? nil : phone
        }
    }
}
