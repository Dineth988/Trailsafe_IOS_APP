import Testing
import Foundation
@testable import IOS_CW2

@MainActor
struct Day4Tests {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }
    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 28, hour: 12))! }
    private func daysAgo(_ n: Int) -> Date { calendar.date(byAdding: .day, value: -n, to: now)! }

    // MARK: Live Share basics

    @Test func tokenIs32HexCharactersAndUnique() {
        let a = ShareToken.generate(), b = ShareToken.generate()
        #expect(a.count == 32 && b.count == 32)
        #expect(a != b)
        #expect(a.allSatisfy { $0.isHexDigit })
    }

    @Test func viewerURLContainsToken() {
        let url = AppConfig.viewerURL(token: "abc123")
        #expect(url?.absoluteString.hasSuffix("/?s=abc123") == true)
    }

    // MARK: Stats

    @Test func weekBucketsIncludeEmptyDays() {
        let sessions = [
            SessionSnapshot(startedAt: daysAgo(0), distanceMeters: 5000, durationSeconds: 1800),
            SessionSnapshot(startedAt: daysAgo(2), distanceMeters: 3000, durationSeconds: 1200)
        ]
        let buckets = StatsCalculator.buckets(sessions, range: .week, now: now, calendar: calendar)
        #expect(buckets.count == 7)
        #expect(buckets.last?.km == 5.0)         // today
        #expect(buckets[4].km == 3.0)            // two days ago
        #expect(buckets[0].km == 0)
    }

    @Test func monthFilterExcludesOldTrailsButAllKeepsThem() {
        let sessions = [
            SessionSnapshot(startedAt: daysAgo(1), distanceMeters: 1000, durationSeconds: 600),
            SessionSnapshot(startedAt: daysAgo(40), distanceMeters: 1000, durationSeconds: 600)
        ]
        #expect(StatsCalculator.filter(sessions, range: .month, now: now, calendar: calendar).count == 1)
        #expect(StatsCalculator.filter(sessions, range: .all, now: now, calendar: calendar).count == 2)
    }

    @Test func totalsAndAveragePace() {
        let sessions = [
            SessionSnapshot(startedAt: now, distanceMeters: 5000, durationSeconds: 1500),
            SessionSnapshot(startedAt: now, distanceMeters: 3000, durationSeconds: 900)
        ]
        let totals = StatsCalculator.totals(sessions)
        #expect(totals.trails == 2)
        #expect(totals.distanceMeters == 8000)
        #expect(totals.paceText == "5:00")        // 2400 s over 8 km
    }

    @Test func pacePointsSkipTinyTrails() {
        let sessions = [
            SessionSnapshot(startedAt: daysAgo(2), distanceMeters: 100, durationSeconds: 60),
            SessionSnapshot(startedAt: daysAgo(1), distanceMeters: 2000, durationSeconds: 720)
        ]
        let points = StatsCalculator.pacePoints(sessions)
        #expect(points.count == 1)
        #expect(abs(points[0].minutesPerKm - 6.0) < 0.001)
    }

    // MARK: Contacts

    @Test func contactValidation() {
        #expect(throws: ContactValidationError.emptyName) {
            try ContactStore.validate(name: " ", phone: "0771234567", email: "")
        }
        #expect(throws: ContactValidationError.noContactMethod) {
            try ContactStore.validate(name: "Ama", phone: "", email: "")
        }
        #expect(throws: ContactValidationError.invalidPhone) {
            try ContactStore.validate(name: "Ama", phone: "123", email: "")
        }
        #expect(throws: ContactValidationError.invalidEmail) {
            try ContactStore.validate(name: "Ama", phone: "", email: "not-an-email")
        }
        #expect(throws: Never.self) {
            try ContactStore.validate(name: "Ama", phone: "+94 77 123 4567", email: "")
        }
    }

    @Test func savingContactStoresOwnerAndPhoneNumbers() throws {
        let persistence = PersistenceController(inMemory: true)
        let context = persistence.container.viewContext
        let owner = UUID()
        try ContactStore.save(existing: nil, ownerID: owner, name: "Ama", phone: "0771234567", email: "", in: context)
        try ContactStore.save(existing: nil, ownerID: owner, name: "Raj", phone: "", email: "raj@example.com", in: context)
        #expect(ContactStore.phoneNumbers(ownerID: owner, in: context) == ["0771234567"])
    }
}
