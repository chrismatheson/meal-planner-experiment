import Foundation
import SwiftData

/// Hash-based incremental recipe sync engine.
/// Fetches all stubs, compares hashes to local cache, only downloads changed/new recipes.
/// Deletes orphaned local recipes no longer present on the server.
@Observable
final class RecipeSyncEngine {

    // MARK: - Sync Phase

    enum SyncPhase: Equatable {
        case idle
        case fetchingStubs
        case comparing
        case fetchingDetails
        case deletingOrphans
        case complete
        case failed(String)
    }

    // MARK: - Sync Result

    struct SyncResult {
        let total: Int
        let fetched: Int
        let skipped: Int
        let deleted: Int
        let errors: Int
    }

    // MARK: - Observable State

    var phase: SyncPhase = .idle
    var isSyncing: Bool { phase != .idle && phase != .complete && !isFailed }
    var totalRecipes: Int = 0
    var syncedRecipes: Int = 0

    /// Progress fraction (0.0–1.0) during fetchingDetails phase
    var progress: Double {
        guard totalRecipes > 0 else { return 0 }
        return Double(syncedRecipes) / Double(totalRecipes)
    }

    private var isFailed: Bool {
        if case .failed = phase { return true }
        return false
    }

    private let syncStatus = SyncStatusManager.shared

    // MARK: - Diff Logic (testable, pure)

    /// Compare remote stubs against local recipes. Returns stubs that need fetching and UIDs to delete.
    struct SyncDiff {
        let toFetch: [RecipeStub]
        let skipped: Int
        let orphanUids: Set<String>
    }

    /// Local recipe summary for diff computation (avoids coupling to SwiftData in tests)
    struct LocalRecipeSummary {
        let uid: String
        let hash: String?

        init(uid: String, hash: String?) {
            self.uid = uid
            self.hash = hash
        }

        init(from model: RecipeModel) {
            self.uid = model.uid
            self.hash = model.hash
        }
    }

    static func computeDiff(stubs: [RecipeStub], localRecipes: [LocalRecipeSummary]) -> SyncDiff {
        let localByUid = Dictionary(uniqueKeysWithValues: localRecipes.map { ($0.uid, $0) })
        let remoteUids = Set(stubs.map(\.uid))

        var toFetch: [RecipeStub] = []
        var skipped = 0

        for stub in stubs {
            if let local = localByUid[stub.uid], local.hash == stub.hash {
                skipped += 1
            } else {
                toFetch.append(stub)
            }
        }

        let orphanUids = Set(localRecipes.map(\.uid)).subtracting(remoteUids)

        return SyncDiff(toFetch: toFetch, skipped: skipped, orphanUids: orphanUids)
    }

    // MARK: - Sync

    /// Perform a full incremental recipe sync.
    /// - Returns: SyncResult with counts, or throws on fatal error
    @MainActor
    func sync(client: PaprikaClient, context: ModelContext) async -> SyncResult {
        phase = .fetchingStubs
        syncedRecipes = 0
        totalRecipes = 0

        do {
            // 1. Fetch all stubs from API
            let stubs = try await client.fetchRecipeStubs()
            totalRecipes = stubs.count

            // 2. Compare with local cache
            phase = .comparing
            let descriptor = FetchDescriptor<RecipeModel>()
            let localRecipes = (try? context.fetch(descriptor)) ?? []
            let localByUid = Dictionary(uniqueKeysWithValues: localRecipes.map { ($0.uid, $0) })
            let localSummaries = localRecipes.map { LocalRecipeSummary(from: $0) }

            let diff = Self.computeDiff(stubs: stubs, localRecipes: localSummaries)
            print("🔄 Sync: \(stubs.count) total, \(diff.toFetch.count) to fetch, \(diff.skipped) unchanged, \(diff.orphanUids.count) orphans")

            // 3. Fetch details for new/changed recipes
            phase = .fetchingDetails
            totalRecipes = diff.toFetch.count
            var errors = 0

            for stub in diff.toFetch {
                do {
                    let recipe = try await client.fetchRecipeDetail(uid: stub.uid)

                    if let existing = localByUid[recipe.uid] {
                        existing.update(from: recipe)
                    } else {
                        let newRecipe = RecipeModel(from: recipe)
                        context.insert(newRecipe)
                    }

                    syncedRecipes += 1
                } catch {
                    print("⚠️ Failed to fetch recipe \(stub.uid): \(error)")
                    errors += 1
                }
            }

            // 4. Delete orphans (recipes removed from Paprika)
            phase = .deletingOrphans
            var deleted = 0
            for local in localRecipes where diff.orphanUids.contains(local.uid) {
                context.delete(local)
                deleted += 1
                print("🗑️ Deleted orphan recipe: \(local.name)")
            }

            // 5. Save and finish
            try context.save()
            syncStatus.markRecipesSynced()
            phase = .complete

            let result = SyncResult(
                total: stubs.count,
                fetched: diff.toFetch.count - errors,
                skipped: diff.skipped,
                deleted: deleted,
                errors: errors
            )
            print("✅ Recipe sync complete: \(result.total) total, \(result.fetched) fetched, \(result.skipped) skipped, \(result.deleted) deleted, \(result.errors) errors")
            return result

        } catch {
            let message = error.localizedDescription
            phase = .failed(message)
            syncStatus.setError(message)
            print("❌ Recipe sync failed: \(error)")
            return SyncResult(total: 0, fetched: 0, skipped: 0, deleted: 0, errors: 1)
        }
    }
}


// MARK: - Category Sync

extension RecipeSyncEngine {

    /// Sync categories from Paprika. Upserts all, deletes orphans.
    @MainActor
    func syncCategories(client: PaprikaClient, context: ModelContext) async {
        do {
            let remoteCategories = try await client.fetchCategories()

            // Load local categories
            let descriptor = FetchDescriptor<CategoryModel>()
            let localCategories = (try? context.fetch(descriptor)) ?? []
            let localByUid = Dictionary(uniqueKeysWithValues: localCategories.map { ($0.uid, $0) })
            let remoteUids = Set(remoteCategories.map(\.uid))

            // Upsert
            for remote in remoteCategories {
                if let existing = localByUid[remote.uid] {
                    existing.update(from: remote)
                } else {
                    let newCategory = CategoryModel(from: remote)
                    context.insert(newCategory)
                }
            }

            // Delete orphans
            var deleted = 0
            for local in localCategories where !remoteUids.contains(local.uid) {
                context.delete(local)
                deleted += 1
            }

            try context.save()
            syncStatus.markCategoriesSynced()
            print("✅ Categories sync: \(remoteCategories.count) total, \(deleted) deleted")

        } catch {
            print("⚠️ Category sync failed: \(error)")
        }
    }
}