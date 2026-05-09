import XCTest
@testable import paprikaplanner

final class MetadataResolverTests: XCTestCase {
    func test_noOverride_returnsInferred() {
        let recipe = makeRecipe(totalTime: "20 min", ingredients: 3)
        XCTAssertEqual(MetadataResolver.effectiveEffortLevel(recipe: recipe, override: nil), .quick)
    }

    func test_overridePresent_trumpsInference() {
        let recipe = makeRecipe(totalTime: "20 min", ingredients: 3)
        let override = MetadataOverrideStub(effortLevel: "elaborate", isKidFriendly: nil, source: "manual")
        XCTAssertEqual(MetadataResolver.effectiveEffortLevel(recipe: recipe, override: override), .elaborate)
    }

    func test_overrideNilEffort_fallsBackToInference() {
        let recipe = makeRecipe(totalTime: "90 min", ingredients: 10)
        let override = MetadataOverrideStub(effortLevel: nil, isKidFriendly: true, source: "confirmed")
        XCTAssertEqual(MetadataResolver.effectiveEffortLevel(recipe: recipe, override: override), .elaborate)
    }

    func test_kidFriendly_fromOverride() {
        let override = MetadataOverrideStub(effortLevel: nil, isKidFriendly: true, source: "manual")
        XCTAssertEqual(MetadataResolver.effectiveKidFriendly(override: override), true)
    }

    func test_kidFriendly_nilWhenNoOverride() {
        XCTAssertNil(MetadataResolver.effectiveKidFriendly(override: nil))
    }

    func test_kidFriendly_nilWhenOverrideUnset() {
        let override = MetadataOverrideStub(effortLevel: "quick", isKidFriendly: nil, source: "inferred")
        XCTAssertNil(MetadataResolver.effectiveKidFriendly(override: override))
    }

    func test_shouldReInfer_trueForInferredSource() {
        let override = MetadataOverrideStub(effortLevel: "quick", isKidFriendly: nil, source: "inferred")
        XCTAssertTrue(MetadataResolver.shouldReInfer(override: override))
    }

    func test_shouldReInfer_falseForConfirmedSource() {
        let override = MetadataOverrideStub(effortLevel: "quick", isKidFriendly: nil, source: "confirmed")
        XCTAssertFalse(MetadataResolver.shouldReInfer(override: override))
    }

    func test_shouldReInfer_falseForManualSource() {
        let override = MetadataOverrideStub(effortLevel: "quick", isKidFriendly: nil, source: "manual")
        XCTAssertFalse(MetadataResolver.shouldReInfer(override: override))
    }

    // MARK: - Helpers

    private struct MetadataOverrideStub: MetadataOverrideProtocol {
        var effortLevel: String?
        var isKidFriendly: Bool?
        var source: String
    }

    private func makeRecipe(totalTime: String?, ingredients count: Int?) -> RecipeModel {
        let ingStr = count.map { (0..<$0).map { "ing \($0)" }.joined(separator: "\n") }
        return RecipeModel(from: PaprikaRecipe(
            uid: "t-\(UUID().uuidString.prefix(6))", name: "Test", ingredients: ingStr,
            directions: nil, description: nil, servings: nil,
            prepTime: nil, cookTime: nil, totalTime: totalTime,
            rating: nil, categories: [], photo: nil, photoUrl: nil,
            source: nil, sourceUrl: nil, onFavorites: nil, created: nil, hash: "h", photoHash: nil))
    }
}
