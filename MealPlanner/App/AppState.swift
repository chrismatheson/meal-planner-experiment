import Foundation
import SwiftUI

/// Global application state
@Observable
final class AppState {
    var isAuthenticated: Bool = false
    var isLoading: Bool = false
    var currentUser: User?
    var paprikaClient: PaprikaClient?
    
    init() {
        // No persistent auth for now - user must login each session
        // TODO: Add Keychain persistence once app is properly signed
    }
    
    func signIn(email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        let client = PaprikaClient()
        let token = try await client.login(email: email, password: password)
        
        self.paprikaClient = client
        currentUser = User(email: email)
        isAuthenticated = true
    }
    
    func signOut() {
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
