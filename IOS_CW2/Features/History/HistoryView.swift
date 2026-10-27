import SwiftUI
import Charts
import CoreData

struct HistoryView: View {
    @FetchRequest private var sessions: FetchedResults<TrailSession>
    @State private var range: StatsRange = .week

    init(ownerID: UUID?) {
        let request = TrailSession.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "startedAt", ascending: false)]
        request.predicate = NSPredicate(
            format: "ownerID == %@ AND statusRaw == %@",
            (ownerID ?? UUID()) as CVarArg, TrailSession.Status.completed.rawValue
        )
        _sessions = FetchRequest(fetchRequest: request)
    }

    private var snapshots: [SessionSnapshot] {
        sessions.compactMap { session in
            session.startedAt.map {
                SessionSnapshot(startedAt: $0, distanceMeters: session.distanceMeters,
                                durationSeconds: session.durationSeconds)
            }
        }
    }

    private var inRange: [SessionSnapshot] { StatsCalculator.filter(snapshots, range: range) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    Picker("Range", selection: $range) {
                        ForEach(StatsRange.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    if sessions.isEmpty {
                        emptyState
                    } else {
                        totalsGrid
                        distanceChart
                        paceChart
                        sessionList
                    }
                }
                .padding(Theme.Spacing.md)
            }
            .background(Theme.background)
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: Sections

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "figure.hiking")
                .font(.system(size: 44))
                .foregroundStyle(Theme.primary)
            Text("No trails yet")
                .font(Typography.title)
                .foregroundStyle(Theme.textPrimary)
            Text("Finish a trail from the Home tab and it will appear here with charts.")
                .font(Typography.body)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xl)
    }

    private var totalsGrid: some View {
        let totals = StatsCalculator.totals(inRange)
        let distance = Fmt.distanceParts(totals.distanceMeters)
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.sm) {
            StatTile(title: "Trails", value: "\(totals.trails)")
            StatTile(title: "Distance", value: distance.value, unit: distance.unit)
            StatTile(title: "Time", value: Fmt.duration(totals.durationSeconds))
            StatTile(title: "Avg pace", value: totals.paceText, unit: "/km")
        }
    }

    private var distanceChart: some View {
        let buckets = StatsCalculator.buckets(snapshots, range: range)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Distance")
                .font(Typography.headline)
                .foregroundStyle(Theme.textPrimary)
            Chart(buckets) { bucket in
                BarMark(
                    x: .value("Date", bucket.date, unit: range == .all ? .month : .day),
                    y: .value("Distance (km)", bucket.km)
                )
                .foregroundStyle(Theme.primary)
            }
            .chartYAxisLabel("km")
            .frame(height: 180)
        }
        .cardStyle()
    }

    private var paceChart: some View {
        let points = StatsCalculator.pacePoints(inRange)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Pace trend")
                .font(Typography.headline)
                .foregroundStyle(Theme.textPrimary)
            if points.count >= 2 {
                Chart(points) { point in
                    LineMark(x: .value("Date", point.date), y: .value("min/km", point.minutesPerKm))
                        .foregroundStyle(Theme.info)
                    PointMark(x: .value("Date", point.date), y: .value("min/km", point.minutesPerKm))
                        .foregroundStyle(Theme.info)
                }
                .chartYAxisLabel("min/km")
                .frame(height: 160)
            } else {
                Text("Record at least two trails in this range to see your pace trend.")
                    .font(Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .cardStyle()
    }

    private var sessionList: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Recent trails")
                .font(Typography.headline)
                .foregroundStyle(Theme.textPrimary)
            ForEach(sessions.prefix(30), id: \.objectID) { session in
                NavigationLink {
                    SessionDetailView(session: session)
                } label: {
                    row(for: session)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func row(for session: TrailSession) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text((session.startedAt ?? Date()).formatted(date: .abbreviated, time: .shortened))
                    .font(Typography.headline)
                    .foregroundStyle(Theme.textPrimary)
                Text("\(Fmt.distance(session.distanceMeters)) · \(Fmt.duration(session.durationSeconds))")
                    .font(Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
        }
        .cardStyle()
    }
}
