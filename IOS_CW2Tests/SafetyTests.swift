import Testing
import Foundation
import CoreData
import CoreLocation
@testable import IOS_CW2

@MainActor
struct SafetyTests {
    let persistence = PersistenceController(inMemory: true)
    var context: NSManagedObjectContext { persistence.container.viewContext }

    private func fix(_ lat: Double, _ lon: Double = 80.0, accuracy: Double = 5, at date: Date = Date()) -> CLLocation {
        CLLocation(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                   altitude: 0, horizontalAccuracy: accuracy, verticalAccuracy: 5, timestamp: date)
    }

    // MARK: Stationary detection

    @Test func stationaryDurationGrowsWhenNotMoving() {
        let t0 = Date()
        var detector = StationaryDetector()
        detector.reset(at: t0)
        detector.record(fix(7.0000), at: t0)
        detector.record(fix(7.0001), at: t0.addingTimeInterval(300))     // about 11 m: still stationary
        #expect(detector.stationaryDuration(at: t0.addingTimeInterval(600)) >= 600)
    }

    @Test func movementResetsStationaryTimer() {
        let t0 = Date()
        var detector = StationaryDetector()
        detector.reset(at: t0)
        detector.record(fix(7.0000), at: t0)
        detector.record(fix(7.0010), at: t0.addingTimeInterval(601))     // about 111 m: moved
        #expect(detector.stationaryDuration(at: t0.addingTimeInterval(700)) < 100)
    }

    @Test func poorAccuracyFixesAreIgnored() {
        let t0 = Date()
        var detector = StationaryDetector()
        detector.reset(at: t0)
        detector.record(fix(7.0000), at: t0)
        detector.record(fix(7.0100, accuracy: 500), at: t0.addingTimeInterval(120))
        #expect(detector.stationaryDuration(at: t0.addingTimeInterval(300)) >= 300)
    }

    // MARK: Safe zone store and monitor

    @Test func safeZoneSaveUpdatesExistingRecord() {
        let owner = UUID()
        let center = CLLocationCoordinate2D(latitude: 7.0, longitude: 80.0)
        let first = SafeZoneStore.save(existing: nil, ownerID: owner, name: "Home", center: center,
                                       radius: 150, isActive: true, in: context)
        SafeZoneStore.save(existing: first, ownerID: owner, name: "Home 2", center: center,
                           radius: 300, isActive: true, in: context)

        let count = (try? context.count(for: SafeZone.fetchRequest())) ?? 0
        #expect(count == 1)
        #expect(SafeZoneStore.zone(ownerID: owner, in: context)?.radiusMeters == 300)
    }

    @Test func zoneMonitorBaselinesThenAlertsOnConfirmedExit() {
        let owner = UUID()
        SafeZoneStore.save(existing: nil, ownerID: owner, name: "Home",
                           center: CLLocationCoordinate2D(latitude: 7.0, longitude: 80.0),
                           radius: 100, isActive: true, in: context)

        let monitor = SafeZoneMonitor()
        var transitions: [SafeZoneMonitor.Status] = []
        monitor.onTransition = { status, _ in transitions.append(status) }
        monitor.reload(ownerID: owner, context: context)
        #expect(monitor.status == .unknown)

        monitor.process([fix(7.0000)])                      // baseline: inside, no alert
        #expect(monitor.status == .inside)
        #expect(transitions.isEmpty)

        monitor.process([fix(7.0020)])                      // about 222 m away: one reading is not enough
        #expect(monitor.status == .inside)
        monitor.process([fix(7.0021)])                      // second confirms the exit
        #expect(monitor.status == .outside)
        #expect(transitions == [.outside])
    }

    @Test func inactiveZoneIsNotMonitored() {
        let owner = UUID()
        SafeZoneStore.save(existing: nil, ownerID: owner, name: "Off",
                           center: CLLocationCoordinate2D(latitude: 7.0, longitude: 80.0),
                           radius: 100, isActive: false, in: context)
        let monitor = SafeZoneMonitor()
        monitor.reload(ownerID: owner, context: context)
        #expect(monitor.status == .noZone)
    }

    // MARK: Data reset

    @Test func eraseRemovesOnlyThisUsersData() {
        let me = UUID(), other = UUID()
        for owner in [me, other] {
            let s = TrailSession.make(in: context)
            s.id = UUID(); s.ownerID = owner; s.startedAt = Date()
            SafeZoneStore.save(existing: nil, ownerID: owner, name: "Z",
                               center: CLLocationCoordinate2D(latitude: 7, longitude: 80),
                               radius: 100, isActive: true, in: context)
        }
        DataReset.eraseUserData(ownerID: me, in: context)

        #expect(SafeZoneStore.zone(ownerID: me, in: context) == nil)
        #expect(SafeZoneStore.zone(ownerID: other, in: context) != nil)
        #expect(((try? context.count(for: TrailSession.fetchRequest())) ?? 0) == 1)
    }

    // MARK: SOS

    @Test func sosCountdownCanBeCancelledOrTriggered() {
        let sos = SOSManager(location: LocationService(), notifications: .shared)
        sos.begin()
        #expect(sos.phase == .countdown(SOSManager.countdownSeconds))
        sos.cancel()
        #expect(sos.phase == .idle)

        sos.begin()
        sos.triggerNow()
        #expect(sos.phase == .triggered)
        sos.acknowledge()
        #expect(sos.phase == .idle)
    }
}
