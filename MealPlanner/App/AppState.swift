import Foundation
import SwiftUI

/// Global application state
@Observable
final class AppState {
    var isAuthenticated: Bool = false
    var isLoading: Bool = false
    var currentUser: User?
    
    private let keychainService = KeychainService()
    
    init() {
        // Check if we have a stored token on launch
        if let token = try? keychainService.getToken() {
            isAuthenticated = true
        }
    }
    
    func signIn(email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        let client = PaprikaClient(keychain: keychainService)
        let token = try await client.login(email: email, password: password)
        
        currentUser = User(email: email)
        isAuthenticated = true
    }
    
    func signOut() {
        try? keychainService.deleteToken()
        currentUser = nil
        isAuthenticated = false
    }
}

/// Simple user model
struct User: Identifiable {
    let id = UUID()
    let email: String
}
