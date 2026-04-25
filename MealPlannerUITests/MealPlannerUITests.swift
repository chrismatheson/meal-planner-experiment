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

    // MARK: - Session Persistence Tests

    // Test credentials (same as integration tests)
    private let testEmail = "blackhole@mailinator.com"
    private let testPassword = "cessuh-xawtig-xIbpa2"

    /// Verifies that after signing in, session persists when app goes to background and returns
    /// NOTE: UI test terminate/launch reinstalls app, wiping keychain. We test background/foreground instead.
    func test_sessionPersistence_afterLogin_relaunchSkipsLogin() throws {
        // Check initial keychain status
        let keychainStatus = app.staticTexts["KeychainStatus"]
        if keychainStatus.waitForExistence(timeout: 3) {
            print("🔍 Initial keychain status: \(keychainStatus.label)")
        }

        // First sign in
        app.textFields["Email"].tap()
        app.textFields["Email"].typeText(testEmail)
        app.secureTextFields["Password"].tap()
        app.secureTextFields["Password"].typeText(testPassword)
        app.buttons["Sign In"].tap()

        // Wait for successful login - should see tab bar
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15),
                      "Should see tab bar after login")

        // Wait a moment for keychain to be written
        sleep(2)

        // Verify we're signed in by checking for tab bar
        XCTAssertTrue(app.tabBars.firstMatch.exists, "Should be logged in with tab bar visible")

        // Background the app (simulates user pressing home)
        XCUIDevice.shared.press(.home)
        sleep(2)

        // Bring app back to foreground (simulates user tapping app icon)
        app.activate()
        sleep(1)

        // Should still be logged in - tab bar should still be visible
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5),
                      "Tab bar should still exist after returning from background")

        // Verify keychain was written by going to Settings and checking email
        app.tabBars.buttons["Settings"].tap()
        sleep(1)

        // The settings screen should show the logged-in email
        XCTAssertTrue(app.staticTexts[testEmail].waitForExistence(timeout: 3),
                      "Should see logged-in email in Settings - confirms session persists")
    }

    // MARK: - Plan Generation Tests

    /// Verifies that after generating a plan, countdown timer appears in toolbar
    func test_planGeneration_showsCountdownTimer() throws {
        // Login
        app.textFields["Email"].tap()
        app.textFields["Email"].typeText(testEmail)
        app.secureTextFields["Password"].tap()
        app.secureTextFields["Password"].typeText(testPassword)
        app.buttons["Sign In"].tap()

        // Wait for main screen
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))

        // Go to Plan tab
        app.tabBars.buttons["Plan"].tap()

        // Tap "Plan My Week" button
        let planButton = app.buttons["Plan My Week"]
        XCTAssertTrue(planButton.waitForExistence(timeout: 5), "Plan My Week button should exist")
        planButton.tap()

        // Wait for plan to generate - should see "Meal Plan" title
        let mealPlanTitle = app.staticTexts["Meal Plan"]
        XCTAssertTrue(mealPlanTitle.waitForExistence(timeout: 10), "Meal Plan title should appear after generation")

        // Debug: Print all buttons in the app
        print("🔍 All buttons in app:")
        for button in app.buttons.allElementsBoundByIndex {
            print("  - Button: '\(button.label)' identifier: '\(button.identifier)'")
        }

        // Debug: Print all navigation bar elements
        print("🔍 Navigation bar buttons:")
        for button in app.navigationBars.buttons.allElementsBoundByIndex {
            print("  - NavBar Button: '\(button.label)'")
        }

        // Verify countdown timer appears - use accessibilityIdentifier
        let syncButton = app.buttons["SyncButton"]
        XCTAssertTrue(syncButton.waitForExistence(timeout: 3), "Sync countdown button should appear in toolbar")

        // Verify the button shows a number (countdown)
        let buttonLabel = syncButton.label
        XCTAssertTrue(buttonLabel.contains(where: { $0.isNumber }), "Sync button should show countdown number, got: \(buttonLabel)")

        // Verify regenerate button exists - use accessibilityIdentifier
        let regenerateButton = app.buttons["RegenerateButton"]
        XCTAssertTrue(regenerateButton.exists, "Regenerate button should exist in toolbar")

        // Verify day cards are showing (at least one day with Today)
        XCTAssertTrue(app.staticTexts["Today"].exists, "Today label should appear on first day card")
    }

    /// Verifies tapping countdown timer triggers sync
    func test_planGeneration_tapCountdown_triggersSync() throws {
        // Login
        app.textFields["Email"].tap()
        app.textFields["Email"].typeText(testEmail)
        app.secureTextFields["Password"].tap()
        app.secureTextFields["Password"].typeText(testPassword)
        app.buttons["Sign In"].tap()

        // Wait for login to complete
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))

        // Check keychain status in Settings before trying to sync
        app.tabBars.buttons["Settings"].tap()
        sleep(1)
        let keychainStatusLabel = app.staticTexts["SettingsKeychainStatus"]
        if keychainStatusLabel.exists {
            print("🔑 Keychain status after login: \(keychainStatusLabel.label)")
        }

        // Check for keychain error
        let keychainErrorLabel = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Last Error'")).firstMatch
        if keychainErrorLabel.exists {
            print("❌ Keychain error: \(keychainErrorLabel.label)")
        }

        // Navigate to Plan
        app.tabBars.buttons["Plan"].tap()

        // Generate plan
        let planButton = app.buttons["Plan My Week"]
        XCTAssertTrue(planButton.waitForExistence(timeout: 5))
        planButton.tap()

        // Wait for plan
        XCTAssertTrue(app.staticTexts["Meal Plan"].waitForExistence(timeout: 10))

        // Find and tap the sync button using accessibilityIdentifier
        let syncButton = app.buttons["SyncButton"]
        XCTAssertTrue(syncButton.waitForExistence(timeout: 3))
        syncButton.tap()

        // Wait for sync to complete
        sleep(5)

        // Check for sync error - look for "Not logged in" or other error messages
        let errorTexts = app.staticTexts.allElementsBoundByIndex.filter {
            $0.label.lowercased().contains("error") ||
            $0.label.lowercased().contains("not logged") ||
            $0.label.lowercased().contains("failed")
        }

        if !errorTexts.isEmpty {
            for errorText in errorTexts {
                print("❌ Found error text: '\(errorText.label)'")
            }
            XCTFail("Sync showed error: \(errorTexts.first?.label ?? "unknown")")
        }

        // Check that button is still there (either synced or still syncing)
        XCTAssertTrue(app.buttons["SyncButton"].exists, "Sync button should still exist")
    }
}
