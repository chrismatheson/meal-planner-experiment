import XCTest
@testable import paprikaplanner

/// Tests for RecipeSyncEngine — hash-based incremental sync logic
///
/// QA FOCUS: The diff algorithm is the core correctness gate.
/// If computeDiff is wrong, we either miss updates or re-download everything.
///
/// Uses LocalRecipeSummary (plain struct) to avoid SwiftData container issues in tests.
final class RecipeSyncEngineTests: XCTestCase {

    typealias Summary = RecipeSyncEngine.LocalRecipeSummary

    // MARK: - Diff: All New (empty cache)

    func test_computeDiff_emptyCache_allStubsNeedFetching() {
        let stubs = [
            RecipeStub(uid: "A", hash: "h1"),
            RecipeStub(uid: "B", hash: "h2"),
            RecipeStub(uid: "C", hash: "h3"),
        ]

        let diff = RecipeSyncEngine.computeDiff(stubs: stubs, localRecipes: [])

        XCTAssertEqual(diff.toFetch.count, 3, "All stubs should need fetching when cache is empty")
        XCTAssertEqual(diff.skipped, 0)
        XCTAssertTrue(diff.orphanUids.isEmpty, "No orphans when cache is empty")
    }

    // MARK: - Diff: All Unchanged (hashes match)

    func test_computeDiff_allHashesMatch_nothingToFetch() {
        let local = [
            Summary(uid: "A", hash: "h1"),
            Summary(uid: "B", hash: "h2"),
        ]
        let stubs = [
            RecipeStub(uid: "A", hash: "h1"),
            RecipeStub(uid: "B", hash: "h2"),
        ]

        let diff = RecipeSyncEngine.computeDiff(stubs: stubs, localRecipes: local)

        XCTAssertEqual(diff.toFetch.count, 0, "Nothing should need fetching when all hashes match")
        XCTAssertEqual(diff.skipped, 2)
        XCTAssertTrue(diff.orphanUids.isEmpty)
    }

    // MARK: - Diff: Hash Changed (needs re-fetch)

    func test_computeDiff_hashChanged_fetchesChanged() {
        let local = [
            Summary(uid: "A", hash: "old_hash"),
            Summary(uid: "B", hash: "h2"),
        ]
        let stubs = [
            RecipeStub(uid: "A", hash: "new_hash"),  // Changed
            RecipeStub(uid: "B", hash: "h2"),          // Unchanged
        ]

        let diff = RecipeSyncEngine.computeDiff(stubs: stubs, localRecipes: local)

        XCTAssertEqual(diff.toFetch.count, 1, "Should fetch the recipe with changed hash")
        XCTAssertEqual(diff.toFetch.first?.uid, "A")
        XCTAssertEqual(diff.skipped, 1)
    }

    // MARK: - Diff: Nil Hash (first sync / migration)

    func test_computeDiff_nilLocalHash_fetchesRecipe() {
        let local = [Summary(uid: "A", hash: nil)]
        let stubs = [RecipeStub(uid: "A", hash: "h1")]

        let diff = RecipeSyncEngine.computeDiff(stubs: stubs, localRecipes: local)

        XCTAssertEqual(diff.toFetch.count, 1, "Should fetch when local hash is nil (migration)")
        XCTAssertEqual(diff.skipped, 0)
    }

    // MARK: - Diff: Orphan Detection

    func test_computeDiff_detectsOrphans() {
        let local = [
            Summary(uid: "A", hash: "h1"),
            Summary(uid: "B", hash: "h2"),
            Summary(uid: "DELETED", hash: "h3"),
        ]
        let stubs = [
            RecipeStub(uid: "A", hash: "h1"),
            RecipeStub(uid: "B", hash: "h2"),
        ]

        let diff = RecipeSyncEngine.computeDiff(stubs: stubs, localRecipes: local)

        XCTAssertEqual(diff.orphanUids.count, 1, "Should detect 1 orphan")
        XCTAssertTrue(diff.orphanUids.contains("DELETED"))
    }

    // MARK: - Diff: Mixed Scenario

    func test_computeDiff_mixedScenario() {
        let local = [
            Summary(uid: "UNCHANGED", hash: "h1"),
            Summary(uid: "CHANGED", hash: "old"),
            Summary(uid: "ORPHAN", hash: "h3"),
        ]
        let stubs = [
            RecipeStub(uid: "UNCHANGED", hash: "h1"),
            RecipeStub(uid: "CHANGED", hash: "new"),
            RecipeStub(uid: "BRAND_NEW", hash: "h4"),
        ]

        let diff = RecipeSyncEngine.computeDiff(stubs: stubs, localRecipes: local)

        XCTAssertEqual(diff.skipped, 1, "UNCHANGED should be skipped")
        XCTAssertEqual(diff.toFetch.count, 2, "CHANGED + BRAND_NEW should need fetching")
        let fetchUids = Set(diff.toFetch.map(\.uid))
        XCTAssertTrue(fetchUids.contains("CHANGED"))
        XCTAssertTrue(fetchUids.contains("BRAND_NEW"))
        XCTAssertEqual(diff.orphanUids, Set(["ORPHAN"]))
    }

    // MARK: - Diff: Empty Remote (all orphans)

    func test_computeDiff_emptyRemote_allOrphans() {
        let local = [
            Summary(uid: "A", hash: "h1"),
            Summary(uid: "B", hash: "h2"),
        ]

        let diff = RecipeSyncEngine.computeDiff(stubs: [], localRecipes: local)

        XCTAssertEqual(diff.toFetch.count, 0)
        XCTAssertEqual(diff.skipped, 0)
        XCTAssertEqual(diff.orphanUids.count, 2, "All local recipes should be orphans")
    }

    // MARK: - Engine State Tests

    func test_initialState_isIdle() {
        let engine = RecipeSyncEngine()
        XCTAssertEqual(engine.phase, .idle)
        XCTAssertFalse(engine.isSyncing)
        XCTAssertEqual(engine.progress, 0)
    }

    func test_progress_zeroWhenNoRecipes() {
        let engine = RecipeSyncEngine()
        engine.totalRecipes = 0
        XCTAssertEqual(engine.progress, 0)
    }
}
