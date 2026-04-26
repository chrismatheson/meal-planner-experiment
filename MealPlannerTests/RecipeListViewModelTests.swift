import XCTest
import SwiftData
@testable import paprikaplanner

/// Tests for RecipeListViewModel sync behavior
/// Note: lastSyncTime is now managed by SyncStatusManager
final class RecipeListViewModelTests: XCTestCase {

    var syncStatus: SyncStatusManager!

    override func setUp() {
        super.setUp()
        syncStatus = SyncStatusManager.shared
        // Clear persisted state
        UserDefaults.standard.removeObject(forKey: "lastRecipeSyncTime")
    }

    // MARK: - Sync Throttling Tests

    /// Sync fires on every tab switch, should only sync once per session
    /// or with a reasonable cooldown (e.g., 5 minutes)
    func test_syncRecipes_doesNotSyncAgain_withinCooldownPeriod() async throws {
        let viewModel = RecipeListViewModel()

        // First sync - should have no sync time
        XCTAssertNil(syncStatus.lastRecipeSyncTime, "Should start with no sync time")

        // Simulate a sync completing
        syncStatus.markRecipesSynced()

        // Check that hasSyncedRecently returns true immediately after sync
        XCTAssertTrue(viewModel.hasSyncedRecently, "Should report recently synced right after sync")
    }

    /// After cooldown period, should allow sync again
    func test_syncRecipes_allowsSync_afterCooldownExpires() async throws {
        let viewModel = RecipeListViewModel()

        // Set last sync to 10 minutes ago (past the cooldown)
        UserDefaults.standard.set(Date().addingTimeInterval(-600), forKey: "lastRecipeSyncTime")

        XCTAssertFalse(viewModel.hasSyncedRecently, "Should allow sync after cooldown expires")
    }

    /// First sync (no previous sync time) should always be allowed
    func test_syncRecipes_allowsFirstSync() async throws {
        let viewModel = RecipeListViewModel()

        XCTAssertNil(syncStatus.lastRecipeSyncTime)
        XCTAssertFalse(viewModel.hasSyncedRecently, "Should allow first sync")
    }
}
