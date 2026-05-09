import XCTest
import SwiftData
@testable import paprikaplanner

final class CategoryWriteBackEngineTests: XCTestCase {

    // MARK: - buildCategories Tests

    func test_buildCategories_addsEffortCategory() {
        let result = CategoryWriteBackEngine.buildCategories(
            existing: ["Italian"],
            effort: .quick,
            kidFriendly: nil
        )
        XCTAssertTrue(result.contains("Italian"))
        XCTAssertTrue(result.contains("MP: Quick"))
        XCTAssertEqual(result.count, 2)
    }

    func test_buildCategories_removesOldMPCategories() {
        let result = CategoryWriteBackEngine.buildCategories(
            existing: ["MP: Normal", "Italian"],
            effort: .quick,
            kidFriendly: nil
        )
        XCTAssertFalse(result.contains("MP: Normal"))
        XCTAssertTrue(result.contains("MP: Quick"))
        XCTAssertTrue(result.contains("Italian"))
        XCTAssertEqual(result.count, 2)
    }

    func test_buildCategories_addsKidFriendly() {
        let result = CategoryWriteBackEngine.buildCategories(
            existing: ["Italian"],
            effort: .normal,
            kidFriendly: true
        )
        XCTAssertTrue(result.contains("MP: Normal"))
        XCTAssertTrue(result.contains("MP: Kid-Friendly"))
        XCTAssertTrue(result.contains("Italian"))
        XCTAssertEqual(result.count, 3)
    }

    func test_buildCategories_doesNotAddKidFriendlyWhenFalse() {
        let result = CategoryWriteBackEngine.buildCategories(
            existing: ["Italian"],
            effort: .elaborate,
            kidFriendly: false
        )
        XCTAssertFalse(result.contains("MP: Kid-Friendly"))
        XCTAssertTrue(result.contains("MP: Elaborate"))
        XCTAssertEqual(result.count, 2)
    }

    func test_buildCategories_handlesNilExisting() {
        let result = CategoryWriteBackEngine.buildCategories(
            existing: nil,
            effort: .quick,
            kidFriendly: true
        )
        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result.contains("MP: Quick"))
        XCTAssertTrue(result.contains("MP: Kid-Friendly"))
    }

    func test_buildCategories_removesMultipleOldMPCategories() {
        let result = CategoryWriteBackEngine.buildCategories(
            existing: ["MP: Normal", "MP: Kid-Friendly", "Italian"],
            effort: .elaborate,
            kidFriendly: false
        )
        XCTAssertFalse(result.contains("MP: Normal"))
        XCTAssertFalse(result.contains("MP: Kid-Friendly"))
        XCTAssertTrue(result.contains("MP: Elaborate"))
        XCTAssertTrue(result.contains("Italian"))
        XCTAssertEqual(result.count, 2)
    }

    // MARK: - pendingSyncCount Tests

    func test_pendingSyncCount() throws {
        let schema = Schema([RecipeModel.self, RecipeMetadataOverride.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        let context = ModelContext(container)

        // One needing sync
        let override1 = RecipeMetadataOverride(
            recipeUid: "r1",
            effortLevel: "quick",
            source: "manual",
            needsSync: true
        )
        context.insert(override1)

        // One already synced
        let override2 = RecipeMetadataOverride(
            recipeUid: "r2",
            effortLevel: "normal",
            source: "confirmed",
            needsSync: false
        )
        context.insert(override2)

        try context.save()

        let count = CategoryWriteBackEngine.pendingSyncCount(context: context)
        XCTAssertEqual(count, 1)
    }
}
