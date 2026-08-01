import Foundation
import Security

/// Keychain-backed secret store. Uses AfterFirstUnlockThisDeviceOnly for background exports.
/// Never logs secret values. Prefers SecItemUpdate so a failed replacement does not delete first.
struct KeychainSecretStore: SecretStore {
    private let service: String

    init(service: String = "com.shersingh7.openhealth.secrets") {
        self.service = service
    }

    func save(secret: String, for reference: SecretReference) async throws {
        guard let data = secret.data(using: .utf8) else {
            throw SecretStoreError.encodingFailed
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: reference.id
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }
        if updateStatus == errSecItemNotFound {
            var add = query
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(add as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw SecretStoreError.storeFailed("status \(addStatus)")
            }
            return
        }
        throw SecretStoreError.storeFailed("status \(updateStatus)")
    }

    func load(reference: SecretReference) async throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: reference.id,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data, let string = String(data: data, encoding: .utf8) else {
            if status == errSecItemNotFound {
                throw SecretStoreError.notFound
            }
            throw SecretStoreError.storeFailed("status \(status)")
        }
        return string
    }

    func delete(reference: SecretReference) async throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: reference.id
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SecretStoreError.deleteFailed("status \(status)")
        }
    }

    func exists(reference: SecretReference) async -> Bool {
        (try? await load(reference: reference)) != nil
    }
}
