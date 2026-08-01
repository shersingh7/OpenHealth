import Foundation

/// Stages Keychain mutations until the parent configuration is committed.
///
/// Destination editors must not permanently mutate Keychain while the parent
/// automation/export draft can still be cancelled. Loads resolve staged values
/// over the underlying store so draft exports can use new credentials without
/// orphaning secrets when the parent is dismissed without saving.
public actor StagedSecretStore: SecretStore {
    /// Opaque compensation token for the short window between committing
    /// Keychain mutations and durably saving the parent configuration.
    public struct CommitReceipt: Sendable {
        fileprivate let previousValues: [String: String]
        fileprivate let previouslyAbsent: Set<String>
        fileprivate let writes: [String: String]
        fileprivate let deletes: Set<String>
    }

    public enum TransactionError: LocalizedError, Sendable {
        case rollbackFailed

        public var errorDescription: String? {
            "A Keychain transaction failed and its previous state could not be fully restored."
        }
    }

    private let underlying: any SecretStore
    private var pendingWrites: [String: String] = [:]
    private var pendingDeletes: Set<String> = []

    public init(underlying: any SecretStore) {
        self.underlying = underlying
    }

    public func save(secret: String, for reference: SecretReference) async throws {
        pendingDeletes.remove(reference.id)
        pendingWrites[reference.id] = secret
    }

    public func load(reference: SecretReference) async throws -> String {
        if pendingDeletes.contains(reference.id) {
            throw SecretStoreError.notFound
        }
        if let staged = pendingWrites[reference.id] {
            return staged
        }
        return try await underlying.load(reference: reference)
    }

    public func delete(reference: SecretReference) async throws {
        pendingWrites.removeValue(forKey: reference.id)
        pendingDeletes.insert(reference.id)
    }

    public func exists(reference: SecretReference) async -> Bool {
        if pendingDeletes.contains(reference.id) {
            return false
        }
        if pendingWrites[reference.id] != nil {
            return true
        }
        return await underlying.exists(reference: reference)
    }

    public var hasPendingChanges: Bool {
        !pendingWrites.isEmpty || !pendingDeletes.isEmpty
    }

    /// Apply staged mutations to the underlying store.
    /// On failure, the previous values are restored and staged state remains
    /// available for retry or discard.
    public func commit() async throws {
        _ = try await commitWithReceipt()
    }

    /// Commit and return an opaque receipt that can compensate if the parent
    /// configuration fails to persist immediately afterwards.
    public func commitWithReceipt() async throws -> CommitReceipt {
        let writes = pendingWrites
        let deletes = pendingDeletes
        let affectedIDs = Set(writes.keys).union(deletes)
        var previousValues: [String: String] = [:]
        var previouslyAbsent: Set<String> = []

        for id in affectedIDs.sorted() {
            let reference = SecretReference(id: id)
            do {
                previousValues[id] = try await underlying.load(reference: reference)
            } catch SecretStoreError.notFound {
                previouslyAbsent.insert(id)
            }
        }

        let receipt = CommitReceipt(
            previousValues: previousValues,
            previouslyAbsent: previouslyAbsent,
            writes: writes,
            deletes: deletes
        )

        do {
            for id in writes.keys.sorted() {
                guard let value = writes[id] else { continue }
                try await underlying.save(secret: value, for: SecretReference(id: id))
            }
            for id in deletes.sorted() {
                try await underlying.delete(reference: SecretReference(id: id))
            }
        } catch {
            do {
                try await restoreUnderlyingState(from: receipt)
            } catch {
                throw TransactionError.rollbackFailed
            }
            throw error
        }

        pendingWrites.removeAll()
        pendingDeletes.removeAll()
        return receipt
    }

    /// Restore the pre-commit Keychain state and re-stage the user's edits so
    /// the parent can retry or safely discard them.
    public func rollback(_ receipt: CommitReceipt) async throws {
        var rollbackError: Error?
        do {
            try await restoreUnderlyingState(from: receipt)
        } catch {
            rollbackError = error
        }

        for (id, value) in receipt.writes where pendingWrites[id] == nil {
            pendingDeletes.remove(id)
            pendingWrites[id] = value
        }
        for id in receipt.deletes where pendingWrites[id] == nil {
            pendingDeletes.insert(id)
        }

        if rollbackError != nil {
            throw TransactionError.rollbackFailed
        }
    }

    /// Drop staged mutations without touching the underlying store.
    /// Existing Keychain credentials remain unchanged; never-committed writes vanish.
    public func discard() {
        pendingWrites.removeAll()
        pendingDeletes.removeAll()
    }

    private func restoreUnderlyingState(from receipt: CommitReceipt) async throws {
        var firstError: Error?

        for id in receipt.previousValues.keys.sorted() {
            guard let value = receipt.previousValues[id] else { continue }
            do {
                try await underlying.save(secret: value, for: SecretReference(id: id))
            } catch {
                if firstError == nil { firstError = error }
            }
        }
        for id in receipt.previouslyAbsent.sorted() {
            do {
                try await underlying.delete(reference: SecretReference(id: id))
            } catch {
                if firstError == nil { firstError = error }
            }
        }

        if let firstError { throw firstError }
    }
}
