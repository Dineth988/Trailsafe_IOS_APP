import CoreData

struct WeeklyStats {
    var distanceMeters = 0.0
    var durationSeconds = 0.0
    var sessions = 0
}

enum TrailStore {
    static func weeklyStats(ownerID: UUID?, in context: NSManagedObjectContext) -> WeeklyStats {
        guard let ownerID else { return WeeklyStats() }
        let since = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()

        let request = TrailSession.fetchRequest()
        request.predicate = NSPredicate(
            format: "ownerID == %@ AND statusRaw == %@ AND startedAt >= %@",
            ownerID as CVarArg, TrailSession.Status.completed.rawValue, since as NSDate
        )
        let sessions = (try? context.fetch(request)) ?? []
        return WeeklyStats(
            distanceMeters: sessions.reduce(0) { $0 + $1.distanceMeters },
            durationSeconds: sessions.reduce(0) { $0 + $1.durationSeconds },
            sessions: sessions.count
        )
    }
}
