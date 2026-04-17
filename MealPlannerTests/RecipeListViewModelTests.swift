import XCTest
import SwiftData
@testable import MealPlanner

/// Tests for RecipeListViewModel sync behavior
final class RecipeListViewModelTests: XCTestCase {

    // MARK: - Sync Throttling Tests

    /// Bug: Sync fires on every tab switch, should only sync once per session
    /// or with a reasonable cooldown (e.g., 5 minutes)
    func test_syncRecipes_doesNotSyncAgain_withinCooldownPeriod() async throws {
        let viewModel = RecipeListViewModel()

        // First sync - should update lastSyncTime
        XCTAssertNil(viewModel.lastSyncTime, "Should start with no sync time")

        // Simulate a sync by setting lastSyncTime (we can't easily mock the client)
        // Instead, test the throttle logic directly
        viewModel.lastSyncTime = Date()

        // Check that hasSyncedRecently returns true immediately after sync
        XCTAssertTrue(viewModel.hasSyncedRecently, "Should report recently synced right after sync")
    }

    /// After cooldown period, should allow sync again
    func test_syncRecipes_allowsSync_afterCooldownExpires() async throws {
        let viewModel = RecipeListViewModel()

        // Set last sync to 10 minutes ago (past the cooldown)
        viewModel.lastSyncTime = Date().addingTimeInterval(-600) // 10 min ago

        XCTAssertFalse(viewModel.hasSyncedRecently, "Should allow sync after cooldown expires")
    }

    /// First sync (no previous sync time) should always be allowed
    func test_syncRecipes_allowsFirstSync() async throws {
        let viewModel = RecipeListViewModel()

        XCTAssertNil(viewModel.lastSyncTime)
        XCTAssertFalse(viewModel.hasSyncedRecently, "Should allow first sync")
    }
}
