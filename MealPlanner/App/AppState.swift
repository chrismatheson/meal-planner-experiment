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

    /// Attempts to restore a previous session using stored credentials
    @MainActor
    func tryRestoreSession() async {
        defer { isRestoringSession = false }

        // Check if we have stored credentials
        guard keychain.hasStoredCredentials else {
            print("ℹ️ No stored credentials found")
            return
        }

        let storedEmail: String
        let storedPassword: String

        do {
            storedEmail = try keychain.getEmail()
            storedPassword = try keychain.getPassword()
        } catch {
            print("ℹ️ Could not retrieve stored credentials")
            return
        }

        // First try existing token if available
        if let storedToken = try? keychain.getToken() {
            let client = PaprikaClient()
            await client.setToken(storedToken)

            // Validate token by making a test request
            do {
                _ = try await client.fetchRecipes(limit: 1)

                // Token is valid - restore session
                self.paprikaClient = client
                self.currentUser = User(email: storedEmail)
                self.isAuthenticated = true
                print("✅ Session restored from stored token")
                return
            } catch {
                print("⚠️ Stored token invalid, will re-authenticate...")
            }
        }

        // Token missing or expired - re-authenticate with stored credentials
        do {
            let client = PaprikaClient()
            let newToken = try await client.login(email: storedEmail, password: storedPassword)

            // Update stored token
            try? keychain.saveToken(newToken)

            self.paprikaClient = client
            self.currentUser = User(email: storedEmail)
            self.isAuthenticated = true
            print("✅ Session restored via re-authentication")
        } catch {
            print("❌ Re-authentication failed: \(error)")
            // Clear all credentials - user will need to login manually
            keychain.clearAll()
        }
    }

    func signIn(email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }

        let client = PaprikaClient()
        let token = try await client.login(email: email, password: password)

        // Persist all credentials for silent re-auth on next launch
        try? keychain.saveCredentials(email: email, password: password, token: token)

        self.paprikaClient = client
        currentUser = User(email: email)
        isAuthenticated = true
        print("✅ Signed in and credentials saved to Keychain")
    }

    func signOut() {
        // Clear all stored credentials
        keychain.clearAll()

        paprikaClient = nil
        currentUser = nil
        isAuthenticated = false
        print("👋 Signed out and credentials cleared")
    }
}

/// Simple user model
struct User: Identifiable {
    let id = UUID()
    let email: String
}
