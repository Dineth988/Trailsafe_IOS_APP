import LocalAuthentication

enum BiometricKind {
    case faceID, touchID, opticID, none

    var displayName: String {
        switch self {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        case .none: return "Passcode"
        }
    }

    var symbolName: String {
        switch self {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        case .opticID: return "opticid"
        case .none: return "lock.fill"
        }
    }
}

@MainActor
final class BiometricService {
    static let shared = BiometricService()

    var kind: BiometricKind {
        let context = LAContext()
        var error: NSError?
        // biometryType is only populated after canEvaluatePolicy has been called.
        _ = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
        switch context.biometryType {
        case .faceID: return .faceID
        case .touchID: return .touchID
        case .opticID: return .opticID
        default: return .none
        }
    }

    /// Uses biometrics first, with automatic device-passcode fallback.
    func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch {
            return false
        }
    }
}
