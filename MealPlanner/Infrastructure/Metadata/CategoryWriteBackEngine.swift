import Foundation
import SwiftData

/// Writes MP: category tags back to Paprika for recipes with pending sync.
/// Strips existing "MP: " prefixed categories and adds current effort/kid-friendly tags.
final class CategoryWriteBackEngine {

    /// Build updated categories array: strip old MP: prefixed, add current.
    static func buildCategories(existing: [String]?, effort: EffortLevel?, kidFriendly: Bool?) -> [String] {
        // Remove old MP: prefixed categories
        var categories = (existing ?? []).filter { !$0.hasPrefix("MP: ") }

        // Add current effort level category
        if let effort {
            categories.append(effort.categoryName)
        }

        // Add kid-friendly category if applicable
        if kidFriendly == true {
            categories.append("MP: Kid-Friendly")
        }

        return categories
    }

    /// Count overrides pending sync
    static func pendingSyncCount(context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<RecipeMetadataOverride>(
            predicate: #Predicate { $0.needsSync == true }
        )
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    /// Sync pending overrides to Paprika. Returns number successfully synced.
    func run(client: PaprikaClient, container: ModelContainer) async -> Int {
        let context = ModelContext(container)
        context.autosaveEnabled = false

        // Fetch overrides that need syncing
        let descriptor = FetchDescriptor<RecipeMetadataOverride>(
            predicate: #Predicate { $0.needsSync == true }
        )
        let overrides = (try? context.fetch(descriptor)) ?? []
        guard !overrides.isEmpty else { return 0 }

        var synced = 0

        for override in overrides {
            do {
                // Fetch current recipe from API to get latest categories
                var recipe = try await client.fetchRecipeDetail(uid: override.recipeUid)

                // Build updated categories
                let effort = EffortLevel(rawValue: override.effortLevel ?? "normal")
                let updatedCategories = Self.buildCategories(
                    existing: recipe.categories,
                    effort: effort,
                    kidFriendly: override.isKidFriendly
                )

                // Update and save back
                recipe.categories = updatedCategories
                try await client.saveRecipe(recipe)

                // Clear needsSync flag
                override.needsSync = false
                override.lastModified = Date()
                synced += 1
            } catch {
                print("⚠️ Write-back failed for \(override.recipeUid): \(error.localizedDescription)")
            }
        }

        try? context.save()
        return synced
    }
}
