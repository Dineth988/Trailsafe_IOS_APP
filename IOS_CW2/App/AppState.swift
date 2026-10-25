import SwiftUI

@MainActor
final class AppState: ObservableObject {
    enum Phase { case onboarding, auth, locked, main }

    private enum Keys {
        static let onboarding = "hasCompletedOnboarding"
        static let biometric = "biometricLockEnabled"
    }

    private let defaults = UserDefaults.standard
    private let auth: AuthService

    @Published private(set) var hasCompletedOnboarding: Bool
    @Published private(set) var currentUser: UserProfile?
    @Published var isLocked: Bool
    @Published var biometricLockEnabled: Bool {
        didSet { defaults.set(biometricLockEnabled, forKey: Keys.biometric) }
    }

    init(auth: AuthService = .shared) {
        self.auth = auth
        let onboarded = defaults.bool(forKey: Keys.onboarding)
        let biometric = defaults.object(forKey: Keys.biometric) as? Bool ?? true
        let user = auth.restoreSession()

        hasCompletedOnboarding = onboarded
        biometricLockEnabled = biometric
        currentUser = user
        isLocked = user != nil && biometric   // cold launch with a saved session → locked
    }

    var phase: Phase {
        if !hasCompletedOnboarding { return .onboarding }
        guard currentUser != nil else { return .auth }
        if isLocked { return .locked }
        return .main
    }

    func completeOnboarding() {
        defaults.set(true, forKey: Keys.onboarding)
        hasCompletedOnboarding = true
    }

    func didAuthenticate(_ user: UserProfile) {
        currentUser = user
        isLocked = false
    }

    func unlock() { isLocked = false }

    func lockIfNeeded() {
        if currentUser != nil && biometricLockEnabled { isLocked = true }
    }

    func logOut() {
        auth.logOut()
        currentUser = nil
        isLocked = false
    }
}
