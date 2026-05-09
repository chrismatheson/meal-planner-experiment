import XCTest
@testable import paprikaplanner

final class PlanGeneratorTests: XCTestCase {
    func test_generateWeek_returnsSevenUniqueRecipes_whenEnoughRecipesExist() {
        let generator = PlanGenerator(chooseRecipe: firstChoice)
        let recipes = makeRecipes(count: 8)

        let days = generator.generateWeek(from: recipes, excluding: [])

        XCTAssertEqual(days.count, 7)
        XCTAssertEqual(Set(days.compactMap(\.recipe?.uid)).count, 7)
    }

    func test_generateWeek_respectsExcludedRecipeIds() {
        let generator = PlanGenerator(chooseRecipe: firstChoice)
        let recipes = makeRecipes(count: 10)
        let excluded = Set(recipes.prefix(3).map(\.uid))

        let days = generator.generateWeek(from: recipes, excluding: excluded)

        XCTAssertTrue(days.compactMap(\.recipe?.uid).allSatisfy { !excluded.contains($0) })
    }

    func test_regenerateDay_replacesRecipeUsingUpdatedExclusions() {
        let generator = PlanGenerator(chooseRecipe: firstChoice)
        let recipes = makeRecipes(count: 8)
        let initialDays = generator.generateWeek(from: recipes, excluding: [])
        let rejectedId = try! XCTUnwrap(initialDays[0].recipe?.uid)

        let regeneratedDay = generator.regenerateDay(
            day: 0,
            in: initialDays,
            from: recipes,
            excluding: [rejectedId]
        )

        XCTAssertNotNil(regeneratedDay)
        XCTAssertNotEqual(regeneratedDay?.recipe?.uid, rejectedId)
    }

    func test_generateWeek_allowsFallbackWhenExclusionsLeaveTooFewRecipes() {
        let generator = PlanGenerator(chooseRecipe: firstChoice)
        let recipes = makeRecipes(count: 4)
        let excluded = Set(recipes.dropFirst().map(\.uid))

        let days = generator.generateWeek(from: recipes, excluding: excluded)

        XCTAssertEqual(days.count, 7)
        XCTAssertEqual(Set(days.compactMap(\.recipe?.uid)).count, recipes.count)
    }

    private func firstChoice(_ recipes: [RecipeModel]) -> RecipeModel? {
        recipes.first
    }

    private func makeRecipes(count: Int) -> [RecipeModel] {
        (0..<count).map { index in
            RecipeModel(from: PaprikaRecipe(
                uid: "recipe-\(index)",
                name: "Recipe \(index)",
                ingredients: nil,
                directions: nil,
                description: nil,
                servings: nil,
                prepTime: nil,
                cookTime: nil,
                totalTime: nil,
                rating: nil,
                categories: index.isMultiple(of: 2) ? ["Italian"] : ["Mexican"],
                photo: nil,
                photoUrl: nil,
                source: nil,
                sourceUrl: nil,
                onFavorites: nil,
                created: nil,
                hash: "hash-\(index)",
                photoHash: nil
            ))
        }
    }
}
