import SwiftData
import XCTest
@testable import paprikaplanner

final class StorageUsageManagerTests: XCTestCase {
    func testDirectorySizeCountsNestedFiles() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let nested = root.appendingPathComponent("nested", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 128).write(to: root.appendingPathComponent("one.bin"))
        try Data(repeating: 2, count: 256).write(to: nested.appendingPathComponent("two.bin"))

        let size = StorageUsageManager.directorySize(at: root)

        XCTAssertGreaterThanOrEqual(size, 384)
        try FileManager.default.removeItem(at: root)
    }

    func testClearImageCacheDeletesFilesOnDiskAndKeepsCacheDirectory() throws {
        try ImageCache.recreateDirectoryIfNeeded()
        let cachedFile = ImageCache.directoryURL.appendingPathComponent("cached-image.bin")
        try Data(repeating: 1, count: 128).write(to: cachedFile)

        try StorageUsageManager.clearImageCache()

        XCTAssertFalse(FileManager.default.fileExists(atPath: cachedFile.path))
        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: ImageCache.directoryURL.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
    }

    @MainActor
    func testSnapshotReportsSwiftDataRecordCounts() throws {
        let context = try makeContext()
        context.insert(RecipeModel(from: makeRecipe(uid: "recipe-1", name: "Pasta")))
        context.insert(CachedMealModel(from: makeMeal(uid: "meal-1", recipeUid: "recipe-1", name: "Pasta")))
        context.insert(CategoryModel(from: PaprikaCategory(uid: "cat-1", name: "Dinner", orderFlag: 0, parentUid: nil)))
        try context.save()

        let snapshot = try StorageUsageManager.snapshot(context: context)

        XCTAssertEqual(snapshot.recipeCount, 1)
        XCTAssertEqual(snapshot.cachedMealCount, 1)
        XCTAssertEqual(snapshot.categoryCount, 1)
    }

    @MainActor
    func testClearSyncedPaprikaDataRemovesRemoteCacheRecords() throws {
        let context = try makeContext()
        context.insert(RecipeModel(from: makeRecipe(uid: "recipe-1", name: "Pasta")))
        context.insert(CachedMealModel(from: makeMeal(uid: "meal-1", recipeUid: "recipe-1", name: "Pasta")))
        context.insert(CategoryModel(from: PaprikaCategory(uid: "cat-1", name: "Dinner", orderFlag: 0, parentUid: nil)))
        context.insert(SlotRuleModel(from: SlotRule(dayOfWeek: 2, constraint: .freeform(label: "Anything"))))
        try context.save()

        try StorageUsageManager.clearSyncedPaprikaData(context: context)

        XCTAssertEqual(try context.fetch(FetchDescriptor<RecipeModel>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<CachedMealModel>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<CategoryModel>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<SlotRuleModel>()).count, 1)
    }

    @MainActor
    func testClearSyncedPaprikaDataBlocksWhenMealsNeedSync() throws {
        let context = try makeContext()
        let meal = CachedMealModel(from: makeMeal(uid: "meal-1", recipeUid: "recipe-1", name: "Pasta"))
        meal.needsSync = true
        context.insert(meal)
        try context.save()

        XCTAssertThrowsError(try StorageUsageManager.clearSyncedPaprikaData(context: context)) { error in
            XCTAssertEqual(error.localizedDescription, "Sync 1 pending meal change before clearing local Paprika data.")
        }
    }

    @MainActor
    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            RecipeModel.self,
            MealSlotModel.self,
            CachedMealModel.self,
            CategoryModel.self,
            SlotRuleModel.self,
            RecipeMetadataOverride.self,
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        return ModelContext(container)
    }

    private func makeRecipe(uid: String, name: String) -> PaprikaRecipe {
        PaprikaRecipe(
            uid: uid,
            name: name,
            ingredients: nil,
            directions: nil,
            description: nil,
            servings: nil,
            prepTime: nil,
            cookTime: nil,
            totalTime: nil,
            rating: nil,
            categories: nil,
            photo: nil,
            photoUrl: nil,
            source: nil,
            sourceUrl: nil,
            onFavorites: false,
            created: nil,
            hash: nil,
            photoHash: nil
        )
    }

    private func makeMeal(uid: String, recipeUid: String, name: String) -> PaprikaMeal {
        PaprikaMeal(
            uid: uid,
            recipeUid: recipeUid,
            date: "2026-05-11 18:00:00",
            name: name,
            orderFlag: 0,
            type: 2,
            deleted: false
        )
    }
}
