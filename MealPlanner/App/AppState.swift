import Foundation
import SwiftUI

/// Global application state
@Observable
final class AppState {
    var isAuthenticated: Bool = false
    var isLoading: Bool = false
    var isRestoringSession: Bool = true  // True until we've checked for stored session
    var isOfflineMode: Bool = false      // True when authenticated via cache (no network)
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
    /// Supports offline-first: if we have credentials AND cached data, allow access even without network
    @MainActor
    func tryRestoreSession() async {
        defer { isRestoringSession = false }

        print("🔑 Checking for stored credentials...")

        // Check if we have stored credentials
        guard keychain.hasStoredCredentials else {
            print("ℹ️ No stored credentials found (hasStoredCredentials = false)")
            return
        }

        print("🔑 Found stored credentials, attempting restore...")

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
                self.isOfflineMode = false
                print("✅ Session restored from stored token")
                return
            } catch {
                print("⚠️ Stored token invalid or offline, will try re-auth...")
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
            self.isOfflineMode = false
            print("✅ Session restored via re-authentication")
        } catch {
            // OFFLINE-FIRST: If we have credentials AND cached data, allow offline access
            if hasCachedData {
                print("📶 Offline with cached data - allowing offline access")
                self.currentUser = User(email: storedEmail)
                self.isAuthenticated = true
                self.isOfflineMode = true
                // paprikaClient stays nil - views will use cached data
            } else {
                print("❌ Re-authentication failed and no cached data: \(error)")
                // Only clear credentials if we have no cached data to show
                keychain.clearAll()
            }
        }
    }

    /// Check if we have cached data that can be shown offline
    private var hasCachedData: Bool {
        // Check if we've ever synced recipes or meals
        let syncManager = SyncStatusManager.shared
        return syncManager.lastRecipeSyncTime != nil || syncManager.lastMealSyncTime != nil
    }

    func signIn(email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }

        let client = PaprikaClient()
        let token = try await client.login(email: email, password: password)

        // Persist all credentials for silent re-auth on next launch
        do {
            try keychain.saveCredentials(email: email, password: password, token: token)
            print("✅ Credentials saved to Keychain")
            KeychainService.lastError = nil
        } catch {
            print("❌ Failed to save credentials to Keychain: \(error)")
            KeychainService.lastError = error.localizedDescription
        }

        self.paprikaClient = client
        currentUser = User(email: email)
        isAuthenticated = true
        print("✅ Signed in successfully")
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
