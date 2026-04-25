import Foundation
import SwiftData

@Observable
final class PlanGenerationViewModel {
    var weekPlan: WeekPlan?
    var isGenerating = false
    var isSyncing = false
    var hasGenerated = false
    var hasSynced = false
    var syncError: String?

    private let paprikaClient = PaprikaClient()

    /// Generate a new week plan from cached recipes
    func generatePlan(context: ModelContext) {
        isGenerating = true

        // Fetch all cached recipes
        let descriptor = FetchDescriptor<RecipeModel>(
            sortBy: [SortDescriptor(\.name)]
        )

        do {
            let recipes = try context.fetch(descriptor)

            guard !recipes.isEmpty else {
                print("⚠️ No recipes available for generation")
                isGenerating = false
                return
            }

            // Create and generate the plan
            weekPlan = WeekPlan(recipes: recipes)
            weekPlan?.generate()
            hasGenerated = true
            hasSynced = false  // Reset sync state for new plan

            print("✅ Generated week plan with \(weekPlan?.days.count ?? 0) days")
        } catch {
            print("❌ Failed to fetch recipes: \(error)")
        }

        isGenerating = false
    }

    /// Regenerate all days with fresh random selections
    func regenerateAll() {
        weekPlan?.generate()
        hasSynced = false
    }

    /// Regenerate a specific day
    func regenerateDay(at index: Int) {
        weekPlan?.regenerateDay(at: index)
        hasSynced = false
    }

    /// Accept the plan and sync to Paprika
    func acceptPlan() async {
        guard let weekPlan = weekPlan else { return }

        isSyncing = true
        syncError = nil

        do {
            // Restore session from Keychain
            let keychain = KeychainService()
            guard let email = keychain.getEmail(),
                  let password = keychain.getPassword() else {
                syncError = "Not logged in"
                isSyncing = false
                return
            }

            // Login to get fresh auth
            _ = try await paprikaClient.login(email: email, password: password)

            // Convert DayPlans to PaprikaMeals
            let meals: [PaprikaMeal] = weekPlan.days.compactMap { day in
                guard let recipe = day.recipe else { return nil }
                // Create a temporary PaprikaRecipe for the model
                let paprikaRecipe = PaprikaRecipe(
                    uid: recipe.uid,
                    name: recipe.name,
                    ingredients: nil,
                    directions: nil,
                    prepTime: recipe.prepTime,
                    cookTime: recipe.cookTime,
                    totalTime: recipe.totalTime,
                    servings: nil,
                    rating: nil,
                    difficulty: nil,
                    notes: nil,
                    nutritionalInfo: nil,
                    photoUrl: recipe.photoUrl,
                    source: nil,
                    sourceUrl: nil,
                    categories: nil,
                    hash: nil,
                    imageUrl: nil,
                    created: nil,
                    onFavorites: nil,
                    photoHash: nil
                )
                return PaprikaMeal(date: day.date, recipe: paprikaRecipe, type: 2)
            }

            guard !meals.isEmpty else {
                syncError = "No meals to sync"
                isSyncing = false
                return
            }

            // Save to Paprika
            try await paprikaClient.saveMeals(meals)

            hasSynced = true
            print("✅ Synced \(meals.count) meals to Paprika")

        } catch {
            syncError = "Sync failed: \(error.localizedDescription)"
            print("❌ Sync failed: \(error)")
        }

        isSyncing = false
    }
}
