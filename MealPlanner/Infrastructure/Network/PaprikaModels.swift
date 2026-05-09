import Foundation

// MARK: - Error Types

enum PaprikaError: LocalizedError {
    case notAuthenticated
    case invalidCredentials
    case invalidResponse
    case serverError(Int)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign in to continue."
        case .invalidCredentials:
            return "Invalid email or password. Please try again."
        case .invalidResponse:
            return "Received an invalid response from the server."
        case .serverError(let code):
            return "Server error (code \(code)). Please try again later."
        case .networkError:
            return "Network error. Please check your connection."
        }
    }
}

// MARK: - API Response Types

struct LoginResponse: Decodable {
    let result: LoginResult
}

struct LoginResult: Decodable {
    let token: String?
    let email: String?
    let error: String?
}

/// Response from /sync/recipes/ - returns UIDs and hashes only
struct RecipesListResponse: Decodable {
    let result: [RecipeStub]
}

struct RecipeStub: Decodable {
    let uid: String
    let hash: String
}

/// Response from /sync/recipe/{uid}/ - returns full recipe
struct RecipeDetailResponse: Decodable {
    let result: PaprikaRecipe
}

struct MealItemsResponse: Decodable {
    let result: [PaprikaMealItem]
}

// MARK: - Domain Types

struct PaprikaRecipe: Codable, Identifiable {
    var id: String { uid }
    
    let uid: String
    let name: String
    let ingredients: String?
    let directions: String?
    let description: String?
    let servings: String?
    let prepTime: String?
    let cookTime: String?
    let totalTime: String?
    let rating: Int?
    var categories: [String]?
    let photo: String?
    let photoUrl: String?
    let source: String?
    let sourceUrl: String?
    let onFavorites: Bool?
    let created: String?
    let hash: String?
    let photoHash: String?
    
    enum CodingKeys: String, CodingKey {
        case uid, name, ingredients, directions, description
        case servings, rating, categories, photo, source, created, hash
        case prepTime = "prep_time"
        case cookTime = "cook_time"
        case totalTime = "total_time"
        case photoUrl = "photo_url"
        case sourceUrl = "source_url"
        case onFavorites = "on_favorites"
        case photoHash = "photo_hash"
    }
}

struct PaprikaMealItem: Codable, Identifiable {
    var id: String { uid }

    let uid: String
    var recipeUid: String?
    var date: String  // Format: YYYY-MM-DD
    var orderFlag: Int
    var typeUid: String?
    var name: String

    enum CodingKeys: String, CodingKey {
        case uid, date, name
        case recipeUid = "recipe_uid"
        case orderFlag = "order_flag"
        case typeUid = "type_uid"
    }
}

/// Meal model for v1 sync API (used for write-back)
/// Format discovered from gist: mattdsteele/7386ec363badfdeaad05a418b9a1f30a
struct PaprikaMeal: Codable, Identifiable {
    var id: String { uid }

    var uid: String
    var recipeUid: String?
    var date: String  // Format: "YYYY-MM-DD HH:MM:SS" (with time!)
    var name: String
    var orderFlag: Int
    var type: Int  // 0=Breakfast, 1=Lunch, 2=Dinner
    var deleted: Bool  // Required for POST, but may not be returned by GET

    enum CodingKeys: String, CodingKey {
        case uid, date, name, type, deleted
        case recipeUid = "recipe_uid"
        case orderFlag = "order_flag"
    }

    /// Custom decoder to handle optional `deleted` field from API responses
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uid = try container.decode(String.self, forKey: .uid)
        recipeUid = try container.decodeIfPresent(String.self, forKey: .recipeUid)
        date = try container.decode(String.self, forKey: .date)
        name = try container.decode(String.self, forKey: .name)
        orderFlag = try container.decode(Int.self, forKey: .orderFlag)
        type = try container.decode(Int.self, forKey: .type)
        deleted = try container.decodeIfPresent(Bool.self, forKey: .deleted) ?? false
    }

    /// Create from a MealItem
    init(from item: PaprikaMealItem) {
        self.uid = item.uid
        self.recipeUid = item.recipeUid
        // Ensure date has time component
        self.date = item.date.contains(" ") ? item.date : "\(item.date) 00:00:00"
        self.name = item.name
        self.orderFlag = item.orderFlag
        self.type = 2  // Default to Dinner
        self.deleted = false
    }

    /// Create for a specific date and recipe
    init(uid: String = UUID().uuidString.uppercased(), date: Date, recipe: PaprikaRecipe, type: Int = 2) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"  // Include time!

        self.uid = uid
        self.recipeUid = recipe.uid
        self.date = formatter.string(from: date)
        self.name = recipe.name
        self.orderFlag = 0
        self.type = type
        self.deleted = false
    }

    /// Direct memberwise initializer for creating from cached data
    init(uid: String, recipeUid: String?, date: String, name: String, orderFlag: Int, type: Int, deleted: Bool) {
        self.uid = uid
        self.recipeUid = recipeUid
        self.date = date
        self.name = name
        self.orderFlag = orderFlag
        self.type = type
        self.deleted = deleted
    }
}

struct MealsResponse: Decodable {
    let result: [PaprikaMeal]
}

// MARK: - Categories

struct CategoriesResponse: Decodable {
    let result: [PaprikaCategory]
}

struct PaprikaCategory: Codable, Identifiable {
    var id: String { uid }

    let uid: String
    let name: String
    let orderFlag: Int
    let parentUid: String?

    enum CodingKeys: String, CodingKey {
        case uid, name
        case orderFlag = "order_flag"
        case parentUid = "parent_uid"
    }
}

// MARK: - Convenience Extensions

extension PaprikaRecipe {
    var displayTime: String? {
        totalTime ?? cookTime ?? prepTime
    }
    
    var firstCategory: String? {
        categories?.first
    }
    
    var imageURL: URL? {
        guard let photoUrl = photoUrl else { return nil }
        return URL(string: photoUrl)
    }
}

extension PaprikaMealItem {
    var dateValue: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: date)
    }
    
    static func create(for date: Date, recipe: PaprikaRecipe) -> PaprikaMealItem {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        return PaprikaMealItem(
            uid: UUID().uuidString,
            recipeUid: recipe.uid,
            date: formatter.string(from: date),
            orderFlag: 0,
            typeUid: nil,
            name: recipe.name
        )
    }
}
