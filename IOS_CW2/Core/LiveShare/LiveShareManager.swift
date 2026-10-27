import Foundation
import CoreLocation
import Combine
import Network
import Security

struct ActiveShare: Codable, Equatable {
    let token: String
    let startedAt: Date
    var expiresAt: Date
    var created: Bool          // has the server node been created yet?
}

enum ShareToken {
    /// 128 random bits as 32 hex characters.
    static func generate() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            return UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        }
        return bytes.map { String(format: "%02x", $0) }.joined()
    }
}

@MainActor
final class LiveShareManager: ObservableObject {
    enum SyncState: Equatable {
        case idle, syncing, synced(Date), offline, failed(Int)
    }

    @Published private(set) var active: ActiveShare?
    @Published private(set) var syncState: SyncState = .idle
    @Published private(set) var sosActive = false
    @Published var errorMessage: String?

    var ownerNameProvider: @MainActor () -> String = { "A TrailSafe user" }

    var shareURL: URL? { active.flatMap { AppConfig.viewerURL(token: $0.token) } }

    var sosMessage: String {
        "SOS! I need help. Follow my live location here: \(shareURL?.absoluteString ?? "")"
    }

    var inviteMessage: String {
        "I'm heading out on a trail. You can follow my live location here: \(shareURL?.absoluteString ?? "")"
    }

    private static let consumer = "liveshare"
    private static let activeKey = "liveShare.active"
    private static let staleKey = "liveShare.stale"
    private static let tickInterval: TimeInterval = 10

    private let location: LocationService
    private let recorder: TrailRecorder
    private let api: LiveShareAPI
    private let defaults: UserDefaults
    private let monitor = NWPathMonitor()

    private var pending: [String: Any] = [:]       // newest values not yet confirmed by the server
    private var latestFix: CLLocation?
    private var staleTokens: [String]               // finished shares whose server data still needs deleting
    private var isFlushing = false
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()

    init(
        location: LocationService,
        recorder: TrailRecorder,
        api: LiveShareAPI = LiveShareAPI(),
        defaults: UserDefaults = .standard
    ) {
        self.location = location
        self.recorder = recorder
        self.api = api
        self.defaults = defaults
        self.staleTokens = defaults.stringArray(forKey: Self.staleKey) ?? []

        location.locationUpdates
            .sink { [weak self] fixes in
                guard let self else { return }
                if let good = fixes.last(where: { $0.horizontalAccuracy >= 0 && $0.horizontalAccuracy <= 100 }) {
                    self.latestFix = good
                }
            }
            .store(in: &cancellables)

        // Offline-first: whenever the network comes back, push what we were holding.
        monitor.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied else { return }
            Task { @MainActor in await self?.flushAll() }
        }
        monitor.start(queue: DispatchQueue(label: "trailsafe.network"))

        resumeSavedShare()
        Task { await flushAll() }
    }

    // MARK: Public API

    func start(hours: Int) {
        guard active == nil else { return }
        guard AppConfig.isConfigured else {
            errorMessage = "Add your Firebase URLs in AppConfig.swift first."
            return
        }
        errorMessage = nil
        sosActive = false

        let now = Date()
        active = ActiveShare(
            token: ShareToken.generate(),
            startedAt: now,
            expiresAt: now.addingTimeInterval(TimeInterval(hours) * 3600),
            created: false
        )
        persistActive()

        location.startTracking(for: Self.consumer)
        location.requestAlwaysUpgradeIfNeeded()
        startTimer()
        queueSnapshot()
        Task { await flushAll() }
    }

    func stop() {
        guard let share = active else { return }
        stopTimer()
        location.stopTracking(for: Self.consumer)
        active = nil
        sosActive = false
        pending.removeAll()
        defaults.removeObject(forKey: Self.activeKey)

        staleTokens.append(share.token)       // the server node is deleted now, or retried later
        persistStale()
        syncState = .idle
        Task { await deleteStale() }
    }

    /// SOS: make sure a share exists, mark it as SOS, and flush straight away.
    func handleSOS(_ event: SOSEvent) {
        if active == nil { start(hours: 6) }
        guard active != nil else { return }
        sosActive = true

        var fields: [String: Any] = [
            "status": "sos",
            "sosAt": ms(event.date),
            "updatedAt": ms(Date())
        ]
        if let c = event.coordinate {
            fields["lat"] = c.latitude
            fields["lon"] = c.longitude
        }
        pending.merge(fields) { _, new in new }
        Task { await flushAll() }
    }

    func clearSOS() {
        guard sosActive else { return }
        sosActive = false
        pending.merge(["status": "active", "sosAt": NSNull(), "updatedAt": ms(Date())]) { _, new in new }
        Task { await flushAll() }
    }

    // MARK: Timer

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: Self.tickInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard let share = active else { return }
        if Date() >= share.expiresAt {
            stop()
            return
        }
        queueSnapshot()
        Task { await flushAll() }
    }

    /// Queues the current position and trail stats (this also acts as a heartbeat while standing still).
    private func queueSnapshot() {
        guard active != nil else { return }
        var fields: [String: Any] = [
            "updatedAt": ms(Date()),
            "trailActive": recorder.state == .recording,
            "distanceMeters": recorder.distanceMeters.isFinite ? recorder.distanceMeters.rounded() : 0
        ]
        if let fix = latestFix {
            fields["lat"] = fix.coordinate.latitude
            fields["lon"] = fix.coordinate.longitude
            fields["accuracy"] = fix.horizontalAccuracy.rounded()
        }
        pending.merge(fields) { _, new in new }
    }

    // MARK: Syncing

    private func flushAll() async {
        await deleteStale()
        await flush()
    }

    private func flush() async {
        guard let share = active, !isFlushing, !pending.isEmpty || !share.created else { return }
        isFlushing = true
        syncState = .syncing

        let snapshot = pending
        pending.removeAll()
        var succeeded = false

        do {
            if share.created {
                try await api.send(method: "PATCH", token: share.token, body: snapshot)
            } else {
                var full = baseFields()
                full.merge(snapshot) { _, new in new }
                try await api.send(method: "PUT", token: share.token, body: full)
                markCreated(token: share.token)
            }
            syncState = .synced(Date())
            succeeded = true
        } catch {
            // Keep the unsent values, but never let them overwrite newer ones.
            pending = snapshot.merging(pending) { _, new in new }
            if let apiError = error as? LiveShareAPI.APIError, case .badStatus(let code) = apiError {
                syncState = .failed(code)
            } else {
                syncState = .offline
            }
        }

        isFlushing = false
        if succeeded, !pending.isEmpty { await flush() }     // something changed while we were sending
    }

    private func deleteStale() async {
        for token in staleTokens {
            do {
                try await api.send(method: "DELETE", token: token)
                staleTokens.removeAll { $0 == token }
                persistStale()
            } catch {
                // Stays in the list and is retried on the next flush.
            }
        }
    }

    private func baseFields() -> [String: Any] {
        guard let share = active else { return [:] }
        return [
            "ownerName": String(ownerNameProvider().prefix(60)),
            "status": "active",
            "startedAt": ms(share.startedAt),
            "expiresAt": ms(share.expiresAt),
            "updatedAt": ms(Date())
        ]
    }

    private func markCreated(token: String) {
        guard active?.token == token else { return }
        active?.created = true
        persistActive()
    }

    // MARK: Persistence (so a share survives an app restart)

    private func resumeSavedShare() {
        guard
            let data = defaults.data(forKey: Self.activeKey),
            let saved = try? JSONDecoder().decode(ActiveShare.self, from: data)
        else { return }

        if saved.expiresAt > Date() {
            active = saved
            location.startTracking(for: Self.consumer)
            startTimer()
            queueSnapshot()
        } else {
            staleTokens.append(saved.token)
            persistStale()
            defaults.removeObject(forKey: Self.activeKey)
        }
    }

    private func persistActive() {
        if let active, let data = try? JSONEncoder().encode(active) {
            defaults.set(data, forKey: Self.activeKey)
        }
    }

    private func persistStale() {
        defaults.set(staleTokens, forKey: Self.staleKey)
    }

    private func ms(_ date: Date) -> Int {
        Int((date.timeIntervalSince1970 * 1000).rounded())
    }
}
