import SwiftUI

@MainActor
final class AuthViewModel: ObservableObject {
    enum Mode: String, CaseIterable, Identifiable {
        case logIn = "Log In"
        case signUp = "Sign Up"
        var id: String { rawValue }
    }

    @Published var mode: Mode = .logIn { didSet { errorMessage = nil } }
    @Published var name = ""
    @Published var email = ""
    @Published var password = ""
    @Published var errorMessage: String?

    private let auth: AuthService

    init(auth: AuthService = .shared) {
        self.auth = auth
    }

    var canSubmit: Bool {
        !email.isEmpty && !password.isEmpty && (mode == .logIn || !name.isEmpty)
    }

    /// Returns the user on success, nil on failure (and sets `errorMessage`).
    func submit() -> UserProfile? {
        do {
            let user: UserProfile
            switch mode {
            case .signUp: user = try auth.signUp(name: name, email: email, password: password)
            case .logIn: user = try auth.logIn(email: email, password: password)
            }
            errorMessage = nil
            password = ""
            return user
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Something went wrong."
            return nil
        }
    }
}
