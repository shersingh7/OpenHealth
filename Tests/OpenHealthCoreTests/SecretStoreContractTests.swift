// XCTest provided by MiniXCTest in this target
import Foundation
@testable import OpenHealthCore

final class SecretStoreContractTests: XCTestCase {
    func testSaveLoadDelete() async throws {
        let store = FakeSecretStore()
        let ref = SecretReference(id: "dest-1-token")
        try await store.save(secret: "super-secret", for: ref)
        let exists1 = await store.exists(reference: ref)
        XCTAssertTrue(exists1)
        let value = try await store.load(reference: ref)
        XCTAssertEqual(value, "super-secret")
        try await store.delete(reference: ref)
        let exists2 = await store.exists(reference: ref)
        XCTAssertFalse(exists2)
        do {
            _ = try await store.load(reference: ref)
            XCTFail("Expected not found")
        } catch SecretStoreError.notFound {
            // expected
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testDestinationConfigDoesNotEmbedSecretMaterial() throws {
        let ref = SecretReference(id: "abc")
        let dest = ExportDestination(
            kind: .restAPI,
            name: "API",
            config: .restAPI(
                endpoint: "https://example.com/ingest",
                method: .POST,
                authMode: .bearer,
                secretRef: ref,
                apiKeyHeaderName: nil,
                customHeaders: [:]
            )
        )
        let data = try JSONEncoder().encode(dest)
        let json = String(data: data, encoding: .utf8)!
        XCTAssertFalse(json.contains("Bearer"))
        XCTAssertFalse(json.lowercased().contains("password"))
        XCTAssertTrue(json.contains("abc"))
    }

    // MARK: - Staged secret store (parent cancel safety)

    func testStagedWriteIsInvisibleToUnderlyingUntilCommit() async throws {
        let underlying = FakeSecretStore()
        let staged = StagedSecretStore(underlying: underlying)
        let ref = SecretReference(id: "dest-staged-1")

        try await staged.save(secret: "new-token", for: ref)
        let stagedExists = await staged.exists(reference: ref)
        XCTAssertTrue(stagedExists)
        let stagedValue = try await staged.load(reference: ref)
        XCTAssertEqual(stagedValue, "new-token")
        // Underlying Keychain/fake must not see the write yet.
        let underlyingExists = await underlying.exists(reference: ref)
        XCTAssertFalse(underlyingExists)

        await staged.discard()
        let stagedAfter = await staged.exists(reference: ref)
        let underlyingAfter = await underlying.exists(reference: ref)
        XCTAssertFalse(stagedAfter)
        XCTAssertFalse(underlyingAfter)
    }

    func testStagedOverwriteDoesNotCorruptExistingUntilCommit() async throws {
        let underlying = FakeSecretStore()
        let ref = SecretReference(id: "dest-existing")
        try await underlying.save(secret: "original", for: ref)

        let staged = StagedSecretStore(underlying: underlying)
        try await staged.save(secret: "replacement", for: ref)
        let stagedValue = try await staged.load(reference: ref)
        XCTAssertEqual(stagedValue, "replacement")
        // Underlying still original while staged.
        let underlyingValue = try await underlying.load(reference: ref)
        XCTAssertEqual(underlyingValue, "original")

        await staged.discard()
        let underlyingAfter = try await underlying.load(reference: ref)
        let stagedAfter = try await staged.load(reference: ref)
        XCTAssertEqual(underlyingAfter, "original")
        XCTAssertEqual(stagedAfter, "original")
    }

    func testStagedCommitAppliesWritesAndDeletes() async throws {
        let underlying = FakeSecretStore()
        let keep = SecretReference(id: "keep")
        let gone = SecretReference(id: "gone")
        try await underlying.save(secret: "k", for: keep)
        try await underlying.save(secret: "g", for: gone)

        let staged = StagedSecretStore(underlying: underlying)
        try await staged.save(secret: "k2", for: keep)
        try await staged.delete(reference: gone)
        let created = SecretReference(id: "created")
        try await staged.save(secret: "c", for: created)

        try await staged.commit()
        let keepValue = try await underlying.load(reference: keep)
        XCTAssertEqual(keepValue, "k2")
        let goneExists = await underlying.exists(reference: gone)
        XCTAssertFalse(goneExists)
        let createdValue = try await underlying.load(reference: created)
        XCTAssertEqual(createdValue, "c")
        let pending = await staged.hasPendingChanges
        XCTAssertFalse(pending)
    }

    func testStagedDeleteHidesExistingWithoutRemovingUntilCommit() async throws {
        let underlying = FakeSecretStore()
        let ref = SecretReference(id: "to-delete")
        try await underlying.save(secret: "secret", for: ref)

        let staged = StagedSecretStore(underlying: underlying)
        try await staged.delete(reference: ref)
        let stagedExists = await staged.exists(reference: ref)
        let underlyingExists = await underlying.exists(reference: ref)
        XCTAssertFalse(stagedExists)
        XCTAssertTrue(underlyingExists)

        await staged.discard()
        let underlyingAfter = await underlying.exists(reference: ref)
        let stagedAfter = await staged.exists(reference: ref)
        XCTAssertTrue(underlyingAfter)
        XCTAssertTrue(stagedAfter)
    }

    func testCommitReceiptRollbackRestoresUnderlyingAndRestagesEdits() async throws {
        let underlying = FakeSecretStore()
        let existing = SecretReference(id: "existing")
        let created = SecretReference(id: "created")
        try await underlying.save(secret: "original", for: existing)

        let staged = StagedSecretStore(underlying: underlying)
        try await staged.save(secret: "replacement", for: existing)
        try await staged.save(secret: "new", for: created)

        let receipt = try await staged.commitWithReceipt()
        let committedExisting = try await underlying.load(reference: existing)
        let committedCreated = try await underlying.load(reference: created)
        XCTAssertEqual(committedExisting, "replacement")
        XCTAssertEqual(committedCreated, "new")

        try await staged.rollback(receipt)
        let restoredExisting = try await underlying.load(reference: existing)
        let createdStillExists = await underlying.exists(reference: created)
        let hasPendingChanges = await staged.hasPendingChanges
        let stagedExisting = try await staged.load(reference: existing)
        let stagedCreated = try await staged.load(reference: created)
        XCTAssertEqual(restoredExisting, "original")
        XCTAssertFalse(createdStillExists)
        XCTAssertTrue(hasPendingChanges)
        XCTAssertEqual(stagedExisting, "replacement")
        XCTAssertEqual(stagedCreated, "new")
    }

    func testCommitFailureCompensatesPartialWritesAndKeepsStaging() async throws {
        let existing = SecretReference(id: "a-existing")
        let failing = SecretReference(id: "b-new")
        let underlying = InjectedFailureSecretStore(
            initial: [existing.id: "original"],
            failingSaveID: failing.id
        )
        let staged = StagedSecretStore(underlying: underlying)
        try await staged.save(secret: "replacement", for: existing)
        try await staged.save(secret: "never-committed", for: failing)

        do {
            try await staged.commit()
            XCTFail("Expected injected commit failure")
        } catch {
            // expected
        }

        let restoredExisting = try await underlying.load(reference: existing)
        let failingExists = await underlying.exists(reference: failing)
        let hasPendingChanges = await staged.hasPendingChanges
        let stagedExisting = try await staged.load(reference: existing)
        let stagedFailing = try await staged.load(reference: failing)
        XCTAssertEqual(restoredExisting, "original")
        XCTAssertFalse(failingExists)
        XCTAssertTrue(hasPendingChanges)
        XCTAssertEqual(stagedExisting, "replacement")
        XCTAssertEqual(stagedFailing, "never-committed")
    }
}

private actor InjectedFailureSecretStore: SecretStore {
    private var storage: [String: String]
    private let failingSaveID: String

    init(initial: [String: String], failingSaveID: String) {
        self.storage = initial
        self.failingSaveID = failingSaveID
    }

    func save(secret: String, for reference: SecretReference) async throws {
        if reference.id == failingSaveID {
            throw SecretStoreError.storeFailed("injected failure")
        }
        storage[reference.id] = secret
    }

    func load(reference: SecretReference) async throws -> String {
        guard let value = storage[reference.id] else {
            throw SecretStoreError.notFound
        }
        return value
    }

    func delete(reference: SecretReference) async throws {
        storage.removeValue(forKey: reference.id)
    }

    func exists(reference: SecretReference) async -> Bool {
        storage[reference.id] != nil
    }
}
