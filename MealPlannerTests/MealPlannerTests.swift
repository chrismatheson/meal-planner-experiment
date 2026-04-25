import XCTest
import SwiftUI
@testable import MealPlanner

final class MealPlannerTests: XCTestCase {
    
    // MARK: - PaprikaRecipe Tests
    
    func testRecipeDecoding() throws {
        let json = """
        {
            "uid": "test-123",
            "name": "Test Recipe",
            "ingredients": "1 cup flour",
            "directions": "Mix and bake",
            "prep_time": "10 min",
            "cook_time": "30 min",
            "total_time": "40 min",
            "rating": 5,
            "categories": ["Dinner", "Quick"],
            "on_favorites": true
        }
        """.data(using: .utf8)!
        
        let recipe = try JSONDecoder().decode(PaprikaRecipe.self, from: json)
        
        XCTAssertEqual(recipe.uid, "test-123")
        XCTAssertEqual(recipe.name, "Test Recipe")
        XCTAssertEqual(recipe.prepTime, "10 min")
        XCTAssertEqual(recipe.cookTime, "30 min")
        XCTAssertEqual(recipe.totalTime, "40 min")
        XCTAssertEqual(recipe.rating, 5)
        XCTAssertEqual(recipe.categories, ["Dinner", "Quick"])
        XCTAssertEqual(recipe.onFavorites, true)
    }
    
    func testRecipeDisplayTime() throws {
        let json = """
        {"uid": "1", "name": "Test", "total_time": "1 hour"}
        """.data(using: .utf8)!
        
        let recipe = try JSONDecoder().decode(PaprikaRecipe.self, from: json)
        XCTAssertEqual(recipe.displayTime, "1 hour")
    }
    
    func testRecipeDisplayTimeFallback() throws {
        let json = """
        {"uid": "1", "name": "Test", "cook_time": "30 min"}
        """.data(using: .utf8)!
        
        let recipe = try JSONDecoder().decode(PaprikaRecipe.self, from: json)
        XCTAssertEqual(recipe.displayTime, "30 min")
    }
    
    // MARK: - MealItem Tests
    
    func testMealItemDecoding() throws {
        let json = """
        {
            "uid": "meal-123",
            "recipe_uid": "recipe-456",
            "date": "2024-01-15",
            "order_flag": 0,
            "name": "Pasta Night"
        }
        """.data(using: .utf8)!
        
        let item = try JSONDecoder().decode(PaprikaMealItem.self, from: json)
        
        XCTAssertEqual(item.uid, "meal-123")
        XCTAssertEqual(item.recipeUid, "recipe-456")
        XCTAssertEqual(item.date, "2024-01-15")
        XCTAssertEqual(item.name, "Pasta Night")
    }
    
    func testMealItemDateParsing() throws {
        let json = """
        {"uid": "1", "date": "2024-03-20", "order_flag": 0, "name": "Test"}
        """.data(using: .utf8)!
        
        let item = try JSONDecoder().decode(PaprikaMealItem.self, from: json)
        
        let date = item.dateValue
        XCTAssertNotNil(date)
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date!)
        XCTAssertEqual(components.year, 2024)
        XCTAssertEqual(components.month, 3)
        XCTAssertEqual(components.day, 20)
    }
    
    // MARK: - Color Extension Tests

    func testColorHexInitialization() {
        // Just verify it doesn't crash
        let color = Color(hex: "D94A3A")
        XCTAssertNotNil(color)

        let color2 = Color(hex: "#8D0227")
        XCTAssertNotNil(color2)
    }

    // MARK: - Keychain Tests

    func testKeychainService_saveAndRetrieveCredentials() throws {
        let keychain = KeychainService()

        // Clean up first
        keychain.clearAll()

        // Save credentials
        try keychain.saveCredentials(
            email: "test@example.com",
            password: "testpassword123",
            token: "testtoken456"
        )

        // Verify hasStoredCredentials
        XCTAssertTrue(keychain.hasStoredCredentials, "Should have stored credentials")

        // Retrieve and verify
        XCTAssertEqual(try keychain.getEmail(), "test@example.com")
        XCTAssertEqual(try keychain.getPassword(), "testpassword123")
        XCTAssertEqual(try keychain.getToken(), "testtoken456")

        // Clean up
        keychain.clearAll()

        // Verify cleared
        XCTAssertFalse(keychain.hasStoredCredentials, "Credentials should be cleared")
    }

    func testKeychainService_persistsAcrossInstances() throws {
        // Save with one instance
        let keychain1 = KeychainService()
        keychain1.clearAll()
        try keychain1.saveCredentials(
            email: "persist@test.com",
            password: "persistpass",
            token: "persisttoken"
        )

        // Retrieve with a NEW instance (simulates app relaunch)
        let keychain2 = KeychainService()

        XCTAssertTrue(keychain2.hasStoredCredentials, "New instance should see stored credentials")
        XCTAssertEqual(try keychain2.getEmail(), "persist@test.com")
        XCTAssertEqual(try keychain2.getPassword(), "persistpass")
        XCTAssertEqual(try keychain2.getToken(), "persisttoken")

        // Clean up
        keychain2.clearAll()
    }
}
