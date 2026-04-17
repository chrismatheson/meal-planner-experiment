import Foundation
import SwiftData

@Observable
final class RecipeListViewModel {
    var isLoading = false
    var error: Error?
    var lastSyncTime: Date?
    var isOffline = false

    /// Sync recipes from Paprika API to local cache
    /// - If offline or API fails, cached data remains available
    /// - Shows loading state only on first load (when cache is empty)
    func syncRecipes(context: ModelContext, client: PaprikaClient?) async {
        guard let client = client else {
            print("No authenticated client available")
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
            for paprikaRecipe in paprikaRecipes {
                if let existing = existingByUid[paprikaRecipe.uid] {
                    existing.update(from: paprikaRecipe)
                } else {
                    let newRecipe = RecipeModel(from: paprikaRecipe)
                    context.insert(newRecipe)
                }
            }

            try context.save()
            lastSyncTime = Date()
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
