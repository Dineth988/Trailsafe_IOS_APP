import Testing
import Foundation
import CoreData
import CoreLocation
@testable import IOS_CW2

@MainActor
struct Day5Tests {
    let persistence = PersistenceController(inMemory: true)
    var context: NSManagedObjectContext { persistence.container.viewContext }

    private func fix(_ lat: Double, _ lon: Double = 80.0) -> CLLocation {
        CLLocation(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                   altitude: 0, horizontalAccuracy: 5, verticalAccuracy: 5, timestamp: Date())
    }

    private func weather(
        code: Int = 0, temp: Double = 28, feels: Double = 28,
        wind: Double = 10, gust: Double = 15, chance: Int = 10, uv: Double = 3
    ) -> WeatherSnapshot {
        WeatherSnapshot(temperatureC: temp, feelsLikeC: feels, windKmh: wind, gustKmh: gust,
                        precipChance: chance, uvIndex: uv, weatherCode: code,
                        latitude: 7, longitude: 80, fetchedAt: Date())
    }

    // MARK: Multi-zone geofencing

    @Test func twoZonesAreTrackedIndependently() {
        let owner = UUID()
        SafeZoneStore.save(existing: nil, ownerID: owner, name: "A",
                           center: CLLocationCoordinate2D(latitude: 7.00, longitude: 80.0),
                           radius: 100, isActive: true, in: context)
        SafeZoneStore.save(existing: nil, ownerID: owner, name: "B",
                           center: CLLocationCoordinate2D(latitude: 7.01, longitude: 80.0),
                           radius: 100, isActive: true, in: context)

        let monitor = SafeZoneMonitor()
        var transitions: [(SafeZoneMonitor.Status, String)] = []
        monitor.onTransition = { status, name in transitions.append((status, name)) }
        monitor.reload(ownerID: owner, context: context)
        #expect(monitor.zones.count == 2)

        monitor.process([fix(7.00)])                  // baseline: inside A, outside B
        #expect(monitor.status == .inside)
        #expect(monitor.currentZoneName == "A")
        #expect(transitions.isEmpty)

        monitor.process([fix(7.01)])                  // first reading near B: not confirmed yet
        monitor.process([fix(7.0101)])                // second one confirms: left A, entered B
        #expect(transitions.contains { $0.0 == .outside && $0.1 == "A" })
        #expect(transitions.contains { $0.0 == .inside && $0.1 == "B" })
        #expect(monitor.currentZoneName == "B")
    }

    @Test func inactiveZonesAreSkippedAndLimitIsEnforced() {
        let owner = UUID()
        SafeZoneStore.save(existing: nil, ownerID: owner, name: "Off",
                           center: CLLocationCoordinate2D(latitude: 7, longitude: 80),
                           radius: 100, isActive: false, in: context)
        #expect(SafeZoneStore.activeZones(ownerID: owner, in: context).isEmpty)

        for index in 0..<(SafeZoneStore.maxZones - 1) {
            SafeZoneStore.save(existing: nil, ownerID: owner, name: "Z\(index)",
                               center: CLLocationCoordinate2D(latitude: 7, longitude: 80),
                               radius: 100, isActive: true, in: context)
        }
        #expect(SafeZoneStore.canAddZone(ownerID: owner, in: context) == false)
    }

    @Test func edgeHandleIsTheRightDistanceFromCentre() {
        let center = CLLocationCoordinate2D(latitude: 7.0, longitude: 80.0)
        let edge = GeoMath.edgeCoordinate(of: center, meters: 300)
        let distance = CLLocation(latitude: center.latitude, longitude: center.longitude)
            .distance(from: CLLocation(latitude: edge.latitude, longitude: edge.longitude))
        #expect(abs(distance - 300) < 3)
    }

    // MARK: Weather

    @Test func openMeteoResponseParsesIntoSnapshot() throws {
        let json = """
        {
          "current": {"time":"2026-10-28T14:15","temperature_2m":29.4,"apparent_temperature":33.1,
                      "weather_code":95,"wind_speed_10m":18.0,"wind_gusts_10m":41.0},
          "hourly": {"time":["2026-10-28T13:00","2026-10-28T14:00","2026-10-28T15:00","2026-10-28T16:00","2026-10-28T17:00"],
                     "precipitation_probability":[10,40,70,null,20],
                     "uv_index":[5.0,6.5,4.0,2.0,1.0]}
        }
        """
        let response = try JSONDecoder().decode(OpenMeteoResponse.self, from: Data(json.utf8))
        let snapshot = OpenMeteoClient.makeSnapshot(from: response, latitude: 7, longitude: 80, now: Date())

        #expect(snapshot.temperatureC == 29.4)
        #expect(snapshot.weatherCode == 95)
        #expect(snapshot.precipChance == 70)        // the highest of the next three hours
        #expect(snapshot.uvIndex == 6.5)            // the 14:00 hour
        #expect(snapshot.gustKmh == 41)
    }

    @Test func hazardRules() {
        #expect(WeatherHazard.assess(weather()).level == .safe)
        #expect(WeatherHazard.assess(weather(code: 95)).level == .severe)
        #expect(WeatherHazard.assess(weather(uv: 9)).level == .warning)
        #expect(WeatherHazard.assess(weather(feels: 36)).level == .warning)
        #expect(WeatherHazard.assess(weather(chance: 60)).level == .caution)

        let storm = WeatherHazard.assess(weather(code: 95, chance: 90))
        #expect(storm.level == .severe)
        #expect(storm.reasons.count >= 2)
        #expect(!storm.tip.isEmpty)
    }

    @Test func conditionMappingAndUVLabels() {
        #expect(WeatherCondition.describe(code: 95).symbol == "cloud.bolt.rain.fill")
        #expect(WeatherCondition.describe(code: 0).text == "Clear sky")
        #expect(weather(uv: 2).uvLabel == "Low")
        #expect(weather(uv: 7).uvLabel == "High")
        #expect(weather(uv: 12).uvLabel == "Extreme")
    }

    // MARK: Shared widget data

    @Test func widgetSnapshotSurvivesEncodingRoundTrip() throws {
        let original = WidgetSnapshot.sample
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WidgetSnapshot.self, from: data)
        #expect(decoded == original)
    }
}
