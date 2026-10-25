import Foundation
import CoreData
import CryptoKit
import Security

enum AuthError: LocalizedError, Equatable {
    case emptyName, invalidEmail, weakPassword, emailTaken, invalidCredentials, storage

    var errorDescription: String? {
        switch self {
        case .emptyName: return "Please enter your name."
        case .invalidEmail: return "Please enter a valid email address."
        case .weakPassword: return "Password must be at least 8 characters."
        case .emailTaken: return "An account with this email already exists."
        case .invalidCredentials: return "Incorrect email or password."
        case .storage: return "Couldn't save your account securely. Please try again."
        }
    }
}

@MainActor
final class AuthService {
    static let shared = AuthService()

    private struct Credential: Codable {
        let salt: Data
        let hash: Data
    }

    private let context: NSManagedObjectContext
    private let keychain: KeychainService
    private let sessionKey = "session.userID"

    init(
        context: NSManagedObjectContext = PersistenceController.shared.container.viewContext,
        keychain: KeychainService = .shared
    ) {
        self.context = context
        self.keychain = keychain
    }

    // MARK: Public API

    func signUp(name: String, email: String, password: String) throws -> UserProfile {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEmail = normalise(email)

        guard !cleanName.isEmpty else { throw AuthError.emptyName }
        guard isValid(email: cleanEmail) else { throw AuthError.invalidEmail }
        guard password.count >= 8 else { throw AuthError.weakPassword }
        guard fetchUser(email: cleanEmail) == nil else { throw AuthError.emailTaken }

        let salt = randomSalt()
        let credential = Credential(salt: salt, hash: hash(password, salt: salt))

        do {
            try keychain.set(JSONEncoder().encode(credential), for: credentialKey(cleanEmail))
        } catch {
            throw AuthError.storage
        }

        let user = UserProfile.make(in: context)
        user.id = UUID()
        user.name = cleanName
        user.email = cleanEmail
        user.createdAt = Date()

        do { try context.save() } catch { throw AuthError.storage }
        try startSession(for: user)
        return user
    }

    func logIn(email: String, password: String) throws -> UserProfile {
        let cleanEmail = normalise(email)

        guard
            let data = keychain.data(for: credentialKey(cleanEmail)),
            let credential = try? JSONDecoder().decode(Credential.self, from: data),
            credential.hash == hash(password, salt: credential.salt),
            let user = fetchUser(email: cleanEmail)
        else {
            throw AuthError.invalidCredentials
        }

        try startSession(for: user)
        return user
    }

    func restoreSession() -> UserProfile? {
        guard
            let idString = keychain.string(for: sessionKey),
            let id = UUID(uuidString: idString)
        else { return nil }

        let request = UserProfile.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    func logOut() {
        keychain.remove(sessionKey)
    }

    // MARK: Helpers

    private func startSession(for user: UserProfile) throws {
        guard let id = user.id else { throw AuthError.storage }
        do { try keychain.setString(id.uuidString, for: sessionKey) } catch { throw AuthError.storage }
    }

    private func fetchUser(email: String) -> UserProfile? {
        let request = UserProfile.fetchRequest()
        request.predicate = NSPredicate(format: "email == %@", email)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    private func credentialKey(_ email: String) -> String { "credential.\(email)" }

    private func normalise(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func isValid(email: String) -> Bool {
        email.range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#, options: .regularExpression) != nil
    }

    private func randomSalt() -> Data {
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes)
    }

    private func hash(_ password: String, salt: Data) -> Data {
        var digest = Data(SHA256.hash(data: salt + Data(password.utf8)))
        for _ in 0..<10_000 {
            digest = Data(SHA256.hash(data: digest + salt))
        }
        return digest
    }
}
