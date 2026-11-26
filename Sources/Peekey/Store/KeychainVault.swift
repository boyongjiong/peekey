import Foundation
import Security

/// Stores the whole account vault as a single generic-password item in the login keychain.
enum KeychainVault {
    private static let service = "app.peekey.mac.vault"
    private static let account = "accounts"

    enum VaultError: LocalizedError {
        case status(OSStatus)
        var errorDescription: String? {
            if case .status(let s) = self {
                let msg = SecCopyErrorMessageString(s, nil) as String? ?? "未知错误"
                return "钥匙串错误 (\(s))：\(msg)"
            }
            return nil
        }
    }

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    static func load() throws -> Data? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw VaultError.status(status) }
        return result as? Data
    }

    static func save(_ data: Data) throws {
        let attrs: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
        ]
        var status = SecItemUpdate(baseQuery as CFDictionary, attrs as CFDictionary)
        if status == errSecItemNotFound {
            var add = baseQuery
            add.merge(attrs) { $1 }
            add[kSecAttrLabel as String] = "Peekey 2FA Vault"
            status = SecItemAdd(add as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw VaultError.status(status) }
    }
}
