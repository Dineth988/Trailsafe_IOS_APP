import Foundation

enum AppConfig {
    /// Firebase Realtime Database URL (no trailing slash). Copy it from the Firebase console.
    static let databaseURL = "https://YOUR-PROJECT-default-rtdb.firebaseio.com"

    /// Firebase Hosting URL where backend/public/index.html is deployed (no trailing slash).
    static let viewerBaseURL = "https://YOUR-PROJECT.web.app"

    static var isConfigured: Bool {
        !databaseURL.contains("YOUR-PROJECT") && !viewerBaseURL.contains("YOUR-PROJECT")
    }

    static func shareEndpoint(token: String) -> URL? {
        URL(string: "\(databaseURL)/shares/\(token).json")
    }

    static func viewerURL(token: String) -> URL? {
        URL(string: "\(viewerBaseURL)/?s=\(token)")
    }
}
