import XCTest
@testable import paprikaplanner

/// Integration tests that hit the REAL Paprika API
/// These tests require valid credentials to pass
/// 
/// To run: Set environment variables PAPRIKA_TEST_EMAIL and PAPRIKA_TEST_PASSWORD
final class PaprikaIntegrationTests: XCTestCase {
    
    // MARK: - Test Configuration

    private var testEmail: String? {
        ProcessInfo.processInfo.environment["PAPRIKA_TEST_EMAIL"]
    }

    private var testPassword: String? {
        ProcessInfo.processInfo.environment["PAPRIKA_TEST_PASSWORD"]
    }

    private var hasValidCredentials: Bool {
        testEmail?.isEmpty == false && testPassword?.isEmpty == false
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
    /// Only runs if PAPRIKA_TEST_EMAIL and PAPRIKA_TEST_PASSWORD are set
    func test_login_withValidCredentials_returnsToken() async throws {
        try XCTSkipUnless(hasValidCredentials, "Skipping: No valid Paprika credentials configured")
        let email = try XCTUnwrap(testEmail)
        let password = try XCTUnwrap(testPassword)

        let client = PaprikaClient()

        let token = try await client.login(email: email, password: password)

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
        let email = try XCTUnwrap(testEmail)
        let password = try XCTUnwrap(testPassword)

        let client = PaprikaClient()

        // First login
        _ = try await client.login(email: email, password: password)

        // Then fetch recipes
        let recipes = try await client.fetchRecipes()

        print("✅ Fetched \(recipes.count) recipes")
        // User may have 0 recipes, so just verify no crash
    }

    // MARK: - Meal Plan Write-back Tests

    /// Tests that we can save a meal to Paprika using v1 sync API
    func test_saveMealItem_createsNewMealInPaprika() async throws {
        try XCTSkipUnless(hasValidCredentials, "Skipping: No valid Paprika credentials configured")
        let email = try XCTUnwrap(testEmail)
        let password = try XCTUnwrap(testPassword)

        let client = PaprikaClient()

        // Login first (this sets up both Bearer token and Basic Auth)
        _ = try await client.login(email: email, password: password)

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

    /// Tests that saving a meal with the SAME UID updates it (no duplicates)
    /// BUG FIX: Previously, every sync created new meals with new UIDs
    func test_saveMeal_withSameUid_updatesInsteadOfCreatingDuplicate() async throws {
        try XCTSkipUnless(hasValidCredentials, "Skipping: No valid Paprika credentials configured")
        let email = try XCTUnwrap(testEmail)
        let password = try XCTUnwrap(testPassword)

        let client = PaprikaClient()
        _ = try await client.login(email: email, password: password)

        // Get two different recipes
        let recipes = try await client.fetchRecipes(limit: 2)
        guard recipes.count >= 2 else {
            throw XCTSkip("Need at least 2 recipes to test update behavior")
        }
        let recipe1 = recipes[0]
        let recipe2 = recipes[1]

        // Create a test date (far in future to avoid conflicts)
        let testDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateStr = dateFormatter.string(from: testDate)

        // Use a proper UUID format (Paprika requires valid UUIDs)
        let fixedUid = UUID().uuidString.uppercased()

        // Save first meal
        let meal1 = PaprikaMeal(uid: fixedUid, date: testDate, recipe: recipe1, type: 2)
        try await client.saveMeals([meal1])
        print("📝 Saved first meal: \(recipe1.name)")

        // Count meals for this date BEFORE update
        let mealsBefore = try await client.fetchMeals()
        let mealsForDateBefore = mealsBefore.filter { $0.date.hasPrefix(dateStr) && $0.type == 2 }
        let countBefore = mealsForDateBefore.count
        print("📊 Meals for \(dateStr) before update: \(countBefore)")

        // Save second meal with SAME UID (should update, not create new)
        let meal2 = PaprikaMeal(uid: fixedUid, date: testDate, recipe: recipe2, type: 2)
        try await client.saveMeals([meal2])
        print("📝 Updated to second meal: \(recipe2.name)")

        // Count meals for this date AFTER update
        let mealsAfter = try await client.fetchMeals()
        let mealsForDateAfter = mealsAfter.filter { $0.date.hasPrefix(dateStr) && $0.type == 2 }
        let countAfter = mealsForDateAfter.count

        print("📊 Meals for \(dateStr) after update: \(countAfter)")

        // CRITICAL: Count should NOT increase - this verifies no duplicates
        XCTAssertEqual(countBefore, countAfter, "Updating a meal should not create duplicates!")

        // Verify the meal was actually updated
        let updatedMeal = mealsAfter.first { $0.uid == fixedUid }
        XCTAssertNotNil(updatedMeal, "Meal should still exist")
        XCTAssertEqual(updatedMeal?.name, recipe2.name, "Meal name should be updated to new recipe")

        // Clean up
        if let mealToDelete = updatedMeal {
            try await client.deleteMeal(mealToDelete)
            print("🧹 Cleaned up test meal")
        }
    }

    /// Debug test: List all meals in Paprika with their dates
    func test_debug_listAllMeals() async throws {
        try XCTSkipUnless(hasValidCredentials, "Skipping: No valid Paprika credentials configured")
        let email = try XCTUnwrap(testEmail)
        let password = try XCTUnwrap(testPassword)

        let client = PaprikaClient()
        _ = try await client.login(email: email, password: password)

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

    /// CLEANUP UTILITY: Remove duplicate meals, keeping only one per date/type
    /// Run this manually after fixing the duplicate bug
    func test_cleanup_duplicateMeals() async throws {
        try XCTSkipUnless(hasValidCredentials, "Skipping: No valid Paprika credentials configured")
        let email = try XCTUnwrap(testEmail)
        let password = try XCTUnwrap(testPassword)

        let client = PaprikaClient()
        _ = try await client.login(email: email, password: password)

        let meals = try await client.fetchMeals()
        print("📋 Found \(meals.count) total meals")

        // Group by date+type, keeping only the first one
        var seenDateTypes: Set<String> = []
        var toDelete: [PaprikaMeal] = []

        for meal in meals {
            let dateOnly = String(meal.date.prefix(10))
            let key = "\(dateOnly)-\(meal.type)"

            if seenDateTypes.contains(key) {
                // This is a duplicate
                toDelete.append(meal)
            } else {
                seenDateTypes.insert(key)
            }
        }

        print("🗑️ Found \(toDelete.count) duplicate meals to delete")

        // Delete duplicates in batches
        for meal in toDelete {
            print("   Deleting: \(meal.date) | \(meal.name)")
            try await client.deleteMeal(meal)
        }

        // Verify
        let mealsAfter = try await client.fetchMeals()
        print("✅ After cleanup: \(mealsAfter.count) meals remaining")
    }
}
