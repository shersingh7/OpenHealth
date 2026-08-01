import SwiftUI

struct DestinationEditorView: View {
    @State var destination: ExportDestination
    let secretStore: any SecretStore
    var onSave: (ExportDestination) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var secretField = ""
    @State private var hasExistingSecret = false
    @State private var errors: [String] = []
    @State private var isSaving = false

    // Editable fields
    @State private var name: String = ""
    @State private var folderPath: String = ""
    @State private var endpoint: String = ""
    @State private var method: HTTPMETHOD = .POST
    @State private var authMode: DestinationAuthMode = .none
    @State private var apiKeyHeader: String = "X-API-Key"
    /// Original secret ref from load — never mutated until a successful validated save.
    @State private var originalSecretRef: SecretReference?

    private let secretPlaceholder = "••••••••"

    var body: some View {
        NavigationStack {
            Form {
                Section("General") {
                    TextField("Name", text: $name)
                    Toggle("Enabled", isOn: $destination.isEnabled)
                }

                switch destination.kind {
                case .localFiles, .iCloudDrive:
                    Section(destination.kind == .iCloudDrive ? "iCloud Folder" : "Folder") {
                        TextField("Relative folder (optional)", text: $folderPath)
                        Text("Relative path only. No absolute paths or “..”.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                case .restAPI:
                    Section("REST API") {
                        TextField("HTTPS endpoint", text: $endpoint)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                        Picker("Method", selection: $method) {
                            ForEach(HTTPMETHOD.allCases, id: \.self) { m in
                                Text(m.rawValue).tag(m)
                            }
                        }
                        Picker("Authentication", selection: $authMode) {
                            ForEach(DestinationAuthMode.allCases, id: \.self) { a in
                                Text(a.displayName).tag(a)
                            }
                        }
                        if authMode != .none {
                            SecureField(hasExistingSecret ? "New secret (leave blank to keep)" : "Secret", text: $secretField)
                            if authMode == .apiKey {
                                TextField("API key header name", text: $apiKeyHeader)
                            }
                            Text("Secrets are stored in Keychain only, never in export configuration files. Cancelling leaves the existing secret unchanged.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                default:
                    Section {
                        Text("This destination type is not implemented.")
                            .foregroundStyle(.secondary)
                    }
                }

                if !errors.isEmpty {
                    Section("Validation") {
                        ForEach(errors, id: \.self) { err in
                            Text(err).foregroundStyle(.red).font(.footnote)
                        }
                    }
                }
            }
            .navigationTitle(destination.kind.displayName)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    // Cancel never touches Keychain.
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(isSaving)
                    .accessibilityIdentifier("oh.destination.save")
                }
            }
            .task { await load() }
        }
    }

    private func load() async {
        name = destination.name
        switch destination.config {
        case .localFiles(let path), .iCloudDrive(let path):
            folderPath = path ?? ""
        case .restAPI(let url, let m, let auth, let ref, let header, _):
            endpoint = url
            method = m
            authMode = auth
            apiKeyHeader = header ?? "X-API-Key"
            originalSecretRef = ref
            if let ref {
                hasExistingSecret = await secretStore.exists(reference: ref)
            }
        case .planned:
            break
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        errors = []

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1) Build candidate config without touching Keychain.
        var candidate = destination
        candidate.name = trimmedName
        var pendingSecretWrite: (SecretReference, String)?
        var pendingSecretDelete: SecretReference?
        var candidateSecretRef = originalSecretRef

        switch destination.kind {
        case .localFiles:
            let path = folderPath.trimmingCharacters(in: .whitespacesAndNewlines)
            candidate.config = .localFiles(folderPath: path.isEmpty ? nil : path)
        case .iCloudDrive:
            let path = folderPath.trimmingCharacters(in: .whitespacesAndNewlines)
            candidate.config = .iCloudDrive(folderPath: path.isEmpty ? nil : path)
        case .restAPI:
            if authMode != .none {
                let trimmed = secretField.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty && trimmed != secretPlaceholder {
                    let ref = candidateSecretRef ?? SecretReference(id: "dest-\(destination.id.uuidString)")
                    pendingSecretWrite = (ref, trimmed)
                    candidateSecretRef = ref
                } else if candidateSecretRef == nil || !hasExistingSecret {
                    errors.append("Authentication requires a secret.")
                    return
                }
            } else {
                if let existing = candidateSecretRef {
                    pendingSecretDelete = existing
                }
                candidateSecretRef = nil
            }

            var apiHeader: String? = nil
            if authMode == .apiKey {
                let h = apiKeyHeader.trimmingCharacters(in: .whitespacesAndNewlines)
                apiHeader = h.isEmpty ? "X-API-Key" : h
            }

            candidate.config = .restAPI(
                endpoint: endpoint.trimmingCharacters(in: .whitespacesAndNewlines),
                method: method,
                authMode: authMode,
                secretRef: candidateSecretRef,
                apiKeyHeaderName: apiHeader,
                customHeaders: [:]
            )
        default:
            errors.append("Unsupported destination.")
            return
        }

        // 2) Validate all non-secret fields before any Keychain mutation.
        #if DEBUG
        let allowLoopback = true
        #else
        let allowLoopback = false
        #endif
        errors = candidate.validate(allowLoopbackHTTP: allowLoopback)
        guard errors.isEmpty else { return }

        // 3) Commit Keychain only after validation succeeds.
        if let (ref, value) = pendingSecretWrite {
            do {
                try await secretStore.save(secret: value, for: ref)
            } catch {
                errors.append("Could not store secret.")
                return
            }
        }
        if let ref = pendingSecretDelete {
            do {
                try await secretStore.delete(reference: ref)
            } catch {
                errors.append("Could not remove previous secret from Keychain.")
                return
            }
        }

        onSave(candidate)
        dismiss()
    }
}
