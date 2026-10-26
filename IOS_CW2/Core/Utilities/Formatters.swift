import Foundation

enum Fmt {
    static func distanceParts(_ meters: Double) -> (value: String, unit: String) {
        meters < 1000
            ? (String(Int(meters.rounded())), "m")
            : (String(format: "%.2f", meters / 1000), "km")
    }

    static func distance(_ meters: Double) -> String {
        let parts = distanceParts(meters)
        return "\(parts.value) \(parts.unit)"
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let total = Int(max(seconds, 0))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
    }

    /// Minutes per kilometre, e.g. "5:30". Needs at least 50 m to be meaningful.
    static func pace(distanceMeters: Double, seconds: TimeInterval) -> String {
        guard distanceMeters >= 50, seconds > 0 else { return "--:--" }
        let secondsPerKm = Int(seconds / (distanceMeters / 1000))
        return String(format: "%d:%02d", secondsPerKm / 60, secondsPerKm % 60)
    }

    static func speedKmh(distanceMeters: Double, seconds: TimeInterval) -> String {
        guard seconds > 0 else { return "0.0" }
        return String(format: "%.1f", (distanceMeters / 1000) / (seconds / 3600))
    }
}
