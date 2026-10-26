import Testing
import Foundation
import CoreData
import CoreLocation
@testable import IOS_CW2

@MainActor
struct TrackingTests {
    let persistence = PersistenceController(inMemory: true)
    var context: NSManagedObjectContext { persistence.container.viewContext }

    @Test func paceFormatting() {
        #expect(Fmt.pace(distanceMeters: 1000, seconds: 330) == "5:30")
        #expect(Fmt.pace(distanceMeters: 10, seconds: 60) == "--:--")
    }

    @Test func durationFormatting() {
        #expect(Fmt.duration(65) == "01:05")
        #expect(Fmt.duration(3725) == "1:02:05")
    }

    @Test func distanceFormatting() {
        let short = Fmt.distanceParts(850)
        #expect(short.value == "850" && short.unit == "m")
        let long = Fmt.distanceParts(1250)
        #expect(long.value == "1.25" && long.unit == "km")
    }

    @Test func routeSplitsOnLongJump() {
        let t0 = Date()
        func point(lat: Double, offset: TimeInterval) -> LocationPoint {
            let p = LocationPoint.make(in: context)
            p.latitude = lat
            p.longitude = 80.0
            p.timestamp = t0.addingTimeInterval(offset)
            return p
        }
        let points = [
            point(lat: 7.000, offset: 0),
            point(lat: 7.0005, offset: 10),
            point(lat: 7.020, offset: 300)     // ~2 km away, 5 minutes later
        ]
        let segments = RouteBuilder.segments(from: points)
        #expect(segments.count == 2)
        #expect(segments[0].count == 2)
    }

    @Test func weeklyStatsSumCompletedTrails() {
        let owner = UUID()
        for distance in [1000.0, 2500.0] {
            let s = TrailSession.make(in: context)
            s.id = UUID()
            s.ownerID = owner
            s.startedAt = Date()
            s.distanceMeters = distance
            s.durationSeconds = 600
            s.status = .completed
        }
        let stats = TrailStore.weeklyStats(ownerID: owner, in: context)
        #expect(stats.sessions == 2)
        #expect(stats.distanceMeters == 3500)
        #expect(stats.durationSeconds == 1200)
    }
}
