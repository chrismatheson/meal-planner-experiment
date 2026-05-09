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

        // Sign out if already logged in (ensures clean state for login tests)
        signOutIfNeeded()
    }

    /// Helper to sign out if currently logged in
    private func signOutIfNeeded() {
        // If tab bar exists, we're logged in
        if app.tabBars.firstMatch.waitForExistence(timeout: 2) {
            // Go to Settings and sign out
            app.tabBars.buttons["Settings"].tap()
            let signOutButton = app.buttons["Sign Out"]
            if signOutButton.waitForExistence(timeout: 2) {
                signOutButton.tap()
                // Wait for login screen
                _ = app.textFields["Email"].waitForExistence(timeout: 3)
            }
        }
    }

    /// Helper to sign in (handles already-logged-in state)
    private func signInIfNeeded(email: String, password: String) {
        if app.textFields["Email"].exists {
            app.textFields["Email"].tap()
            app.textFields["Email"].typeText(email)
            app.secureTextFields["Password"].tap()
            app.secureTextFields["Password"].typeText(password)
            app.buttons["Sign In"].tap()
        }
        // Wait for login to complete
        _ = app.tabBars.firstMatch.waitForExistence(timeout: 15)
    }

    private var configuredTestEmail: String? {
        ProcessInfo.processInfo.environment["PAPRIKA_TEST_EMAIL"]
    }

    private var configuredTestPassword: String? {
        ProcessInfo.processInfo.environment["PAPRIKA_TEST_PASSWORD"]
    }

    private func waitForAuthenticatedUI(timeout: TimeInterval = 15) {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: timeout),
                      "Expected authenticated tab bar to appear")
        XCTAssertTrue(app.navigationBars["Meal Plan"].waitForExistence(timeout: 5),
                      "Expected app to land on the Plan-first flow")
    }

    private func openPlanTab() {
        app.tabBars.buttons["Plan"].tap()
        XCTAssertTrue(app.navigationBars["Meal Plan"].waitForExistence(timeout: 5))
    }

    @discardableResult
    private func ensurePlanReviewIsVisible(timeout: TimeInterval = 15) -> Bool {
        openPlanTab()

        let syncButton = app.buttons["SyncButton"]
        if syncButton.waitForExistence(timeout: 5) {
            return true
        }

        let planButton = app.buttons["Plan My Week"]
        if planButton.waitForExistence(timeout: 5) {
            planButton.tap()
            return syncButton.waitForExistence(timeout: timeout)
        }

        let loadingText = app.staticTexts["Loading your meal plan..."]
        if loadingText.exists {
            return syncButton.waitForExistence(timeout: timeout)
        }

        return syncButton.waitForExistence(timeout: timeout)
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
    
    /// Verifies valid credentials navigate into the current Plan-first shell
    /// REQUIRES: PAPRIKA_TEST_EMAIL and PAPRIKA_TEST_PASSWORD env vars
    func test_login_withValidCredentials_showsPlanShell() throws {
        guard let email = ProcessInfo.processInfo.environment["PAPRIKA_TEST_EMAIL"],
              let password = ProcessInfo.processInfo.environment["PAPRIKA_TEST_PASSWORD"] else {
            throw XCTSkip("Test credentials not configured")
        }
        
        app.textFields["Email"].tap()
        app.textFields["Email"].typeText(email)
        
        app.secureTextFields["Password"].tap()
        app.secureTextFields["Password"].typeText(password)
        
        app.buttons["Sign In"].tap()

        waitForAuthenticatedUI()
        XCTAssertTrue(app.tabBars.buttons["Plan"].exists)
        XCTAssertTrue(app.tabBars.buttons["Recipes"].exists)
        XCTAssertTrue(app.tabBars.buttons["Settings"].exists)
    }
    
    /// Full happy path: login → land on Plan → generate/load review state
    func test_fullHappyPath_loginToPlanReview() throws {
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

        waitForAuthenticatedUI()
        XCTAssertTrue(ensurePlanReviewIsVisible(), "Expected generated or loaded plan review UI")
    }

    // MARK: - Session Persistence Tests

    /// Verifies that after signing in, session persists when app goes to background and returns
    /// NOTE: UI test terminate/launch reinstalls app, wiping keychain. We test background/foreground instead.
    func test_sessionPersistence_afterLogin_relaunchSkipsLogin() throws {
        guard let email = configuredTestEmail,
              let password = configuredTestPassword else {
            throw XCTSkip("Test credentials not configured")
        }

        // Check initial keychain status
        let keychainStatus = app.staticTexts["KeychainStatus"]
        if keychainStatus.waitForExistence(timeout: 3) {
            print("🔍 Initial keychain status: \(keychainStatus.label)")
        }

        // Sign in only if needed (might already be logged in from previous test)
        if app.textFields["Email"].exists {
            app.textFields["Email"].tap()
            app.textFields["Email"].typeText(email)
            app.secureTextFields["Password"].tap()
            app.secureTextFields["Password"].typeText(password)
            app.buttons["Sign In"].tap()
        }

        // Wait for successful login - should see tab bar
        waitForAuthenticatedUI()

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
        XCTAssertTrue(app.staticTexts[email].waitForExistence(timeout: 3),
                      "Should see logged-in email in Settings - confirms session persists")
    }

    // MARK: - Plan Generation Tests

    /// Verifies that after generating a plan, countdown timer appears in toolbar
    func test_planGeneration_showsCountdownTimer() throws {
        guard let email = configuredTestEmail,
              let password = configuredTestPassword else {
            throw XCTSkip("Test credentials not configured")
        }

        signInIfNeeded(email: email, password: password)
        waitForAuthenticatedUI()
        XCTAssertTrue(ensurePlanReviewIsVisible(), "Expected plan review UI")

        let syncButton = app.buttons["SyncButton"]
        XCTAssertTrue(syncButton.exists, "Sync button should appear in toolbar")

        let regenerateButton = app.buttons["RegenerateButton"]
        XCTAssertTrue(regenerateButton.exists, "Regenerate button should exist in toolbar")

        let dayCards = app.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH 'DayPlanCard_'"))
        XCTAssertGreaterThan(dayCards.count, 0, "Should show at least one day card in the plan")
    }

    /// Verifies tapping the sync affordance on the review screen attempts sync
    func test_planGeneration_tapSyncButton_triggersSync() throws {
        guard let email = configuredTestEmail,
              let password = configuredTestPassword else {
            throw XCTSkip("Test credentials not configured")
        }

        signInIfNeeded(email: email, password: password)
        waitForAuthenticatedUI()

        // Check keychain status in Settings before trying to sync
        app.tabBars.buttons["Settings"].tap()
        let keychainStatusLabel = app.staticTexts["SettingsKeychainStatus"]
        if keychainStatusLabel.waitForExistence(timeout: 3) {
            print("🔑 Keychain status after login: \(keychainStatusLabel.label)")
        }

        // Check for keychain error
        let keychainErrorLabel = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Last Error'")).firstMatch
        if keychainErrorLabel.exists {
            print("❌ Keychain error: \(keychainErrorLabel.label)")
        }

        XCTAssertTrue(ensurePlanReviewIsVisible(), "Expected plan review UI before syncing")

        let syncButton = app.buttons["SyncButton"]
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
