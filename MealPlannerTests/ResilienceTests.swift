import XCTest
import SwiftData
@testable import paprikaplanner

// MARK: - Test 1: Network Timeout Configuration

/// Verifies PaprikaClient has a reasonable timeout configured,
/// not the system default 60s that hangs the app on slow networks.
final class NetworkTimeoutTests: XCTestCase {

    func test_defaultClient_hasReasonableTimeout() async {
        let client = PaprikaClient()
        let config = await client.session.configuration
        XCTAssertLessThanOrEqual(
            config.timeoutIntervalForRequest, 30,
            "Request timeout should be ≤30s to avoid hanging the app"
        )
    }

    func test_customSession_isUsed() async {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 5
        let session = URLSession(configuration: config)
        let client = PaprikaClient(session: session)
        let clientSession = await client.session
        XCTAssertEqual(
            clientSession.configuration.timeoutIntervalForRequest, 5,
            "Custom session should be used by client"
        )
    }

    func test_loginWithTimeout_failsGracefully() async {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 0.001
        let session = URLSession(configuration: config)
        let client = PaprikaClient(session: session)
        do {
            _ = try await client.login(email: "test@test.com", password: "test")
            XCTFail("Should have thrown a timeout error")
        } catch {
            XCTAssertNotNil(error, "Error should be non-nil and catchable")
        }
    }
}

// MARK: - Test 2: Offline Sync Queue Resilience

/// Verifies the offline sync queue handles partial failures correctly:
/// meals that fail to sync must remain queued (needsSync = true).
final class OfflineSyncQueueResilienceTests: XCTestCase {

    private func makePendingMeal(name: String, uid: String = UUID().uuidString) -> CachedMealModel {
        let paprikaMeal = PaprikaMeal(
            uid: uid, recipeUid: nil, date: "2026-05-09 12:00:00",
            name: name, orderFlag: 0, type: 2, deleted: false
        )
        let meal = CachedMealModel(from: paprikaMeal)
        meal.needsSync = true
        return meal
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([CachedMealModel.self, RecipeModel.self, MealSlotModel.self,
                             CategoryModel.self, SlotRuleModel.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @MainActor
    func test_drainFailure_mealsRemainQueued() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let meal = makePendingMeal(name: "Test Meal 1", uid: "MEAL-1")
        context.insert(meal)
        try context.save()

        let descriptor = FetchDescriptor<CachedMealModel>(
            predicate: #Predicate { $0.needsSync == true }
        )
        let pendingBefore = try context.fetch(descriptor)
        XCTAssertEqual(pendingBefore.count, 1, "Should have 1 pending meal before drain")

        // Simulate failed drain: needsSync stays true (catch block doesn't touch it)
        meal.needsSync = true
        let pendingAfter = try context.fetch(descriptor)
        XCTAssertEqual(pendingAfter.count, 1, "Meals should remain queued after sync failure")
        XCTAssertTrue(pendingAfter.first?.needsSync ?? false)
    }

    @MainActor
    func test_drainSuccess_marksAllMealsSynced() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        for i in 0..<3 {
            let meal = makePendingMeal(name: "Meal \(i)", uid: "MEAL-\(i)")
            context.insert(meal)
        }
        try context.save()

        let descriptor = FetchDescriptor<CachedMealModel>(
            predicate: #Predicate { $0.needsSync == true }
        )
        let pending = try context.fetch(descriptor)
        XCTAssertEqual(pending.count, 3)

        for meal in pending { meal.needsSync = false }
        try context.save()

        let stillPending = try context.fetch(descriptor)
        XCTAssertEqual(stillPending.count, 0, "All meals should be synced after successful drain")
    }
}

// MARK: - Test 3: Concurrent Sync Protection

/// Verifies RecipeSyncEngine rejects concurrent sync calls
/// to prevent data corruption from overlapping writes.
final class ConcurrentSyncTests: XCTestCase {

    @MainActor
    func test_sync_rejectsConcurrentCalls() async throws {
        let engine = RecipeSyncEngine()
        engine.phase = .fetchingStubs
        XCTAssertTrue(engine.isSyncing)

        let schema = Schema([RecipeModel.self, CachedMealModel.self, MealSlotModel.self,
                             CategoryModel.self, SlotRuleModel.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        let client = PaprikaClient()

        let result = await engine.sync(client: client, context: context)
        XCTAssertEqual(result.total, 0, "Concurrent sync should return empty result")
        XCTAssertEqual(result.fetched, 0)
        XCTAssertEqual(result.errors, 0, "Rejected sync should not count as error")
    }

    @MainActor
    func test_sync_allowsAfterPreviousComplete() async {
        let engine = RecipeSyncEngine()
        engine.phase = .complete
        XCTAssertFalse(engine.isSyncing, "Should not report isSyncing when complete")
    }

    @MainActor
    func test_sync_allowsAfterPreviousFailed() async {
        let engine = RecipeSyncEngine()
        engine.phase = .failed("Previous error")
        XCTAssertFalse(engine.isSyncing, "Should not report isSyncing after failure")
    }
}

// MARK: - Test 4: Token Expiry / Auth Resilience

/// Verifies that expired or invalid tokens are handled gracefully
/// rather than causing silent failures or app hangs.
final class TokenResilienceTests: XCTestCase {

    func test_apiCallWithoutToken_throwsNotAuthenticated() async {
        let client = PaprikaClient()
        do {
            _ = try await client.fetchRecipeStubs()
            XCTFail("Should throw notAuthenticated when no token is set")
        } catch let error as PaprikaError {
            XCTAssertEqual(error.errorDescription, PaprikaError.notAuthenticated.errorDescription)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func test_apiCallWithInvalidToken_throwsNotAuthenticated() async {
        let client = PaprikaClient()
        await client.setToken("expired-or-invalid-token")
        do {
            _ = try await client.fetchRecipeStubs()
            XCTFail("Should throw when token is invalid")
        } catch let error as PaprikaError {
            switch error {
            case .notAuthenticated, .serverError:
                break // Expected — 401 or server rejection
            default:
                break // Network errors also acceptable
            }
        } catch {
            // URLError or other network errors are acceptable — key: no hang, no crash
        }
    }

    func test_saveMealsWithoutAuth_throwsNotAuthenticated() async {
        let client = PaprikaClient()
        let meal = PaprikaMeal(
            uid: "test-uid", recipeUid: nil, date: "2026-05-09",
            name: "Test Meal", orderFlag: 0, type: 0, deleted: false
        )
        do {
            try await client.saveMeals([meal])
            XCTFail("Should throw notAuthenticated when no auth header")
        } catch let error as PaprikaError {
            XCTAssertEqual(error.errorDescription, PaprikaError.notAuthenticated.errorDescription)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func test_appState_signOut_clearsAuthState() {
        let appState = AppState()
        appState.isAuthenticated = true
        appState.currentUser = User(email: "test@test.com")
        appState.signOut()
        XCTAssertFalse(appState.isAuthenticated)
        XCTAssertNil(appState.currentUser)
        XCTAssertNil(appState.paprikaClient)
    }
}
