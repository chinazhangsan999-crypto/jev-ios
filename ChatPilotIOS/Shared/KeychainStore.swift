import Foundation
import Security

enum KeychainStore {
    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "ChatPilot.ProviderKey",
         kSecAttrAccount as String: "api-key",
         kSecAttrAccessGroup as String: Bundle.main.object(forInfoDictionaryKey: "KeychainGroup") as? String ?? ""]
    }

    static func save(_ key: String) throws {
        let cleaned = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, let data = cleaned.data(using: .utf8) else { throw PilotError.missingKey }
        let changes: [String: Any] = [kSecValueData as String: data,
                                     kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        var status = SecItemUpdate(query as CFDictionary, changes as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            changes.forEach { item[$0.key] = $0.value }
            status = SecItemAdd(item as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw PilotError.keychain(status) }
    }

    static func load() throws -> String {
        var item = query
        item[kSecReturnData as String] = true
        item[kSecMatchLimit as String] = kSecMatchLimitOne
        var output: CFTypeRef?
        let status = SecItemCopyMatching(item as CFDictionary, &output)
        guard status == errSecSuccess else {
            if status == errSecItemNotFound { throw PilotError.missingKey }
            throw PilotError.keychain(status)
        }
        guard let data = output as? Data, let key = String(data: data, encoding: .utf8) else { throw PilotError.missingKey }
        return key
    }

    static func delete() { SecItemDelete(query as CFDictionary) }
}
