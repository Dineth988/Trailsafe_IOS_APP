import SwiftUI
import CoreData

private enum ZoneEditorTarget: Identifiable {
    case add
    case edit(SafeZone)

    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let zone): return zone.objectID.uriRepresentation().absoluteString
        }
    }
}

struct SafeZonesListView: View {
    @EnvironmentObject private var monitor: SafeZoneMonitor
    @Environment(\.managedObjectContext) private var context
    @FetchRequest private var zones: FetchedResults<SafeZone>

    private let ownerID: UUID?
    @State private var editor: ZoneEditorTarget?

    init(ownerID: UUID?) {
        self.ownerID = ownerID
        let request = SafeZone.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        request.predicate = NSPredicate(format: "ownerID == %@", (ownerID ?? UUID()) as CVarArg)
        _zones = FetchRequest(fetchRequest: request)
    }

    var body: some View {
        List {
            Section {
                if zones.isEmpty {
                    emptyState
                } else {
                    ForEach(zones, id: \.objectID) { zone in row(zone) }
                        .onDelete(perform: delete)
                }
            } footer: {
                Text("Up to \(SafeZoneStore.maxZones) zones, for example home, trailhead and campsite. Alerts run while a trail is recording.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Safe Zones")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { editor = .add } label: { Image(systemName: "plus") }
                    .disabled(zones.count >= SafeZoneStore.maxZones)
                    .accessibilityLabel("Add safe zone")
            }
        }
        .fullScreenCover(item: $editor) { target in
            switch target {
            case .add: SafeZoneEditorView(zone: nil)
            case .edit(let zone): SafeZoneEditorView(zone: zone)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 34))
                .foregroundStyle(Theme.primary)
            Text("No safe zones yet")
                .font(Typography.headline)
            Text("Add a place you want to be alerted about when you leave or return.")
                .font(Typography.caption)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Button("Add Safe Zone") { editor = .add }
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func row(_ zone: SafeZone) -> some View {
        HStack {
            Button { editor = .edit(zone) } label: {
                HStack(spacing: 12) {
                    Image(systemName: "shield.fill")
                        .foregroundStyle(zone.isActive ? Theme.primary : Theme.textSecondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(zone.name ?? "Safe zone").foregroundStyle(Theme.textPrimary)
                        Text("Radius \(Fmt.distance(zone.radiusMeters))")
                            .font(Typography.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .buttonStyle(.plain)
            Spacer()
            Toggle("", isOn: activeBinding(zone))
                .labelsHidden()
                .accessibilityLabel("\(zone.name ?? "Safe zone") active")
        }
    }

    private func activeBinding(_ zone: SafeZone) -> Binding<Bool> {
        Binding(
            get: { zone.isActive },
            set: { newValue in
                zone.isActive = newValue
                try? context.save()
                monitor.reload(ownerID: ownerID, context: context)
            }
        )
    }

    private func delete(at offsets: IndexSet) {
        offsets.map { zones[$0] }.forEach { SafeZoneStore.delete($0, in: context) }
        monitor.reload(ownerID: ownerID, context: context)
    }
}
