import SwiftUI

struct ContactEditView: View {
    let contact: TrustedContact?
    let ownerID: UUID?

    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var errorMessage: String?
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    TSField(title: "Name", icon: "person", text: $name,
                            contentType: .name, capitalization: .words)
                    TSField(title: "Phone number", icon: "phone", text: $phone,
                            keyboard: .phonePad, contentType: .telephoneNumber)
                    TSField(title: "Email (optional)", icon: "envelope", text: $email,
                            keyboard: .emailAddress, contentType: .emailAddress)

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(Typography.caption)
                            .foregroundStyle(Theme.accent)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Text("A phone number lets TrailSafe pre-fill an SMS with your Live Share link.")
                        .font(Typography.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(Theme.Spacing.md)
            }
            .background(Theme.background)
            .navigationTitle(contact == nil ? "Add Contact" : "Edit Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).fontWeight(.semibold)
                }
            }
            .task {
                guard !loaded else { return }
                loaded = true
                name = contact?.name ?? ""
                phone = contact?.phone ?? ""
                email = contact?.email ?? ""
            }
        }
    }

    private func save() {
        do {
            try ContactStore.save(existing: contact, ownerID: ownerID,
                                  name: name, phone: phone, email: email, in: context)
            dismiss()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't save this contact."
        }
    }
}
