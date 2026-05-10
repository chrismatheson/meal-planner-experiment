import Foundation
import SwiftData

/// Runs effort-level inference on recipes in batches of 25, off the main thread.
final class MetadataInferenceEngine {
    static let batchSize = 25

    /// Whether to normalise ingredient text during inference
    var normaliseIngredients: Bool = true

    /// Run inference on a background ModelContext. Returns number of recipes processed.
    func runInBackground(container: ModelContainer) async -> (inferred: Int, normalised: Int) {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return await runSync(context: context)
    }

    /// Synchronous inference for testing. Processes all eligible recipes.
    func runSync(context: ModelContext) async -> (inferred: Int, normalised: Int) {
        // Fetch all recipes
        let recipes = (try? context.fetch(FetchDescriptor<RecipeModel>())) ?? []
        // Fetch existing overrides, keyed by recipeUid
        let overrides = (try? context.fetch(FetchDescriptor<RecipeMetadataOverride>())) ?? []
        let overridesByUid = Dictionary(uniqueKeysWithValues: overrides.map { ($0.recipeUid, $0) })

        var processed = 0
        var normalisedRecipes = 0

        // Process in batches
        for batchStart in stride(from: 0, to: recipes.count, by: Self.batchSize) {
            let batchEnd = min(batchStart + Self.batchSize, recipes.count)
            let batch = recipes[batchStart..<batchEnd]

            for recipe in batch {
                let existing = overridesByUid[recipe.uid]

                // Skip confirmed/manual overrides
                if !MetadataResolver.shouldReInfer(override: existing) { continue }

                let inferred = EffortLevel.infer(from: recipe)

                if let existing {
                    // Update existing inferred override
                    existing.effortLevel = inferred.rawValue
                    existing.lastModified = Date()
                } else {
                    // Create new override
                    let newOverride = RecipeMetadataOverride(
                        recipeUid: recipe.uid,
                        effortLevel: inferred.rawValue
                    )
                    context.insert(newOverride)
                }
                processed += 1

                // Normalise ingredients if enabled
                if normaliseIngredients {
                    let result = IngredientTextNormaliser.normalise(recipe.ingredients)
                    if let normalisedText = result.text {
                        recipe.ingredients = normalisedText
                        normalisedRecipes += 1
                    }
                }
            }

            // Yield between batches to avoid starving other work
            if batchEnd < recipes.count {
                await Task.yield()
            }
        }

        try? context.save()
        return (inferred: processed, normalised: normalisedRecipes)
    }
}
