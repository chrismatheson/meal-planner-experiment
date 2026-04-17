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

// MARK: - Meal Slot Model (SwiftData)

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
