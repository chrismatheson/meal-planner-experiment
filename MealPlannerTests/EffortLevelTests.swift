import XCTest
@testable import paprikaplanner

final class EffortLevelTests: XCTestCase {
    func test_countIngredients_splitsOnNewlines() {
        XCTAssertEqual(IngredientCounter.count("1 lb pasta\n2 eggs\n1 cup cheese"), 3)
    }
    func test_countIngredients_filtersBlankLines() {
        XCTAssertEqual(IngredientCounter.count("1 lb pasta\n\n2 eggs\n  \n1 cup cheese"), 3)
    }
    func test_countIngredients_nilReturnsNil() { XCTAssertNil(IngredientCounter.count(nil)) }
    func test_quick_byTime() {
        XCTAssertEqual(EffortLevel.infer(from: makeRecipe(totalTime: "25 min", ingredients: 8)), .quick)
    }
    func test_quick_byIngredients_noTime() {
        XCTAssertEqual(EffortLevel.infer(from: makeRecipe(totalTime: nil, ingredients: 4)), .quick)
    }
    func test_elaborate_byTime() {
        XCTAssertEqual(EffortLevel.infer(from: makeRecipe(totalTime: "90 min", ingredients: 8)), .elaborate)
    }
    func test_elaborate_byIngredients_noTime() {
        XCTAssertEqual(EffortLevel.infer(from: makeRecipe(totalTime: nil, ingredients: 18)), .elaborate)
    }
    func test_normal_middleRange() {
        XCTAssertEqual(EffortLevel.infer(from: makeRecipe(totalTime: "45 min", ingredients: 10)), .normal)
    }
    func test_timeWinsOverIngredients() {
        XCTAssertEqual(EffortLevel.infer(from: makeRecipe(totalTime: "20 min", ingredients: 16)), .quick)
    }
    func test_noDataDefaultsToNormal() {
        XCTAssertEqual(EffortLevel.infer(from: makeRecipe(totalTime: nil, ingredients: nil)), .normal)
    }
    func test_fallback_cookTime() {
        let r = makeRecipe(prepTime: "10 min", cookTime: "25 min", totalTime: nil, ingredients: 10)
        XCTAssertEqual(EffortLevel.infer(from: r), .quick)
    }
    func test_boundary30_isQuick() {
        XCTAssertEqual(EffortLevel.infer(from: makeRecipe(totalTime: "30 min", ingredients: 10)), .quick)
    }
    func test_boundary60_isNormal() {
        XCTAssertEqual(EffortLevel.infer(from: makeRecipe(totalTime: "60 min", ingredients: 10)), .normal)
    }
    func test_boundary61_isElaborate() {
        XCTAssertEqual(EffortLevel.infer(from: makeRecipe(totalTime: "61 min", ingredients: 10)), .elaborate)
    }

    private func makeRecipe(prepTime: String? = nil, cookTime: String? = nil,
                            totalTime: String?, ingredients count: Int?) -> RecipeModel {
        let ingStr = count.map { (0..<$0).map { "ing \($0)" }.joined(separator: "\n") }
        return RecipeModel(from: PaprikaRecipe(
            uid: "t-\(UUID().uuidString.prefix(6))", name: "Test", ingredients: ingStr,
            directions: nil, description: nil, servings: nil,
            prepTime: prepTime, cookTime: cookTime, totalTime: totalTime,
            rating: nil, categories: [], photo: nil, photoUrl: nil,
            source: nil, sourceUrl: nil, onFavorites: nil, created: nil, hash: "h", photoHash: nil))
    }
}
