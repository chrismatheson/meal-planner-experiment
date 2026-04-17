import XCTest

/// UI Tests that verify the actual app works end-to-end
/// These tests MUST pass before any release
/// 
/// Set environment variables for testing:
/// - PAPRIKA_TEST_EMAIL
/// - PAPRIKA_TEST_PASSWORD
final class MealPlannerUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        
        // Pass test credentials via environment
        if let email = ProcessInfo.processInfo.environment["PAPRIKA_TEST_EMAIL"],
           let password = ProcessInfo.processInfo.environment["PAPRIKA_TEST_PASSWORD"] {
            app.launchEnvironment["PAPRIKA_TEST_EMAIL"] = email
            app.launchEnvironment["PAPRIKA_TEST_PASSWORD"] = password
        }
        
        app.launch()
    }
    
    // MARK: - Critical Path Tests (MUST PASS)
    
    /// Verifies the app launches and shows login screen
    func test_appLaunch_showsLoginScreen() {
        // Given: App is launched
        // Then: Login screen is visible
        XCTAssertTrue(app.staticTexts["Sign in with your Paprika sync account"].exists)
        XCTAssertTrue(app.textFields["Email"].exists)
        XCTAssertTrue(app.secureTextFields["Password"].exists)
        XCTAssertTrue(app.buttons["Sign In"].exists)
    }
    
    /// Verifies login button is disabled with empty fields
    func test_loginButton_disabledWhenFieldsEmpty() {
        let signInButton = app.buttons["Sign In"]
        XCTAssertFalse(signInButton.isEnabled)
    }
    
    /// Verifies login button enables when fields have content
    func test_loginButton_enablesWithContent() {
        app.textFields["Email"].tap()
        app.textFields["Email"].typeText("test@example.com")
        
        app.secureTextFields["Password"].tap()
        app.secureTextFields["Password"].typeText("password")
        
        XCTAssertTrue(app.buttons["Sign In"].isEnabled)
    }
    
    /// Verifies invalid credentials show error (not crash)
    func test_login_withInvalidCredentials_showsError() {
        app.textFields["Email"].tap()
        app.textFields["Email"].typeText("invalid@test.com")
        
        app.secureTextFields["Password"].tap()
        app.secureTextFields["Password"].typeText("wrongpassword")
        
        app.buttons["Sign In"].tap()
        
        // Wait for error alert
        let alert = app.alerts["Sign In Error"]
        XCTAssertTrue(alert.waitForExistence(timeout: 10))
        
        // Dismiss alert
        alert.buttons["OK"].tap()
        
        // Still on login screen
        XCTAssertTrue(app.staticTexts["Sign in with your Paprika sync account"].exists)
    }
    
    /// Verifies valid credentials navigate to recipes
    /// REQUIRES: PAPRIKA_TEST_EMAIL and PAPRIKA_TEST_PASSWORD env vars
    func test_login_withValidCredentials_showsRecipeList() throws {
        guard let email = ProcessInfo.processInfo.environment["PAPRIKA_TEST_EMAIL"],
              let password = ProcessInfo.processInfo.environment["PAPRIKA_TEST_PASSWORD"] else {
            throw XCTSkip("Test credentials not configured")
        }
        
        app.textFields["Email"].tap()
        app.textFields["Email"].typeText(email)
        
        app.secureTextFields["Password"].tap()
        app.secureTextFields["Password"].typeText(password)
        
        app.buttons["Sign In"].tap()
        
        // Wait for navigation to complete
        let recipesNav = app.navigationBars["Recipes"]
        XCTAssertTrue(recipesNav.waitForExistence(timeout: 15), 
                      "Should navigate to Recipes screen after login")
    }
    
    /// Full happy path: login → see recipes → go to meal plan
    func test_fullHappyPath_loginToMealPlan() throws {
        guard let email = ProcessInfo.processInfo.environment["PAPRIKA_TEST_EMAIL"],
              let password = ProcessInfo.processInfo.environment["PAPRIKA_TEST_PASSWORD"] else {
            throw XCTSkip("Test credentials not configured")
        }
        
        // Login
        app.textFields["Email"].tap()
        app.textFields["Email"].typeText(email)
        app.secureTextFields["Password"].tap()
        app.secureTextFields["Password"].typeText(password)
        app.buttons["Sign In"].tap()
        
        // Wait for recipes
        XCTAssertTrue(app.navigationBars["Recipes"].waitForExistence(timeout: 15))
        
        // Navigate to Meal Plan
        app.tabBars.buttons["Meal Plan"].tap()
        XCTAssertTrue(app.navigationBars["Meal Plan"].waitForExistence(timeout: 5))
        
        // Verify we can see the week view
        XCTAssertTrue(app.staticTexts["Today"].exists || app.buttons["Today"].exists)
    }
}
