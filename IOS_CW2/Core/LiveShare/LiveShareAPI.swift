import Foundation

/// Thin REST client for the Firebase Realtime Database.
struct LiveShareAPI {
    enum APIError: Error {
        case notConfigured
        case badStatus(Int)
    }

    var session: URLSession = .shared

    /// PUT = create or replace, PATCH = update fields (null removes a field), DELETE = remove.
    func send(method: String, token: String, body: [String: Any]? = nil) async throws {
        guard AppConfig.isConfigured, let url = AppConfig.shareEndpoint(token: token) else {
            throw APIError.notConfigured
        }
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.httpMethod = method
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.badStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
    }
}
