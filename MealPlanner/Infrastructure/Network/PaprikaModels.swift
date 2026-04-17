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

struct RecipesResponse: Decodable {
    let result: [PaprikaRecipe]
}

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
    let categories: [String]?
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
