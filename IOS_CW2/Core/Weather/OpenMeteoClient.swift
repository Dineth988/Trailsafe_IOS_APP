import Foundation

struct OpenMeteoResponse: Decodable {
    struct Current: Decodable {
        let time: String
        let temperature: Double
        let apparentTemperature: Double?
        let weatherCode: Int
        let windSpeed: Double
        let windGusts: Double?

        enum CodingKeys: String, CodingKey {
            case time
            case temperature = "temperature_2m"
            case apparentTemperature = "apparent_temperature"
            case weatherCode = "weather_code"
            case windSpeed = "wind_speed_10m"
            case windGusts = "wind_gusts_10m"
        }
    }

    struct Hourly: Decodable {
        let time: [String]
        let precipitationProbability: [Double?]
        let uvIndex: [Double?]

        enum CodingKeys: String, CodingKey {
            case time
            case precipitationProbability = "precipitation_probability"
            case uvIndex = "uv_index"
        }
    }

    let current: Current
    let hourly: Hourly
}

/// Free weather API, no key needed (https://open-meteo.com).
struct OpenMeteoClient {
    enum ClientError: Error {
        case badURL
        case badStatus(Int)
    }

    var session: URLSession = .shared

    func fetch(latitude: Double, longitude: Double) async throws -> WeatherSnapshot {
        guard var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast") else {
            throw ClientError.badURL
        }
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.4f", latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.4f", longitude)),
            URLQueryItem(name: "current",
                         value: "temperature_2m,apparent_temperature,weather_code,wind_speed_10m,wind_gusts_10m"),
            URLQueryItem(name: "hourly", value: "precipitation_probability,uv_index"),
            URLQueryItem(name: "forecast_days", value: "2"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "wind_speed_unit", value: "kmh")
        ]
        guard let url = components.url else { throw ClientError.badURL }

        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ClientError.badStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
        return Self.makeSnapshot(from: decoded, latitude: latitude, longitude: longitude, now: Date())
    }

    /// Pure function so it can be unit-tested without the network.
    static func makeSnapshot(
        from response: OpenMeteoResponse,
        latitude: Double,
        longitude: Double,
        now: Date
    ) -> WeatherSnapshot {
        let hourPrefix = String(response.current.time.prefix(13))          // e.g. 2026-10-28T14
        let index = response.hourly.time.firstIndex { $0.hasPrefix(hourPrefix) } ?? 0

        let probabilities = response.hourly.precipitationProbability
        let window = index..<min(index + 3, probabilities.count)
        let chance = window.compactMap { probabilities[$0] }.max() ?? 0

        let uvValues = response.hourly.uvIndex
        let uv = index < uvValues.count ? (uvValues[index] ?? 0) : 0

        return WeatherSnapshot(
            temperatureC: response.current.temperature,
            feelsLikeC: response.current.apparentTemperature ?? response.current.temperature,
            windKmh: response.current.windSpeed,
            gustKmh: response.current.windGusts ?? response.current.windSpeed,
            precipChance: Int(chance.rounded()),
            uvIndex: uv,
            weatherCode: response.current.weatherCode,
            latitude: latitude,
            longitude: longitude,
            fetchedAt: now
        )
    }
}
