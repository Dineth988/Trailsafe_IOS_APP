import Foundation

struct WeatherSnapshot: Codable, Equatable {
    var temperatureC: Double
    var feelsLikeC: Double
    var windKmh: Double
    var gustKmh: Double
    var precipChance: Int          // highest chance over the next 3 hours, in percent
    var uvIndex: Double
    var weatherCode: Int           // WMO code
    var latitude: Double
    var longitude: Double
    var fetchedAt: Date

    var condition: (text: String, symbol: String) { WeatherCondition.describe(code: weatherCode) }

    var uvLabel: String {
        switch uvIndex {
        case ..<3: return "Low"
        case ..<6: return "Moderate"
        case ..<8: return "High"
        case ..<11: return "Very high"
        default: return "Extreme"
        }
    }
}

enum WeatherCondition {
    static func describe(code: Int) -> (text: String, symbol: String) {
        switch code {
        case 0: return ("Clear sky", "sun.max.fill")
        case 1: return ("Mostly clear", "sun.max.fill")
        case 2: return ("Partly cloudy", "cloud.sun.fill")
        case 3: return ("Overcast", "cloud.fill")
        case 45, 48: return ("Fog", "cloud.fog.fill")
        case 51, 53, 55, 56, 57: return ("Drizzle", "cloud.drizzle.fill")
        case 61, 63, 66: return ("Rain", "cloud.rain.fill")
        case 65, 67: return ("Heavy rain", "cloud.heavyrain.fill")
        case 71, 73, 75, 77, 85, 86: return ("Snow", "cloud.snow.fill")
        case 80, 81: return ("Rain showers", "cloud.sun.rain.fill")
        case 82: return ("Violent showers", "cloud.heavyrain.fill")
        case 95: return ("Thunderstorm", "cloud.bolt.rain.fill")
        case 96, 99: return ("Thunderstorm with hail", "cloud.bolt.rain.fill")
        default: return ("Unknown", "questionmark.circle")
        }
    }
}
