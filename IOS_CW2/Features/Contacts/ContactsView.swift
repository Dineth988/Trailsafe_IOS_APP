import SwiftUI
import CoreData

private enum ContactSheet: Identifiable {
    case add
    case edit(TrustedContact)

    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let contact): return contact.objectID.uriRepresentation().absoluteString
        }
    }
}

struct ContactsView: View {
    @EnvironmentObject private var liveShare: LiveShareManager
    @Environment(\.managedObjectContext) private var context
    @FetchRequest private var contacts: FetchedResults<TrustedContact>

    private let ownerID: UUID?

    @State private var sheet: ContactSheet?
    @State private var showComposer = false
    @State private var hours = 2

    init(ownerID: UUID?) {
        self.ownerID = ownerID
        let request = TrustedContact.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        request.predicate = NSPredicate(format: "ownerID == %@", (ownerID ?? UUID()) as CVarArg)
        _contacts = FetchRequest(fetchRequest: request)
    }

    private var phones: [String] { ContactStore.phoneNumbers(ownerID: ownerID, in: context) }

    var body: some View {
        NavigationStack {
            List {
                liveShareSection
                contactsSection
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Contacts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { sheet = .add } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Add contact")
                }
            }
            .sheet(item: $sheet) { item in
                switch item {
                case .add:
                    ContactEditView(contact: nil, ownerID: ownerID)
                case .edit(let contact):
                    ContactEditView(contact: contact, ownerID: ownerID)
                }
            }
            .sheet(isPresented: $showComposer) {
                MessageComposer(recipients: phones, body: liveShare.inviteMessage) { showComposer = false }
                    .ignoresSafeArea()
            }
        }
    }

    // MARK: Live Share

    @ViewBuilder
    private var liveShareSection: some View {
        if let share = liveShare.active {
            Section {
                HStack(spacing: 8) {
                    Circle().fill(liveShare.sosActive ? Color.red : Theme.primary).frame(width: 10, height: 10)
                    Text(liveShare.sosActive ? "SOS is being shared" : "Live Share is on")
                        .font(Typography.headline)
                        .foregroundStyle(liveShare.sosActive ? Color.red : Theme.textPrimary)
                }
                LabeledContent("Ends in") {
                    Text(share.expiresAt, style: .relative).monospacedDigit()
                }
                LabeledContent("Status", value: syncText)

                if let url = liveShare.shareURL {
                    ShareLink(item: url, message: Text(liveShare.inviteMessage)) {
                        Label("Share link", systemImage: "square.and.arrow.up")
                    }
                }
                if MessageComposer.canSend, !phones.isEmpty {
                    Button { showComposer = true } label: {
                        Label("Message my contacts", systemImage: "message.fill")
                    }
                }
                Button("Stop Sharing", role: .destructive) { liveShare.stop() }
            } header: {
                Text("Live Share")
            } footer: {
                Text("Anyone with the link can see your live location until it ends. Stopping removes it from the server.")
            }
        } else {
            Section {
                Picker("Share for", selection: $hours) {
                    ForEach([1, 2, 4, 8], id: \.self) { Text("\($0) hour\($0 == 1 ? "" : "s")").tag($0) }
                }
                Button("Start Live Share") { liveShare.start(hours: hours) }
                    .buttonStyle(.trail(.accent))
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .padding(.vertical, 4)

                if let error = liveShare.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(Typography.caption)
                        .foregroundStyle(Theme.accent)
                }
                if !AppConfig.isConfigured {
                    Label("Firebase isn't configured yet. See AppConfig.swift.", systemImage: "gearshape.2")
                        .font(Typography.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            } header: {
                Text("Live Share")
            } footer: {
                Text("Creates a private link your trusted contacts can open in any browser to follow you on a map.")
            }
        }
    }

    private var syncText: String {
        switch liveShare.syncState {
        case .idle: return "Starting…"
        case .syncing: return "Sending…"
        case .synced(let date): return "Updated \(date.formatted(date: .omitted, time: .standard))"
        case .offline: return "Offline, will retry"
        case .failed(let code): return "Server error \(code)"
        }
    }

    // MARK: Contacts

    private var contactsSection: some View {
        Section {
            if contacts.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 32))
                        .foregroundStyle(Theme.primary)
                    Text("No trusted contacts yet")
                        .font(Typography.headline)
                    Text("Add someone who should hear about your SOS and Live Share.")
                        .font(Typography.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                    Button("Add Contact") { sheet = .add }
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else {
                ForEach(contacts, id: \.objectID) { contact in
                    Button { sheet = .edit(contact) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Theme.primary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(contact.name ?? "Unnamed")
                                    .foregroundStyle(Theme.textPrimary)
                                Text(detail(for: contact))
                                    .font(Typography.caption)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                    }
                }
                .onDelete { offsets in
                    offsets.map { contacts[$0] }.forEach { ContactStore.delete($0, in: context) }
                }
            }
        } header: {
            Text("Trusted contacts")
        }
    }

    private func detail(for contact: TrustedContact) -> String {
        let phone = contact.phone ?? ""
        let email = contact.email ?? ""
        return [phone, email].filter { !$0.isEmpty }.joined(separator: " · ")
    }
}
