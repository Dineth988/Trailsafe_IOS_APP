import Foundation
import Security

enum KeychainError: Error {
    case unexpectedStatus(OSStatus)
}

final class KeychainService {
    static let shared = KeychainService()

    private let service: String

    init(service: String = Bundle.main.bundleIdentifier ?? "com.trailsafe.app") {
        self.service = service
    }

    func set(_ data: Data, for key: String) throws {
        let query = baseQuery(for: key)
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data
        // Readable after first unlock so background tracking can still work.
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
    }

    func data(for key: String) -> Data? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    func setString(_ value: String, for key: String) throws {
        try set(Data(value.utf8), for: key)
    }

    func string(for key: String) -> String? {
        data(for: key).flatMap { String(data: $0, encoding: .utf8) }
    }

    func remove(_ key: String) {
        SecItemDelete(baseQuery(for: key) as CFDictionary)
    }

    private func baseQuery(for key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
    }
}
