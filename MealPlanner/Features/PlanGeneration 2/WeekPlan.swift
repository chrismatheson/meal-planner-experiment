import Foundation
import SwiftData

/// A generated week plan - 7 dinners for the next 7 days
@Observable
final class WeekPlan {
    /// The 7 day assignments (index 0 = today, index 6 = 6 days from now)
    var days: [DayPlan]

    /// Recipes that have been excluded during this session (regenerated)
    private var sessionExcludedIds: Set<String> = []

    /// External exclusions (from rejection tracker, history, etc.)
    private var externalExcludedIds: Set<String> = []

    /// All available recipes for generation
    private var allRecipes: [RecipeModel]

    /// Combined exclusions
    private var allExcludedIds: Set<String> {
        sessionExcludedIds.union(externalExcludedIds)
    }

    init(recipes: [RecipeModel]) {
        self.allRecipes = recipes
        self.days = []
    }

    /// Set external exclusions (rejected recipes, recent history)
    func setExclusions(_ recipeIds: Set<String>) {
        externalExcludedIds = recipeIds
        print("📋 WeekPlan exclusions set: \(recipeIds.count) recipes")
    }

    /// Add to external exclusions
    func addExclusions(_ recipeIds: Set<String>) {
        externalExcludedIds.formUnion(recipeIds)
    }

    /// Generate a fresh 7-day plan with random recipes
    func generate() {
        sessionExcludedIds.removeAll()
        days = (0..<7).map { dayOffset in
            let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: Date()) ?? Date()
            let recipe = pickRandomRecipe()
            return DayPlan(date: date, recipe: recipe)
        }
    }

    /// Regenerate a specific day with a different recipe
    /// Returns the rejected recipe ID (if any) for tracking
    @discardableResult
    func regenerateDay(at index: Int) -> String? {
        guard index >= 0 && index < days.count else { return nil }

        // Track the rejected recipe
        let rejectedId = days[index].recipe?.uid

        // Exclude current recipe from future picks this session
        if let rejectedId = rejectedId {
            sessionExcludedIds.insert(rejectedId)
        }

        // Pick a new recipe
        days[index].recipe = pickRandomRecipe()

        return rejectedId
    }

    /// Pick a random recipe that hasn't been used this week and isn't excluded
    private func pickRandomRecipe() -> RecipeModel? {
        // Get recipes not already in this week's plan and not excluded
        let usedIds = Set(days.compactMap { $0.recipe?.uid })
        let available = allRecipes.filter { recipe in
            !usedIds.contains(recipe.uid) && !allExcludedIds.contains(recipe.uid)
        }

        // If we've exhausted all recipes, relax exclusions progressively
        if available.isEmpty {
            // First, try without session exclusions
            sessionExcludedIds.removeAll()
            let withoutSession = allRecipes.filter { recipe in
                !usedIds.contains(recipe.uid) && !externalExcludedIds.contains(recipe.uid)
            }
            if !withoutSession.isEmpty {
                return withoutSession.randomElement()
            }

            // Last resort: allow anything not in this week
            let lastResort = allRecipes.filter { !usedIds.contains($0.uid) }
            return lastResort.randomElement()
        }

        return available.randomElement()
    }

    /// Statistics for debugging/UI
    var exclusionStats: (session: Int, external: Int, total: Int) {
        (sessionExcludedIds.count, externalExcludedIds.count, allExcludedIds.count)
    }
}

/// A single day in the week plan
@Observable
final class DayPlan: Identifiable {
    let id = UUID()
    let date: Date
    var recipe: RecipeModel?

    /// Meal name from API (shown when we have meal but no local recipe)
    var mealName: String?

    init(date: Date, recipe: RecipeModel?, mealName: String? = nil) {
        self.date = date
        self.recipe = recipe
        self.mealName = mealName
    }

    /// Display name: prefer recipe name, fall back to meal name
    var displayName: String {
        recipe?.name ?? mealName ?? "No recipe"
    }

    /// Whether we have a meal assigned (either recipe or meal name)
    var hasMeal: Bool {
        recipe != nil || mealName != nil
    }

    /// Formatted day name (e.g., "Monday" or "Today")
    var dayName: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        }
    }

    /// Short date (e.g., "Apr 17")
    var shortDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}
