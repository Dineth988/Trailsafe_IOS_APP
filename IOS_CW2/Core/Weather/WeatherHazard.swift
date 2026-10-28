import Foundation

struct WeatherAssessment: Equatable {
    enum Level: Int, Comparable {
        case safe, caution, warning, severe
        static func < (lhs: Level, rhs: Level) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    var level: Level
    var reasons: [String]
    var tip: String

    var title: String {
        switch level {
        case .safe: return "Conditions look good"
        case .caution: return "Caution"
        case .warning: return "Weather warning"
        case .severe: return "Severe weather"
        }
    }
}

enum WeatherHazard {
    static func assess(_ w: WeatherSnapshot) -> WeatherAssessment {
        typealias Level = WeatherAssessment.Level
        var found: [(level: Level, reason: String, tip: String)] = []

        // Storms
        if [95, 96, 99].contains(w.weatherCode) {
            found.append((.severe, "Thunderstorms in the area",
                          "Get off open ground and ridges, avoid tall trees, and consider ending your trail."))
        }
        // Wind
        if w.gustKmh >= 75 {
            found.append((.severe, "Dangerous wind gusts of \(Int(w.gustKmh)) km/h",
                          "Avoid exposed ridges and tree cover. Head to shelter."))
        } else if w.gustKmh >= 55 || w.windKmh >= 40 {
            found.append((.warning, "Strong wind (gusts \(Int(w.gustKmh)) km/h)",
                          "Stay off exposed ridges and watch for falling branches."))
        } else if w.gustKmh >= 40 {
            found.append((.caution, "Gusty wind", "Keep to sheltered paths."))
        }
        // Rain
        if w.precipChance >= 80 || [65, 67, 82].contains(w.weatherCode) {
            found.append((.warning, "Heavy rain likely",
                          "Wear a waterproof layer. Trails can be slippery and streams can rise quickly."))
        } else if w.precipChance >= 50 || [51, 53, 55, 56, 57, 61, 63, 66, 80, 81].contains(w.weatherCode) {
            found.append((.caution, "Rain likely", "Pack a waterproof layer."))
        }
        // UV
        if w.uvIndex >= 11 {
            found.append((.severe, "Extreme UV (\(Int(w.uvIndex)))",
                          "Avoid direct sun, cover up, and use high-factor sunscreen."))
        } else if w.uvIndex >= 8 {
            found.append((.warning, "Very high UV (\(Int(w.uvIndex)))",
                          "Wear a hat and sunscreen, and take breaks in the shade."))
        } else if w.uvIndex >= 6 {
            found.append((.caution, "High UV (\(Int(w.uvIndex)))", "Wear sunscreen and a hat."))
        }
        // Heat and cold
        if w.feelsLikeC >= 40 {
            found.append((.severe, "Dangerous heat (feels like \(Int(w.feelsLikeC))°)",
                          "Avoid exertion. Drink water regularly and rest in the shade."))
        } else if w.feelsLikeC >= 35 {
            found.append((.warning, "Heat stress risk (feels like \(Int(w.feelsLikeC))°)",
                          "Carry extra water, go slowly and rest in the shade."))
        } else if w.feelsLikeC >= 32 {
            found.append((.caution, "Hot conditions", "Carry plenty of water."))
        }
        if w.feelsLikeC <= -5 {
            found.append((.warning, "Very cold (feels like \(Int(w.feelsLikeC))°)",
                          "Wear insulating layers and limit time outside."))
        } else if w.feelsLikeC <= 0 {
            found.append((.caution, "Freezing conditions", "Watch for ice and dress warmly."))
        }
        // Visibility and snow
        if [45, 48].contains(w.weatherCode) {
            found.append((.caution, "Low visibility (fog)", "Stay on marked trails and keep your group close."))
        }
        if [75, 86].contains(w.weatherCode) {
            found.append((.warning, "Heavy snow", "Turn back if the trail is hard to follow."))
        } else if [71, 73, 77, 85].contains(w.weatherCode) {
            found.append((.caution, "Snowfall", "Footing may be slippery."))
        }

        guard !found.isEmpty else {
            return WeatherAssessment(level: .safe, reasons: [],
                                     tip: "Conditions look fine. Carry water and tell someone your plan.")
        }

        let sorted = found.sorted { $0.level > $1.level }
        return WeatherAssessment(level: sorted[0].level,
                                 reasons: sorted.map { $0.reason },
                                 tip: sorted[0].tip)
    }
}
