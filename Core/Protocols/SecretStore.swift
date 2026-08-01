import Foundation

public enum SecretStoreError: Error, Equatable, LocalizedError {
    case notFound
    case encodingFailed
    case storeFailed(String)
    case deleteFailed(String)

    public var errorDescription: String? {
        switch self {
        case .notFound: return "Secret not found."
        case .encodingFailed: return "Could not encode secret."
        case .storeFailed(let m): return "Could not store secret: \(m)"
        case .deleteFailed(let m): return "Could not delete secret: \(m)"
        }
    }
}

/// Stores opaque secret values keyed by SecretReference.id. Never logs values.
public protocol SecretStore: Sendable {
    func save(secret: String, for reference: SecretReference) async throws
    func load(reference: SecretReference) async throws -> String
    func delete(reference: SecretReference) async throws
    func exists(reference: SecretReference) async -> Bool
}
