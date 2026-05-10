import XCTest
import SwiftData
@testable import paprikaplanner

final class MetadataInferenceEngineTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() {
        super.setUp()
        let schema = Schema([RecipeModel.self, RecipeMetadataOverride.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: config)
        context = ModelContext(container)
    }

    func test_inferCreatesOverridesForNewRecipes() async {
        // Insert 3 recipes with no overrides
        for i in 0..<3 {
            context.insert(RecipeModel(from: PaprikaRecipe(
                uid: "r\(i)", name: "R\(i)", ingredients: "a\nb\nc",
                directions: nil, description: nil, servings: nil,
                prepTime: nil, cookTime: nil, totalTime: "20 min",
                rating: nil, categories: [], photo: nil, photoUrl: nil,
                source: nil, sourceUrl: nil, onFavorites: nil, created: nil, hash: "h\(i)", photoHash: nil)))
        }
        try! context.save()

        let engine = MetadataInferenceEngine()
        let result = await engine.runSync(context: context)

        XCTAssertEqual(result.inferred, 3)
        let overrides = try! context.fetch(FetchDescriptor<RecipeMetadataOverride>())
        XCTAssertEqual(overrides.count, 3)
        XCTAssertTrue(overrides.allSatisfy { $0.source == "inferred" })
        XCTAssertTrue(overrides.allSatisfy { $0.effortLevel == "quick" }) // 20 min = quick
    }

    func test_inferSkipsConfirmedOverrides() async {
        let recipe = RecipeModel(from: PaprikaRecipe(
            uid: "r1", name: "R1", ingredients: nil, directions: nil, description: nil, servings: nil,
            prepTime: nil, cookTime: nil, totalTime: "20 min",
            rating: nil, categories: [], photo: nil, photoUrl: nil,
            source: nil, sourceUrl: nil, onFavorites: nil, created: nil, hash: "h1", photoHash: nil))
        context.insert(recipe)
        context.insert(RecipeMetadataOverride(recipeUid: "r1", effortLevel: "elaborate", source: "confirmed"))
        try! context.save()

        let engine = MetadataInferenceEngine()
        let result = await engine.runSync(context: context)

        XCTAssertEqual(result.inferred, 0)
        let overrides = try! context.fetch(FetchDescriptor<RecipeMetadataOverride>())
        XCTAssertEqual(overrides.first?.effortLevel, "elaborate") // unchanged
    }

    func test_inferUpdatesInferredOverrides() async {
        let recipe = RecipeModel(from: PaprikaRecipe(
            uid: "r1", name: "R1", ingredients: nil, directions: nil, description: nil, servings: nil,
            prepTime: nil, cookTime: nil, totalTime: "90 min",
            rating: nil, categories: [], photo: nil, photoUrl: nil,
            source: nil, sourceUrl: nil, onFavorites: nil, created: nil, hash: "h1", photoHash: nil))
        context.insert(recipe)
        context.insert(RecipeMetadataOverride(recipeUid: "r1", effortLevel: "quick", source: "inferred"))
        try! context.save()

        let engine = MetadataInferenceEngine()
        let result = await engine.runSync(context: context)

        XCTAssertEqual(result.inferred, 1)
        let overrides = try! context.fetch(FetchDescriptor<RecipeMetadataOverride>())
        XCTAssertEqual(overrides.first?.effortLevel, "elaborate") // updated
    }
}
