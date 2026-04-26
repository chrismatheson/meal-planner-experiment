import Foundation

/// Detects the primary protein type from recipe ingredients
enum ProteinType: String, CaseIterable {
    case chicken
    case beef
    case pork
    case fish
    case seafood
    case turkey
    case lamb
    case tofu
    case vegetarian
    case unknown
    
    var displayName: String {
        switch self {
        case .chicken: return "Chicken"
        case .beef: return "Beef"
        case .pork: return "Pork"
        case .fish: return "Fish"
        case .seafood: return "Seafood"
        case .turkey: return "Turkey"
        case .lamb: return "Lamb"
        case .tofu: return "Tofu/Plant-based"
        case .vegetarian: return "Vegetarian"
        case .unknown: return "Unknown"
        }
    }
}

/// Utility to detect protein type from recipe data
struct ProteinDetector {
    
    /// Keywords for each protein type (order matters - more specific first)
    private static let proteinKeywords: [(ProteinType, [String])] = [
        (.chicken, ["chicken", "poultry"]),
        (.turkey, ["turkey"]),
        (.beef, ["beef", "steak", "ground beef", "brisket", "chuck", "sirloin", "ribeye"]),
        (.pork, ["pork", "bacon", "ham", "sausage", "chorizo", "pancetta"]),
        (.lamb, ["lamb", "mutton"]),
        (.fish, ["salmon", "tuna", "cod", "tilapia", "halibut", "trout", "bass", "mahi", "snapper", "fish"]),
        (.seafood, ["shrimp", "prawn", "lobster", "crab", "scallop", "mussel", "clam", "oyster", "calamari", "squid", "octopus"]),
        (.tofu, ["tofu", "tempeh", "seitan", "beyond meat", "impossible", "plant-based"]),
    ]
    
    /// Negative keywords that indicate broth/flavoring rather than main protein
    private static let negativeKeywords = ["broth", "stock", "bouillon", "extract", "flavoring", "sauce"]
    
    /// Detect the primary protein from recipe ingredients
    static func detect(from ingredients: String?) -> ProteinType {
        guard let ingredients = ingredients?.lowercased(), !ingredients.isEmpty else {
            return .unknown
        }
        
        for (proteinType, keywords) in proteinKeywords {
            for keyword in keywords {
                if containsAsMainIngredient(ingredients: ingredients, keyword: keyword) {
                    return proteinType
                }
            }
        }
        
        // Check for vegetarian indicators
        if isLikelyVegetarian(ingredients) {
            return .vegetarian
        }
        
        return .unknown
    }
    
    /// Detect protein from recipe name + categories as fallback
    static func detect(name: String?, categories: [String]?) -> ProteinType {
        // Check categories first
        if let categories = categories {
            let categoryText = categories.joined(separator: " ").lowercased()
            for (proteinType, keywords) in proteinKeywords {
                for keyword in keywords {
                    if categoryText.contains(keyword) {
                        return proteinType
                    }
                }
            }
            if categoryText.contains("vegetarian") || categoryText.contains("vegan") {
                return .vegetarian
            }
        }
        
        // Check recipe name
        if let name = name?.lowercased() {
            for (proteinType, keywords) in proteinKeywords {
                for keyword in keywords {
                    if name.contains(keyword) {
                        return proteinType
                    }
                }
            }
        }
        
        return .unknown
    }
    
    /// Check if a keyword appears as a main ingredient (not just flavoring)
    private static func containsAsMainIngredient(ingredients: String, keyword: String) -> Bool {
        guard ingredients.contains(keyword) else { return false }
        
        // Check if it's likely a broth/flavoring context
        let lines = ingredients.components(separatedBy: .newlines)
        for line in lines {
            if line.contains(keyword) {
                // Skip if this line also contains negative keywords
                let hasNegative = negativeKeywords.contains { line.contains($0) }
                if !hasNegative {
                    return true
                }
            }
        }
        return false
    }
    
    /// Check if recipe is likely vegetarian (no obvious meat)
    private static func isLikelyVegetarian(_ ingredients: String) -> Bool {
        let meatKeywords = ["chicken", "beef", "pork", "lamb", "turkey", "fish", "salmon", 
                           "tuna", "shrimp", "bacon", "sausage", "meat"]
        return !meatKeywords.contains { ingredients.contains($0) }
    }
}
