import SwiftUI

struct DestinationPickerView: View {
    @Binding var destinations: [ExportDestination]
    @Binding var selectedIDs: [UUID]
    let secretStore: any SecretStore
    @Environment(\.dismiss) private var dismiss
    @State private var editorDestination: ExportDestination?
    @State private var showEditor = false
    @State private var pendingDelete: ExportDestination?
    @State private var deleteError: String?

    var body: some View {
        NavigationStack {
            List {
                Section("Configured") {
                    ForEach(destinations) { dest in
                        HStack {
                            OHDestinationRow(name: dest.name, kind: dest.kind, isEnabled: dest.isEnabled)
                            Spacer()
                            Image(systemName: selectedIDs.contains(dest.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(OHTheme.primaryAction)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            toggle(dest.id)
                        }
                        .swipeActions {
                            Button("Edit") {
                                editorDestination = dest
                                showEditor = true
                            }
                            Button("Delete", role: .destructive) {
                                pendingDelete = dest
                            }
                        }
                    }
                }

                Section("Add implemented destination") {
                    ForEach(ExportDestinationKind.implemented) { kind in
                        Button {
                            let draft: ExportDestination
                            switch kind {
                            case .localFiles:
                                draft = ExportDestination(kind: .localFiles, config: .localFiles(folderPath: nil))
                            case .iCloudDrive:
                                draft = ExportDestination(kind: .iCloudDrive, config: .iCloudDrive(folderPath: nil))
                            case .restAPI:
                                draft = ExportDestination(
                                    kind: .restAPI,
                                    config: .restAPI(
                                        endpoint: "https://",
                                        method: .POST,
                                        authMode: .none,
                                        secretRef: nil,
                                        apiKeyHeaderName: nil,
                                        customHeaders: [:]
                                    )
                                )
                            default:
                                return
                            }
                            editorDestination = draft
                            showEditor = true
                        } label: {
                            Label(kind.displayName, systemImage: kind.systemImage)
                                .frame(minHeight: OHTheme.minTapTarget)
                        }
                    }
                }

                Section {
                    ForEach(ExportDestinationKind.planned) { kind in
                        Label(kind.displayName, systemImage: kind.systemImage)
                            .foregroundStyle(.secondary)
                            .frame(minHeight: OHTheme.minTapTarget)
                    }
                } header: {
                    Text("Planned (not available)")
                } footer: {
                    Text("These destinations cannot be selected until implemented.")
                }

                if let deleteError {
                    Section {
                        Text(deleteError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Destinations")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("oh.export.destinations.done")
                }
            }
            .sheet(isPresented: $showEditor) {
                if let dest = editorDestination {
                    DestinationEditorView(destination: dest, secretStore: secretStore) { saved in
                        if let idx = destinations.firstIndex(where: { $0.id == saved.id }) {
                            destinations[idx] = saved
                        } else {
                            destinations.append(saved)
                        }
                        if !selectedIDs.contains(saved.id) {
                            selectedIDs.append(saved.id)
                        }
                    }
                }
            }
            .confirmationDialog(
                "Delete destination?",
                isPresented: Binding(
                    get: { pendingDelete != nil },
                    set: { if !$0 { pendingDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let dest = pendingDelete {
                        Task { await deleteDestination(dest) }
                    }
                }
                Button("Cancel", role: .cancel) {
                    pendingDelete = nil
                }
            } message: {
                Text("This removes the destination and its Keychain secret if nothing else references it.")
            }
        }
    }

    private func toggle(_ id: UUID) {
        if selectedIDs.contains(id) {
            selectedIDs.removeAll { $0 == id }
        } else {
            selectedIDs.append(id)
        }
    }

    private func deleteDestination(_ dest: ExportDestination) async {
        deleteError = nil
        // Stage/remove secrets referenced only by this destination in the current list.
        // When `secretStore` is a StagedSecretStore, this does not touch Keychain until
        // the parent automation Save commits (or is discarded on Cancel).
        let remainingRefs = Set(
            destinations
                .filter { $0.id != dest.id }
                .flatMap { $0.config.secretReferences.map(\.id) }
        )
        var cleanupFailed = false
        for ref in dest.config.secretReferences where !remainingRefs.contains(ref.id) {
            do {
                try await secretStore.delete(reference: ref)
            } catch {
                cleanupFailed = true
            }
        }
        destinations.removeAll { $0.id == dest.id }
        selectedIDs.removeAll { $0 == dest.id }
        pendingDelete = nil
        if cleanupFailed {
            deleteError = "Destination removed, but secret cleanup failed."
        }
    }
}
