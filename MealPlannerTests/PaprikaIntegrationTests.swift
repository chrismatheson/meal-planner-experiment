import XCTest
@testable import MealPlanner

/// Integration tests that hit the REAL Paprika API
/// These tests require valid credentials to pass
/// 
/// To run: Set environment variables PAPRIKA_EMAIL and PAPRIKA_PASSWORD
/// or update the testCredentials below for local testing (don't commit real creds!)
final class PaprikaIntegrationTests: XCTestCase {
    
    // MARK: - Test Configuration
    
    /// Set these for local testing (DO NOT COMMIT REAL CREDENTIALS)
    /// Or use environment variables: PAPRIKA_EMAIL, PAPRIKA_PASSWORD
    private var testEmail: String {
        ProcessInfo.processInfo.environment["PAPRIKA_EMAIL"] ?? "your-test-email@example.com"
    }
    
    private var testPassword: String {
        ProcessInfo.processInfo.environment["PAPRIKA_PASSWORD"] ?? "your-test-password"
    }
    
    private var hasValidCredentials: Bool {
        testEmail != "your-test-email@example.com" && testPassword != "your-test-password"
    }
    
    // MARK: - Integration Tests
    
    /// Verifies that our API client can connect to Paprika servers
    /// This test would have caught the User-Agent issue!
    func test_apiConnection_withUserAgent_isAccepted() async throws {
        // This test verifies we're not rejected as "Unrecognized client"
        let client = PaprikaClient(keychain: MockKeychainService())
        
        // Even with invalid credentials, we should get "invalid credentials"
        // NOT "Unrecognized client" (which means User-Agent is wrong)
        do {
            _ = try await client.login(email: "invalid@test.com", password: "invalid")
            XCTFail("Should have thrown an error")
        } catch let error as PaprikaError {
            // We expect invalidCredentials or similar - NOT a generic decoding error
            // If we get a decoding error, it likely means the API rejected us entirely
            switch error {
            case .invalidCredentials:
                // Good - API recognized us as a valid client, just wrong creds
                break
            case .serverError(let code):
                // 401/403 is expected for bad creds
                XCTAssertTrue([401, 403].contains(code), "Unexpected server error: \(code)")
            default:
                XCTFail("Unexpected error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    /// Tests login with valid credentials
    /// Only runs if PAPRIKA_EMAIL and PAPRIKA_PASSWORD are set
    func test_login_withValidCredentials_returnsToken() async throws {
        try XCTSkipUnless(hasValidCredentials, "Skipping: No valid Paprika credentials configured")
        
        let client = PaprikaClient(keychain: MockKeychainService())
        
        let token = try await client.login(email: testEmail, password: testPassword)
        
        XCTAssertFalse(token.isEmpty, "Token should not be empty")
        print("✅ Successfully logged in, token length: \(token.count)")
    }
    
    /// Tests that invalid credentials fail gracefully
    func test_login_withInvalidCredentials_throwsInvalidCredentials() async throws {
        let client = PaprikaClient(keychain: MockKeychainService())
        
        do {
            _ = try await client.login(email: "invalid@example.com", password: "wrongpassword")
            XCTFail("Should have thrown invalidCredentials error")
        } catch PaprikaError.invalidCredentials {
            // Expected
        } catch PaprikaError.serverError(let code) where code == 401 || code == 403 {
            // Also acceptable
        }
    }
    
    /// Tests fetching recipes after successful login
    func test_fetchRecipes_afterLogin_returnsRecipes() async throws {
        try XCTSkipUnless(hasValidCredentials, "Skipping: No valid Paprika credentials configured")
        
        let keychain = MockKeychainService()
        let client = PaprikaClient(keychain: keychain)
        
        // First login
        _ = try await client.login(email: testEmail, password: testPassword)
        
        // Then fetch recipes
        let recipes = try await client.fetchRecipes()
        
        print("✅ Fetched \(recipes.count) recipes")
        // User may have 0 recipes, so just verify no crash
    }
}

// MARK: - Mock Keychain for Testing

private class MockKeychainService: KeychainService {
    private var storedToken: String?
    
    override func saveToken(_ token: String) throws {
        storedToken = token
    }
    
    override func getToken() throws -> String {
        guard let token = storedToken else {
            throw KeychainError.notFound
        }
        return token
    }
    
    override func deleteToken() throws {
        storedToken = nil
    }
}
