import Foundation
import SwiftData

/// A generated week plan - 7 dinners for the next 7 days
@Observable
final class WeekPlan {
    /// The 7 day assignments (index 0 = today, index 6 = 6 days from now)
    var days: [DayPlan]
    
    /// Recipes that have been excluded (used, then regenerated)
    private var excludedRecipeIds: Set<String> = []
    
    /// All available recipes for generation
    private var allRecipes: [RecipeModel]
    
    init(recipes: [RecipeModel]) {
        self.allRecipes = recipes
        self.days = []
    }
    
    /// Generate a fresh 7-day plan with random recipes
    func generate() {
        excludedRecipeIds.removeAll()
        days = (0..<7).map { dayOffset in
            let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: Date()) ?? Date()
            let recipe = pickRandomRecipe()
            return DayPlan(date: date, recipe: recipe)
        }
    }
    
    /// Regenerate a specific day with a different recipe
    func regenerateDay(at index: Int) {
        guard index >= 0 && index < days.count else { return }
        
        // Exclude current recipe from future picks
        if let currentRecipe = days[index].recipe {
            excludedRecipeIds.insert(currentRecipe.uid)
        }
        
        // Pick a new recipe
        days[index].recipe = pickRandomRecipe()
    }
    
    /// Pick a random recipe that hasn't been used this week
    private func pickRandomRecipe() -> RecipeModel? {
        // Get recipes not already in this week's plan and not excluded
        let usedIds = Set(days.compactMap { $0.recipe?.uid })
        let available = allRecipes.filter { recipe in
            !usedIds.contains(recipe.uid) && !excludedRecipeIds.contains(recipe.uid)
        }
        
        // If we've exhausted all recipes, reset exclusions (but keep week duplicates blocked)
        if available.isEmpty {
            excludedRecipeIds.removeAll()
            let stillAvailable = allRecipes.filter { !usedIds.contains($0.uid) }
            return stillAvailable.randomElement()
        }
        
        return available.randomElement()
    }
}

/// A single day in the week plan
@Observable
final class DayPlan: Identifiable {
    let id = UUID()
    let date: Date
    var recipe: RecipeModel?
    
    init(date: Date, recipe: RecipeModel?) {
        self.date = date
        self.recipe = recipe
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
