import XCTest
@testable import paprikaplanner

/// Integration tests that hit the REAL Paprika API
/// These tests require valid credentials to pass
/// 
/// To run: Set environment variables PAPRIKA_EMAIL and PAPRIKA_PASSWORD
/// or update the testCredentials below for local testing (don't commit real creds!)
final class PaprikaIntegrationTests: XCTestCase {
    
    // MARK: - Test Configuration

    /// Test credentials - these are for a test account only
    /// In a real project, use a secrets management solution
    private let testEmail = "blackhole@mailinator.com"
    private let testPassword = "cessuh-xawtig-xIbpa2"

    private var hasValidCredentials: Bool {
        !testEmail.isEmpty && !testPassword.isEmpty
    }
    
    // MARK: - Integration Tests
    
    /// Verifies that our API client can connect to Paprika servers
    /// This test would have caught the User-Agent issue!
    func test_apiConnection_withUserAgent_isAccepted() async throws {
        // This test verifies we're not rejected as "Unrecognized client"
        let client = PaprikaClient()

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

        let client = PaprikaClient()

        let token = try await client.login(email: testEmail, password: testPassword)

        XCTAssertFalse(token.isEmpty, "Token should not be empty")
        print("✅ Successfully logged in, token length: \(token.count)")
    }

    /// Tests that invalid credentials fail gracefully
    func test_login_withInvalidCredentials_throwsInvalidCredentials() async throws {
        let client = PaprikaClient()
        
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

        let client = PaprikaClient()

        // First login
        _ = try await client.login(email: testEmail, password: testPassword)

        // Then fetch recipes
        let recipes = try await client.fetchRecipes()

        print("✅ Fetched \(recipes.count) recipes")
        // User may have 0 recipes, so just verify no crash
    }

    // MARK: - Meal Plan Write-back Tests

    /// Tests that we can save a meal to Paprika using v1 sync API
    func test_saveMealItem_createsNewMealInPaprika() async throws {
        try XCTSkipUnless(hasValidCredentials, "Skipping: No valid Paprika credentials configured")

        let client = PaprikaClient()

        // Login first (this sets up both Bearer token and Basic Auth)
        _ = try await client.login(email: testEmail, password: testPassword)

        // Get a recipe to assign
        let recipes = try await client.fetchRecipes(limit: 1)
        guard let recipe = recipes.first else {
            throw XCTSkip("No recipes available to test with")
        }

        // Create a meal for tomorrow (to avoid messing with today's plan)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let meal = PaprikaMeal(date: tomorrow, recipe: recipe, type: 2) // 2 = Dinner

        print("📝 Saving meal: \(meal.name) for \(meal.date) (uid: \(meal.uid.prefix(8))...)")

        // Save it using v1 sync API with gzip
        try await client.saveMeals([meal])

        // Verify by fetching meals back
        let meals = try await client.fetchMeals()
        let savedMeal = meals.first { $0.uid == meal.uid }

        XCTAssertNotNil(savedMeal, "Meal should be saved to Paprika")
        XCTAssertEqual(savedMeal?.name, recipe.name)
        XCTAssertEqual(savedMeal?.date, meal.date)

        print("✅ Successfully saved meal: \(recipe.name) for \(meal.date)")

        // Clean up - delete the test meal
        try await client.deleteMeal(savedMeal!)

        // Verify deletion
        let mealsAfterDelete = try await client.fetchMeals()
        let deletedMeal = mealsAfterDelete.first { $0.uid == meal.uid }
        XCTAssertNil(deletedMeal, "Meal should be deleted from Paprika")
        print("🧹 Cleaned up test meal")
    }

    /// Debug test: List all meals in Paprika with their dates
    func test_debug_listAllMeals() async throws {
        try XCTSkipUnless(hasValidCredentials, "Skipping: No valid Paprika credentials configured")

        let client = PaprikaClient()
        _ = try await client.login(email: testEmail, password: testPassword)

        let meals = try await client.fetchMeals()
        print("📋 All meals in Paprika (\(meals.count) total):")

        let sortedMeals = meals.sorted { $0.date < $1.date }
        for meal in sortedMeals {
            let weekInfo: String
            if let date = meal.dateValue {
                let cal = Calendar(identifier: .iso8601)
                let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
                weekInfo = "Week \(comps.weekOfYear ?? 0)"
            } else {
                weekInfo = "???"
            }
            print("   \(meal.date) | \(weekInfo) | \(meal.name)")
        }
    }
}
