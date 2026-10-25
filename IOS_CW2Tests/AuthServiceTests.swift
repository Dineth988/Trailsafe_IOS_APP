import Testing
import Foundation
@testable import IOS_CW2

@MainActor
struct AuthServiceTests {
    let persistence = PersistenceController(inMemory: true)
    let service: AuthService

    init() {
        service = AuthService(
            context: persistence.container.viewContext,
            keychain: KeychainService(service: "tests.\(UUID().uuidString)")
        )
    }

    @Test func signUpThenLogIn() throws {
        let created = try service.signUp(name: "Ama", email: "Ama@Example.com", password: "trailsafe1")
        #expect(created.email == "ama@example.com")

        service.logOut()
        let user = try service.logIn(email: "ama@example.com", password: "trailsafe1")
        #expect(user.objectID == created.objectID)
    }

    @Test func wrongPasswordFails() throws {
        _ = try service.signUp(name: "Ama", email: "ama@example.com", password: "trailsafe1")
        #expect(throws: AuthError.invalidCredentials) {
            try service.logIn(email: "ama@example.com", password: "wrongpass1")
        }
    }

    @Test func duplicateEmailRejected() throws {
        _ = try service.signUp(name: "Ama", email: "ama@example.com", password: "trailsafe1")
        #expect(throws: AuthError.emailTaken) {
            try service.signUp(name: "Other", email: "AMA@example.com", password: "trailsafe2")
        }
    }

    @Test func shortPasswordRejected() {
        #expect(throws: AuthError.weakPassword) {
            try service.signUp(name: "Ama", email: "ama@example.com", password: "short")
        }
    }

    @Test func sessionRestoresAfterSignUp() throws {
        _ = try service.signUp(name: "Ama", email: "ama@example.com", password: "trailsafe1")
        #expect(service.restoreSession()?.email == "ama@example.com")
        service.logOut()
        #expect(service.restoreSession() == nil)
    }
}
