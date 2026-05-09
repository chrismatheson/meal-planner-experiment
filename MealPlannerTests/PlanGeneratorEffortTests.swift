import XCTest
@testable import paprikaplanner

final class PlanGeneratorEffortTests: XCTestCase {

    func test_effortPreference_prefersMatchingRecipes() {
        // 5 quick recipes (20 min), 5 elaborate (90 min)
        let recipes = (0..<5).map { makeRecipe(uid: "q\($0)", totalTime: "20 min") }
            + (0..<5).map { makeRecipe(uid: "e\($0)", totalTime: "90 min") }

        // With quick preference and deterministic chooser (first), should pick quick first
        let generator = PlanGenerator(
            chooseRecipe: { $0.first },
            effortResolver: { recipe, _ in EffortLevel.infer(from: recipe) }
        )
        let days = generator.generateWeek(
            from: recipes, excluding: [],
            effortPreferences: [.quick, .quick, .quick, .quick, nil, nil, nil]
        )

        // First 4 days should be quick recipes
        for i in 0..<4 {
            let effort = EffortLevel.infer(from: days[i].recipe!)
            XCTAssertEqual(effort, .quick, "Day \(i) should be quick")
        }
    }

    func test_effortPreference_fallsBackWhenPoolExhausted() {
        // Only 2 quick recipes
        let recipes = (0..<2).map { makeRecipe(uid: "q\($0)", totalTime: "20 min") }
            + (0..<5).map { makeRecipe(uid: "n\($0)", totalTime: "45 min") }

        let generator = PlanGenerator(
            chooseRecipe: { $0.first },
            effortResolver: { recipe, _ in EffortLevel.infer(from: recipe) }
        )
        let days = generator.generateWeek(
            from: recipes, excluding: [],
            effortPreferences: Array(repeating: .quick, count: 7)
        )

        // All 7 days should have recipes (falls back to non-quick)
        XCTAssertEqual(days.count, 7)
        XCTAssertTrue(days.allSatisfy { $0.recipe != nil })
    }

    func test_noPreference_behavesLikeOriginal() {
        let recipes = (0..<8).map { makeRecipe(uid: "r\($0)", totalTime: "45 min") }
        let generator = PlanGenerator(chooseRecipe: { $0.first })
        let days = generator.generateWeek(from: recipes, excluding: [])

        XCTAssertEqual(days.count, 7)
        XCTAssertEqual(Set(days.compactMap(\.recipe?.uid)).count, 7)
    }

    private func makeRecipe(uid: String, totalTime: String) -> RecipeModel {
        RecipeModel(from: PaprikaRecipe(
            uid: uid, name: uid, ingredients: nil, directions: nil, description: nil,
            servings: nil, prepTime: nil, cookTime: nil, totalTime: totalTime,
            rating: nil, categories: [], photo: nil, photoUrl: nil,
            source: nil, sourceUrl: nil, onFavorites: nil, created: nil, hash: "h", photoHash: nil))
    }
}
