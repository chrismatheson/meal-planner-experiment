import Foundation
import SwiftUI

/// Global application state
@Observable
final class AppState {
    var isAuthenticated: Bool = false
    var isLoading: Bool = false
    var isRestoringSession: Bool = true  // True until we've checked for stored session
    var currentUser: User?
    var paprikaClient: PaprikaClient?

    private let keychain = KeychainService()

    init() {
        // Try to restore session from Keychain on launch
        Task { @MainActor in
            await tryRestoreSession()
        }
    }

    /// Attempts to restore a previous session using stored token
    @MainActor
    func tryRestoreSession() async {
        defer { isRestoringSession = false }

        // Try to get stored credentials
        let storedToken: String
        let storedEmail: String

        do {
            storedToken = try keychain.getToken()
            storedEmail = try keychain.getEmail()
        } catch {
            // No stored credentials - user needs to login
            print("ℹ️ No stored session found")
            return
        }

        // Create client with stored token
        let client = PaprikaClient()
        await client.setToken(storedToken)

        // Validate token by making a test request
        // If this fails, the token is expired
        do {
            _ = try await client.fetchRecipes(limit: 1)

            // Token is valid - restore session
            self.paprikaClient = client
            self.currentUser = User(email: storedEmail)
            self.isAuthenticated = true
            print("✅ Session restored from Keychain")
        } catch {
            // Token invalid or expired - clear it
            print("⚠️ Stored session invalid: \(error)")
            try? keychain.deleteToken()
            try? keychain.deleteEmail()
        }
    }

    func signIn(email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }

        let client = PaprikaClient()
        let token = try await client.login(email: email, password: password)

        // Persist token and email for next launch
        try? keychain.saveToken(token)
        try? keychain.saveEmail(email)

        self.paprikaClient = client
        currentUser = User(email: email)
        isAuthenticated = true
    }

    func signOut() {
        // Clear stored credentials
        try? keychain.deleteToken()
        try? keychain.deleteEmail()

        paprikaClient = nil
        currentUser = nil
        isAuthenticated = false
    }
}

/// Simple user model
struct User: Identifiable {
    let id = UUID()
    let email: String
}
