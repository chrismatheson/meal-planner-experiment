import Foundation
import SwiftData

@Observable
final class RecipeListViewModel {
    var isLoading = false
    var error: Error?

    /// Exposes sync engine state for progress UI
    let syncEngine = RecipeSyncEngine()

    private let syncStatus = SyncStatusManager.shared

    /// Cooldown period between automatic syncs (5 minutes)
    private let syncCooldown: TimeInterval = 300

    /// Returns true if we've synced within the cooldown period
    var hasSyncedRecently: Bool {
        guard let lastSync = syncStatus.lastRecipeSyncTime else { return false }
        return Date().timeIntervalSince(lastSync) < syncCooldown
    }

    /// Sync recipes from Paprika API to local cache using hash-based incremental sync.
    /// - If offline or API fails, cached data remains available
    /// - Shows loading state only on first load (when cache is empty)
    /// - Throttled: won't sync again within cooldown period unless forced
    @MainActor
    func syncRecipes(context: ModelContext, client: PaprikaClient?, force: Bool = false) async {
        // Skip if we synced recently (unless forced, e.g., pull-to-refresh)
        if !force && hasSyncedRecently {
            let lastSync = syncStatus.lastRecipeSyncTime!
            print("⏳ Skipping sync - synced \(Int(Date().timeIntervalSince(lastSync)))s ago")
            return
        }

        guard let client = client else {
            print("📶 No authenticated client - offline mode")
            return
        }

        // Check if we have cached data
        let descriptor = FetchDescriptor<RecipeModel>()
        let existingRecipes = (try? context.fetch(descriptor)) ?? []
        let hasCachedData = !existingRecipes.isEmpty

        // Only show loading indicator if no cached data
        if !hasCachedData {
            isLoading = true
        }

        _ = await syncEngine.sync(client: client, context: context)
        isLoading = false

        if case .failed(let message) = syncEngine.phase {
            if hasCachedData {
                print("⚠️ Sync failed but cached data available: \(message)")
            } else {
                self.error = PaprikaError.networkError(
                    NSError(domain: "RecipeSync", code: -1, userInfo: [NSLocalizedDescriptionKey: message])
                )
            }
        } else {
            error = nil
        }
    }
}
