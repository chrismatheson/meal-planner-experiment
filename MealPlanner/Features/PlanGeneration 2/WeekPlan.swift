import Foundation
import SwiftData

// MARK: - Cuisine Detection

/// Known cuisine types for diversity rules
enum CuisineType: String, CaseIterable {
    case italian = "Italian"
    case mexican = "Mexican"
    case asian = "Asian"
    case chinese = "Chinese"
    case japanese = "Japanese"
    case thai = "Thai"
    case indian = "Indian"
    case mediterranean = "Mediterranean"
    case greek = "Greek"
    case american = "American"
    case french = "French"
    case korean = "Korean"
    case vietnamese = "Vietnamese"
    case middleEastern = "Middle Eastern"
    case unknown = "Unknown"

    /// Keywords that indicate this cuisine (case-insensitive matching)
    var keywords: [String] {
        switch self {
        case .italian: return ["italian", "pasta", "pizza"]
        case .mexican: return ["mexican", "tex-mex", "taco", "burrito", "enchilada"]
        case .asian: return ["asian"]
        case .chinese: return ["chinese", "stir fry", "stir-fry"]
        case .japanese: return ["japanese", "sushi", "teriyaki", "ramen"]
        case .thai: return ["thai"]
        case .indian: return ["indian", "curry", "tikka", "masala"]
        case .mediterranean: return ["mediterranean"]
        case .greek: return ["greek"]
        case .american: return ["american", "bbq", "barbecue"]
        case .french: return ["french"]
        case .korean: return ["korean", "kimchi", "bulgogi"]
        case .vietnamese: return ["vietnamese", "pho", "banh mi"]
        case .middleEastern: return ["middle eastern", "lebanese", "falafel", "shawarma"]
        case .unknown: return []
        }
    }

    /// Detect cuisine from a recipe's categories
    static func detect(from categories: [String]) -> CuisineType {
        let lowercased = categories.map { $0.lowercased() }

        for cuisine in CuisineType.allCases where cuisine != .unknown {
            for keyword in cuisine.keywords {
                if lowercased.contains(where: { $0.contains(keyword) }) {
                    return cuisine
                }
            }
        }
        return .unknown
    }
}

// MARK: - Week Plan

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

    private let generator: PlanGenerator

    /// Combined exclusions
    private var allExcludedIds: Set<String> {
        sessionExcludedIds.union(externalExcludedIds)
    }

    init(recipes: [RecipeModel], generator: PlanGenerator = PlanGenerator()) {
        self.allRecipes = recipes
        self.generator = generator
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
        days = generator.generateWeek(from: allRecipes, excluding: allExcludedIds)
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

        guard let newDay = generator.regenerateDay(
            day: index,
            in: days,
            from: allRecipes,
            excluding: allExcludedIds
        ) else {
            return rejectedId
        }

        days[index].recipe = newDay.recipe

        return rejectedId
    }

    /// Statistics for debugging/UI
    var exclusionStats: (session: Int, external: Int, total: Int) {
        (sessionExcludedIds.count, externalExcludedIds.count, allExcludedIds.count)
    }

    /// Get cuisine distribution for the current week
    var cuisineDistribution: [CuisineType: Int] {
        var counts: [CuisineType: Int] = [:]
        for day in days {
            guard let recipe = day.recipe else { continue }
            let cuisine = CuisineType.detect(from: recipe.categories)
            counts[cuisine, default: 0] += 1
        }
        return counts
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
