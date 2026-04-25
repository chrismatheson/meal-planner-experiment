import Foundation
import Security

/// Secure storage service using iOS Keychain
/// NOTE: In simulator, Keychain requires code signing which isn't available.
/// We fall back to UserDefaults for simulator/debug builds.
final class KeychainService {
    private let service = "com.mealplanner.paprika"

    /// Last error for debugging
    static var lastError: String?

    /// Use UserDefaults fallback in simulator (Keychain requires code signing)
    private var useUserDefaultsFallback: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    private let defaults = UserDefaults.standard
    private func defaultsKey(_ key: String) -> String { "keychain_fallback_\(key)" }

    enum KeychainError: Error, LocalizedError {
        case duplicateEntry
        case unknown(OSStatus)
        case notFound
        case invalidData

        var errorDescription: String? {
            switch self {
            case .duplicateEntry: return "Duplicate entry"
            case .unknown(let status): return "Unknown keychain error: \(status)"
            case .notFound: return "Item not found"
            case .invalidData: return "Invalid data"
            }
        }
    }
    
    // MARK: - Token Storage
    
    func saveToken(_ token: String) throws {
        // Use UserDefaults fallback in simulator
        if useUserDefaultsFallback {
            defaults.set(token, forKey: defaultsKey("token"))
            print("✅ Token saved to UserDefaults (simulator fallback)")
            return
        }

        guard let data = token.data(using: .utf8) else {
            throw KeychainError.invalidData
        }

        // Delete existing token first
        try? deleteToken()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "authToken",
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            print("❌ Keychain saveToken failed with OSStatus: \(status)")
            KeychainService.lastError = "saveToken failed: OSStatus \(status)"
            throw KeychainError.unknown(status)
        }
        print("✅ Keychain saveToken succeeded")
    }
    
    func getToken() throws -> String {
        // Use UserDefaults fallback in simulator
        if useUserDefaultsFallback {
            guard let token = defaults.string(forKey: defaultsKey("token")) else {
                throw KeychainError.notFound
            }
            return token
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "token",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.notFound
            }
            throw KeychainError.unknown(status)
        }

        guard let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }

        return token
    }

    func deleteToken() throws {
        // Use UserDefaults fallback in simulator
        if useUserDefaultsFallback {
            defaults.removeObject(forKey: defaultsKey("token"))
            return
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "token"
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unknown(status)
        }
    }
    
    // MARK: - Email Storage

    func saveEmail(_ email: String) throws {
        if useUserDefaultsFallback {
            defaults.set(email, forKey: defaultsKey("email"))
            print("✅ Email saved to UserDefaults (simulator fallback)")
            return
        }

        guard let data = email.data(using: .utf8) else {
            throw KeychainError.invalidData
        }

        try? deleteEmail()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "email",
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            print("❌ Keychain saveEmail failed with OSStatus: \(status)")
            KeychainService.lastError = "saveEmail failed: OSStatus \(status)"
            throw KeychainError.unknown(status)
        }
        print("✅ Keychain saveEmail succeeded")
    }

    func getEmail() throws -> String {
        if useUserDefaultsFallback {
            guard let email = defaults.string(forKey: defaultsKey("email")) else {
                throw KeychainError.notFound
            }
            return email
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "email",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.notFound
            }
            throw KeychainError.unknown(status)
        }

        guard let data = result as? Data,
              let email = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }

        return email
    }

    func deleteEmail() throws {
        if useUserDefaultsFallback {
            defaults.removeObject(forKey: defaultsKey("email"))
            return
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "email"
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unknown(status)
        }
    }

    // MARK: - Password Storage (for silent re-authentication)

    func savePassword(_ password: String) throws {
        if useUserDefaultsFallback {
            defaults.set(password, forKey: defaultsKey("password"))
            print("✅ Password saved to UserDefaults (simulator fallback)")
            return
        }

        guard let data = password.data(using: .utf8) else {
            throw KeychainError.invalidData
        }

        try? deletePassword()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "password",
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            print("❌ Keychain savePassword failed with OSStatus: \(status)")
            KeychainService.lastError = "savePassword failed: OSStatus \(status)"
            throw KeychainError.unknown(status)
        }
        print("✅ Keychain savePassword succeeded")
    }

    func getPassword() throws -> String {
        if useUserDefaultsFallback {
            guard let password = defaults.string(forKey: defaultsKey("password")) else {
                throw KeychainError.notFound
            }
            return password
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "password",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.notFound
            }
            throw KeychainError.unknown(status)
        }

        guard let data = result as? Data,
              let password = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }

        return password
    }

    func deletePassword() throws {
        if useUserDefaultsFallback {
            defaults.removeObject(forKey: defaultsKey("password"))
            return
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "password"
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unknown(status)
        }
    }

    // MARK: - Convenience Methods

    /// Save all credentials after successful login
    func saveCredentials(email: String, password: String, token: String) throws {
        try saveEmail(email)
        try savePassword(password)
        try saveToken(token)
    }

    /// Clear all stored credentials on sign out
    func clearAll() {
        try? deleteEmail()
        try? deletePassword()
        try? deleteToken()
    }

    /// Check if we have stored credentials for silent re-auth
    var hasStoredCredentials: Bool {
        do {
            _ = try getEmail()
            _ = try getPassword()
            return true
        } catch {
            return false
        }
    }
}
