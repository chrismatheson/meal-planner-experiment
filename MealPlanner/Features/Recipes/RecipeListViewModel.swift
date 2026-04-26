import Foundation
import SwiftData

@Observable
final class RecipeListViewModel {
    var isLoading = false
    var error: Error?
    var isOffline = false

    private let syncStatus = SyncStatusManager.shared

    /// Cooldown period between automatic syncs (5 minutes)
    private let syncCooldown: TimeInterval = 300

    /// Returns true if we've synced within the cooldown period
    var hasSyncedRecently: Bool {
        guard let lastSync = syncStatus.lastRecipeSyncTime else { return false }
        return Date().timeIntervalSince(lastSync) < syncCooldown
    }

    /// Sync recipes from Paprika API to local cache
    /// - If offline or API fails, cached data remains available
    /// - Shows loading state only on first load (when cache is empty)
    /// - Throttled: won't sync again within cooldown period unless forced
    func syncRecipes(context: ModelContext, client: PaprikaClient?, force: Bool = false) async {
        // Skip if we synced recently (unless forced, e.g., pull-to-refresh)
        if !force && hasSyncedRecently {
            let lastSync = syncStatus.lastRecipeSyncTime!
            print("⏳ Skipping sync - synced \(Int(Date().timeIntervalSince(lastSync)))s ago")
            return
        }

        guard let client = client else {
            print("📶 No authenticated client - offline mode")
            isOffline = true
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
        defer { isLoading = false }

        do {
            let paprikaRecipes = try await client.fetchRecipes()

            // Success - not offline
            isOffline = false

            let existingByUid = Dictionary(uniqueKeysWithValues: existingRecipes.map { ($0.uid, $0) })

            // Update or insert recipes
            var recipesWithPhotos = 0
            for paprikaRecipe in paprikaRecipes {
                if paprikaRecipe.photoUrl != nil {
                    recipesWithPhotos += 1
                }
                if let existing = existingByUid[paprikaRecipe.uid] {
                    existing.update(from: paprikaRecipe)
                } else {
                    let newRecipe = RecipeModel(from: paprikaRecipe)
                    context.insert(newRecipe)
                }
            }
            print("📸 \(recipesWithPhotos)/\(paprikaRecipes.count) recipes have photoUrl")

            try context.save()
            syncStatus.markRecipesSynced()
            error = nil
        } catch let urlError as URLError where urlError.code == .notConnectedToInternet {
            // Offline - keep using cached data
            isOffline = true
            if hasCachedData {
                print("📶 Offline - using cached recipes")
            } else {
                error = urlError
            }
        } catch {
            // Other error - keep using cached data if available
            if hasCachedData {
                print("⚠️ Sync failed but cached data available: \(error)")
            } else {
                self.error = error
            }
            print("Failed to sync recipes: \(error)")
        }
    }
}
