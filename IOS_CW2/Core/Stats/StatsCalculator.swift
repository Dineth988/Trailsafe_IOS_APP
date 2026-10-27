import Foundation

struct SessionSnapshot {
    let startedAt: Date
    let distanceMeters: Double
    let durationSeconds: Double
}

enum StatsRange: String, CaseIterable, Identifiable {
    case week = "7 Days"
    case month = "30 Days"
    case all = "All"
    var id: String { rawValue }
}

struct DistanceBucket: Identifiable {
    let date: Date
    let km: Double
    var id: Date { date }
}

struct PacePoint: Identifiable {
    let date: Date
    let minutesPerKm: Double
    var id: Date { date }
}

struct StatsTotals {
    var trails = 0
    var distanceMeters = 0.0
    var durationSeconds = 0.0

    var paceText: String { Fmt.pace(distanceMeters: distanceMeters, seconds: durationSeconds) }
}

enum StatsCalculator {
    static func filter(
        _ sessions: [SessionSnapshot],
        range: StatsRange,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [SessionSnapshot] {
        guard range != .all else { return sessions }
        let days = range == .week ? 7 : 30
        let today = calendar.startOfDay(for: now)
        guard let start = calendar.date(byAdding: .day, value: -(days - 1), to: today) else { return sessions }
        return sessions.filter { $0.startedAt >= start }
    }

    /// Daily buckets (including empty days) for 7/30 days, monthly buckets for the last 12 months for "All".
    static func buckets(
        _ sessions: [SessionSnapshot],
        range: StatsRange,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [DistanceBucket] {
        switch range {
        case .week, .month:
            let days = range == .week ? 7 : 30
            let today = calendar.startOfDay(for: now)
            return (0..<days).reversed().compactMap { offset in
                guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
                let meters = sessions
                    .filter { calendar.isDate($0.startedAt, inSameDayAs: day) }
                    .reduce(0) { $0 + $1.distanceMeters }
                return DistanceBucket(date: day, km: meters / 1000)
            }
        case .all:
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
            return (0..<12).reversed().compactMap { offset in
                guard let month = calendar.date(byAdding: .month, value: -offset, to: monthStart) else { return nil }
                let meters = sessions
                    .filter { calendar.isDate($0.startedAt, equalTo: month, toGranularity: .month) }
                    .reduce(0) { $0 + $1.distanceMeters }
                return DistanceBucket(date: month, km: meters / 1000)
            }
        }
    }

    static func totals(_ sessions: [SessionSnapshot]) -> StatsTotals {
        StatsTotals(
            trails: sessions.count,
            distanceMeters: sessions.reduce(0) { $0 + $1.distanceMeters },
            durationSeconds: sessions.reduce(0) { $0 + $1.durationSeconds }
        )
    }

    /// One point per trail (oldest first). Very short trails and absurd paces are skipped.
    static func pacePoints(_ sessions: [SessionSnapshot]) -> [PacePoint] {
        sessions
            .filter { $0.distanceMeters >= 200 && $0.durationSeconds > 0 }
            .map { PacePoint(date: $0.startedAt,
                             minutesPerKm: ($0.durationSeconds / 60) / ($0.distanceMeters / 1000)) }
            .filter { $0.minutesPerKm <= 30 }
            .sorted { $0.date < $1.date }
    }
}
