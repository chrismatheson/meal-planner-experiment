import Foundation
import SwiftData

// MARK: - Recipe Model (SwiftData)

@Model
final class RecipeModel {
    @Attribute(.unique) var uid: String
    var name: String
    var ingredients: String?
    var directions: String?
    var recipeDescription: String?
    var servings: String?
    var prepTime: String?
    var cookTime: String?
    var totalTime: String?
    var rating: Int?
    var categories: [String]
    var photo: String?
    var photoUrl: String?
    var source: String?
    var sourceUrl: String?
    var onFavorites: Bool
    var lastSynced: Date
    /// Hash from Paprika API — used for incremental sync (only fetch when hash changes)
    var hash: String?

    init(from paprikaRecipe: PaprikaRecipe) {
        self.uid = paprikaRecipe.uid
        self.name = paprikaRecipe.name
        self.ingredients = paprikaRecipe.ingredients
        self.directions = paprikaRecipe.directions
        self.recipeDescription = paprikaRecipe.description
        self.servings = paprikaRecipe.servings
        self.prepTime = paprikaRecipe.prepTime
        self.cookTime = paprikaRecipe.cookTime
        self.totalTime = paprikaRecipe.totalTime
        self.rating = paprikaRecipe.rating
        self.categories = paprikaRecipe.categories ?? []
        self.photo = paprikaRecipe.photo
        self.photoUrl = paprikaRecipe.photoUrl
        self.source = paprikaRecipe.source
        self.sourceUrl = paprikaRecipe.sourceUrl
        self.onFavorites = paprikaRecipe.onFavorites ?? false
        self.hash = paprikaRecipe.hash
        self.lastSynced = Date()
    }

    func update(from paprikaRecipe: PaprikaRecipe) {
        self.name = paprikaRecipe.name
        self.ingredients = paprikaRecipe.ingredients
        self.directions = paprikaRecipe.directions
        self.recipeDescription = paprikaRecipe.description
        self.servings = paprikaRecipe.servings
        self.prepTime = paprikaRecipe.prepTime
        self.cookTime = paprikaRecipe.cookTime
        self.totalTime = paprikaRecipe.totalTime
        self.rating = paprikaRecipe.rating
        self.categories = paprikaRecipe.categories ?? []
        self.photo = paprikaRecipe.photo
        self.photoUrl = paprikaRecipe.photoUrl
        self.source = paprikaRecipe.source
        self.sourceUrl = paprikaRecipe.sourceUrl
        self.onFavorites = paprikaRecipe.onFavorites ?? false
        self.hash = paprikaRecipe.hash
        self.lastSynced = Date()
    }
    
    var displayTime: String? {
        totalTime ?? cookTime ?? prepTime
    }
    
    var firstCategory: String? {
        categories.first
    }
    
    var imageURL: URL? {
        guard let photoUrl = photoUrl else { return nil }
        return URL(string: photoUrl)
    }
}

// MARK: - Category Model (SwiftData)

@Model
final class CategoryModel {
    @Attribute(.unique) var uid: String
    var name: String
    var orderFlag: Int
    var parentUid: String?
    var lastSynced: Date

    init(from paprikaCategory: PaprikaCategory) {
        self.uid = paprikaCategory.uid
        self.name = paprikaCategory.name
        self.orderFlag = paprikaCategory.orderFlag
        self.parentUid = paprikaCategory.parentUid
        self.lastSynced = Date()
    }

    func update(from paprikaCategory: PaprikaCategory) {
        self.name = paprikaCategory.name
        self.orderFlag = paprikaCategory.orderFlag
        self.parentUid = paprikaCategory.parentUid
        self.lastSynced = Date()
    }
}

// MARK: - Cached Meal Model (SwiftData)
// Stores meals fetched from Paprika, keyed by ISO week for efficient lookup

@Model
final class CachedMealModel {
    @Attribute(.unique) var uid: String
    var recipeUid: String?
    var recipeName: String
    var date: Date
    var mealType: Int  // 0=Breakfast, 1=Lunch, 2=Dinner
    var isoWeekYear: Int  // e.g., 2026
    var isoWeekNumber: Int  // 1-52
    var lastSynced: Date
    var needsSync: Bool  // True if locally modified

    init(from meal: PaprikaMeal) {
        let mealDate = meal.dateValue ?? Date()
        let (year, week) = Calendar.isoWeek(for: mealDate)

        self.uid = meal.uid
        self.recipeUid = meal.recipeUid
        self.recipeName = meal.name
        self.date = mealDate
        self.mealType = meal.type
        self.needsSync = false
        self.lastSynced = Date()
        self.isoWeekYear = year
        self.isoWeekNumber = week
    }

    init(date: Date, recipe: RecipeModel, mealType: Int = 2) {
        self.uid = UUID().uuidString.uppercased()
        self.recipeUid = recipe.uid
        self.recipeName = recipe.name
        self.date = date
        self.mealType = mealType
        self.needsSync = true
        self.lastSynced = Date()

        let (year, week) = Calendar.isoWeek(for: date)
        self.isoWeekYear = year
        self.isoWeekNumber = week
    }

    /// Convert to PaprikaMeal for API sync
    func toPaprikaMeal() -> PaprikaMeal {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        return PaprikaMeal(
            uid: uid,
            recipeUid: recipeUid,
            date: formatter.string(from: date),
            name: recipeName,
            orderFlag: 0,
            type: mealType,
            deleted: false
        )
    }
}

// MARK: - ISO Week Utilities

extension Calendar {
    /// Returns (year, weekNumber) for a given date using ISO week numbering
    /// ISO weeks start on Monday, week 1 contains the first Thursday of the year
    static func isoWeek(for date: Date) -> (year: Int, week: Int) {
        let calendar = Calendar(identifier: .iso8601)
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return (components.yearForWeekOfYear ?? 0, components.weekOfYear ?? 0)
    }

    /// Returns the date range (start, end) for a given ISO week
    static func dateRange(forISOWeek week: Int, year: Int) -> (start: Date, end: Date)? {
        var calendar = Calendar(identifier: .iso8601)
        calendar.firstWeekday = 2 // Monday

        var components = DateComponents()
        components.yearForWeekOfYear = year
        components.weekOfYear = week
        components.weekday = 2 // Monday

        guard let monday = calendar.date(from: components),
              let sunday = calendar.date(byAdding: .day, value: 6, to: monday) else {
            return nil
        }

        return (monday, sunday)
    }

    /// Returns the current ISO week number and year
    static var currentISOWeek: (year: Int, week: Int) {
        isoWeek(for: Date())
    }
}

// MARK: - PaprikaMeal Date Parsing

extension PaprikaMeal {
    /// Parse the date string to a Date object
    /// Uses local timezone for consistency with calendar operations
    var dateValue: Date? {
        // Try full datetime format first
        let fullFormatter = DateFormatter()
        fullFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        fullFormatter.timeZone = .current  // Interpret as local time
        if let date = fullFormatter.date(from: self.date) {
            return date
        }

        // Fall back to date-only (set to noon to avoid day boundary issues)
        let dateOnlyFormatter = DateFormatter()
        dateOnlyFormatter.dateFormat = "yyyy-MM-dd"
        dateOnlyFormatter.timeZone = .current  // Interpret as local time
        if let date = dateOnlyFormatter.date(from: String(self.date.prefix(10))) {
            // Add 12 hours to avoid day boundary issues with timezones
            return Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: date)
        }
        return nil
    }
}

// MARK: - Legacy Meal Slot Model (kept for compatibility)

@Model
final class MealSlotModel {
    @Attribute(.unique) var uid: String
    var recipeUid: String?
    var date: Date
    var orderFlag: Int
    var typeUid: String?
    var name: String
    var needsSync: Bool
    var lastModified: Date

    init(from paprikaMealItem: PaprikaMealItem) {
        self.uid = paprikaMealItem.uid
        self.recipeUid = paprikaMealItem.recipeUid
        self.date = paprikaMealItem.dateValue ?? Date()
        self.orderFlag = paprikaMealItem.orderFlag
        self.typeUid = paprikaMealItem.typeUid
        self.name = paprikaMealItem.name
        self.needsSync = false
        self.lastModified = Date()
    }

    init(date: Date, recipe: RecipeModel) {
        self.uid = UUID().uuidString
        self.recipeUid = recipe.uid
        self.date = date
        self.orderFlag = 0
        self.typeUid = nil
        self.name = recipe.name
        self.needsSync = true
        self.lastModified = Date()
    }

    func toPaprikaModel() -> PaprikaMealItem {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        return PaprikaMealItem(
            uid: uid,
            recipeUid: recipeUid,
            date: formatter.string(from: date),
            orderFlag: orderFlag,
            typeUid: typeUid,
            name: name
        )
    }
}
