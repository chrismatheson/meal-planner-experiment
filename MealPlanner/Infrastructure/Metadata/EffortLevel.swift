import Foundation

enum EffortLevel: String, CaseIterable, Codable {
    case quick, normal, elaborate

    /// Cycle to the next effort level (quick → normal → elaborate → quick)
    var next: EffortLevel {
        switch self {
        case .quick: .normal
        case .normal: .elaborate
        case .elaborate: .quick
        }
    }

    var categoryName: String {
        switch self {
        case .quick: "MP: Quick"
        case .normal: "MP: Normal"
        case .elaborate: "MP: Elaborate"
        }
    }

    static func infer(from recipe: RecipeModel) -> EffortLevel {
        let minutes = TimeParser.parseToMinutes(recipe.totalTime)
            ?? TimeParser.parseToMinutes(recipe.cookTime)
            ?? TimeParser.parseToMinutes(recipe.prepTime)
        if let minutes {
            if minutes <= 30 { return .quick }
            if minutes > 60 { return .elaborate }
            return .normal
        }
        if let count = IngredientCounter.count(recipe.ingredients) {
            if count <= 5 { return .quick }
            if count > 15 { return .elaborate }
            return .normal
        }
        return .normal
    }
}

enum IngredientCounter {
    static func count(_ ingredients: String?) -> Int? {
        guard let ingredients else { return nil }
        return ingredients.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
    }
}
