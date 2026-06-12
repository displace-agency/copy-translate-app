import Foundation
import Security

/// Minimal Keychain wrapper for the Anthropic API key. Generic-password item
/// scoped to this app's service/account.
enum Keychain {
    private static let service = "agency.displace.CopyTranslate"
    private static let account = "ANTHROPIC_API_KEY"

    static func get() -> String? {
        var query: [String: Any] = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let str = String(data: data, encoding: .utf8), !str.isEmpty else { return nil }
        return str
    }

    @discardableResult
    static func set(_ value: String) -> Bool {
        let data = Data(value.utf8)
        // Update if present, else add.
        if get() != nil {
            let attrs: [String: Any] = [kSecValueData as String: data]
            return SecItemUpdate(baseQuery as CFDictionary, attrs as CFDictionary) == errSecSuccess
        }
        var add = baseQuery
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }

    @discardableResult
    static func delete() -> Bool {
        let status = SecItemDelete(baseQuery as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
