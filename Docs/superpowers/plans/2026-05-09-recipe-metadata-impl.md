# Recipe Metadata Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Auto-classify recipes by effort level (quick/normal/elaborate) from Paprika time/ingredient data, with user overrides and kid-friendly tagging. Layer 1 (inference) + Layer 2 (override model + resolver). No UI in this plan.

**Architecture:** Pure functions for time parsing and inference, a SwiftData model for user overrides, a resolver that combines inferred + override data. Background inference runs in batches of 25 after recipe sync. The generation pipeline gains effort-level awareness as a soft scoring preference.

**Tech Stack:** Swift, SwiftData, XCTest, `@Observable`, structured concurrency

**Spec:** `Docs/superpowers/specs/2026-05-09-recipe-metadata-design.md`

**Test target name:** `paprikaplannerTests`
**Module import:** `@testable import paprikaplanner`
**Test command:** `xcodebuild test -scheme paprikaplanner -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:paprikaplannerTests/<TestClass> 2>&1 | tail -30`

---

### Task 1: TimeParser — parse Paprika freeform time strings to minutes

**Files:**
- Create: `MealPlanner/Infrastructure/Metadata/TimeParser.swift`
- Create: `MealPlannerTests/TimeParserTests.swift`

- [ ] **Step 1: Write failing tests for TimeParser**

Create `MealPlannerTests/TimeParserTests.swift`:

```swift
import XCTest
@testable import paprikaplanner

final class TimeParserTests: XCTestCase {
    func test_minutesOnly() {
        XCTAssertEqual(TimeParser.parseToMinutes("30 min"), 30)
        XCTAssertEqual(TimeParser.parseToMinutes("30 minutes"), 30)
        XCTAssertEqual(TimeParser.parseToMinutes("30 mins"), 30)
    }
    func test_hoursOnly() {
        XCTAssertEqual(TimeParser.parseToMinutes("1 hour"), 60)
        XCTAssertEqual(TimeParser.parseToMinutes("1 hr"), 60)
        XCTAssertEqual(TimeParser.parseToMinutes("2 hours"), 120)
    }
    func test_hoursAndMinutes() {
        XCTAssertEqual(TimeParser.parseToMinutes("1 hr 15 min"), 75)
        XCTAssertEqual(TimeParser.parseToMinutes("1 hour 30 minutes"), 90)
    }
    func test_colonFormat() {
        XCTAssertEqual(TimeParser.parseToMinutes("1:30"), 90)
        XCTAssertEqual(TimeParser.parseToMinutes("0:45"), 45)
    }
    func test_bareNumber() { XCTAssertEqual(TimeParser.parseToMinutes("90"), 90) }
    func test_unparseable() {
        XCTAssertNil(TimeParser.parseToMinutes(nil))
        XCTAssertNil(TimeParser.parseToMinutes(""))
        XCTAssertNil(TimeParser.parseToMinutes("quick"))
    }
    func test_whitespace() { XCTAssertEqual(TimeParser.parseToMinutes("  30 min  "), 30) }
}
```

- [ ] **Step 2: Run tests — expect compile error** (`Cannot find 'TimeParser' in scope`)

- [ ] **Step 3: Implement TimeParser**

Create `MealPlanner/Infrastructure/Metadata/TimeParser.swift`:

```swift
import Foundation

enum TimeParser {
    static func parseToMinutes(_ timeString: String?) -> Int? {
        guard let raw = timeString?.trimmingCharacters(in: .whitespaces),
              !raw.isEmpty else { return nil }
        if let r = parseColonFormat(raw) { return r }
        if let r = parseNaturalLanguage(raw) { return r }
        if let n = Int(raw) { return n }
        return nil
    }

    private static func parseColonFormat(_ s: String) -> Int? {
        let parts = s.split(separator: ":")
        guard parts.count == 2,
              let h = Int(parts[0].trimmingCharacters(in: .whitespaces)),
              let m = Int(parts[1].trimmingCharacters(in: .whitespaces))
        else { return nil }
        return h * 60 + m
    }

    private static func parseNaturalLanguage(_ s: String) -> Int? {
        let lower = s.lowercased()
        var total = 0; var found = false
        if let r = lower.range(of: "([0-9]+)\\s*(?:hours?|hrs?)", options: .regularExpression) {
            if let h = Int(lower[r].filter(\.isNumber)) { total += h * 60; found = true }
        }
        if let r = lower.range(of: "([0-9]+)\\s*(?:minutes?|mins?)", options: .regularExpression) {
            if let m = Int(lower[r].filter(\.isNumber)) { total += m; found = true }
        }
        return found ? total : nil
    }
}
```

- [ ] **Step 4: Run tests — expect all pass**
- [ ] **Step 5: Commit**
```bash
git add MealPlanner/Infrastructure/Metadata/TimeParser.swift MealPlannerTests/TimeParserTests.swift
git commit -m "feat: TimeParser — parse Paprika freeform time strings to minutes"
```

---

### Task 2: EffortLevel enum + IngredientCounter + inference

**Files:**
- Create: `MealPlanner/Infrastructure/Metadata/EffortLevel.swift`
- Create: `MealPlannerTests/EffortLevelTests.swift`

- [ ] **Step 1: Write failing tests**

Create `MealPlannerTests/EffortLevelTests.swift`:

```swift
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
```

- [ ] **Step 2: Run tests — expect compile error**
- [ ] **Step 3: Implement EffortLevel + IngredientCounter**

Create `MealPlanner/Infrastructure/Metadata/EffortLevel.swift`:

```swift
import Foundation

enum EffortLevel: String, CaseIterable, Codable {
    case quick, normal, elaborate

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
```

- [ ] **Step 4: Run tests — expect all pass**
- [ ] **Step 5: Commit**
```bash
git add MealPlanner/Infrastructure/Metadata/EffortLevel.swift MealPlannerTests/EffortLevelTests.swift
git commit -m "feat: EffortLevel enum, IngredientCounter, inference from recipe data"
```

---

### Task 3: RecipeMetadataOverride SwiftData model + MetadataResolver

**Files:**
- Create: `MealPlanner/Infrastructure/Metadata/RecipeMetadataOverride.swift`
- Create: `MealPlanner/Infrastructure/Metadata/MetadataResolver.swift`
- Create: `MealPlannerTests/MetadataResolverTests.swift`
- Modify: `MealPlanner/MealPlannerApp.swift` — add model to schema

- [ ] **Step 1: Write failing tests for MetadataResolver**

Create `MealPlannerTests/MetadataResolverTests.swift`:

```swift
import XCTest
@testable import paprikaplanner

final class MetadataResolverTests: XCTestCase {
    func test_noOverride_returnsInferred() {
        let recipe = makeRecipe(totalTime: "20 min", ingredients: 3)
        XCTAssertEqual(MetadataResolver.effectiveEffortLevel(recipe: recipe, override: nil), .quick)
    }

    func test_overridePresent_trumpsInference() {
        let recipe = makeRecipe(totalTime: "20 min", ingredients: 3) // inferred: quick
        let override = MetadataOverrideStub(effortLevel: "elaborate", isKidFriendly: nil, source: "manual")
        XCTAssertEqual(MetadataResolver.effectiveEffortLevel(recipe: recipe, override: override), .elaborate)
    }

    func test_overrideNilEffort_fallsBackToInference() {
        let recipe = makeRecipe(totalTime: "90 min", ingredients: 10) // inferred: elaborate
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

    // Helper stub that matches MetadataOverrideProtocol
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
```

- [ ] **Step 2: Run tests — expect compile error**

- [ ] **Step 3: Create RecipeMetadataOverride model**

Create `MealPlanner/Infrastructure/Metadata/RecipeMetadataOverride.swift`:

```swift
import Foundation
import SwiftData

/// Protocol for resolver to work with both real model and test stubs
protocol MetadataOverrideProtocol {
    var effortLevel: String? { get }
    var isKidFriendly: Bool? { get }
    var source: String { get }
}

@Model
final class RecipeMetadataOverride: MetadataOverrideProtocol {
    @Attribute(.unique) var recipeUid: String
    var effortLevel: String?     // "quick" | "normal" | "elaborate"
    var isKidFriendly: Bool?     // true | false | nil (unset)
    var source: String           // "inferred" | "confirmed" | "manual"
    var needsSync: Bool          // true if Paprika categories need updating
    var lastModified: Date

    init(recipeUid: String, effortLevel: String?, isKidFriendly: Bool? = nil,
         source: String = "inferred", needsSync: Bool = false) {
        self.recipeUid = recipeUid
        self.effortLevel = effortLevel
        self.isKidFriendly = isKidFriendly
        self.source = source
        self.needsSync = needsSync
        self.lastModified = Date()
    }
}
```

- [ ] **Step 4: Create MetadataResolver**

Create `MealPlanner/Infrastructure/Metadata/MetadataResolver.swift`:

```swift
import Foundation

enum MetadataResolver {
    static func effectiveEffortLevel(recipe: RecipeModel, override: MetadataOverrideProtocol?) -> EffortLevel {
        if let raw = override?.effortLevel, let level = EffortLevel(rawValue: raw) {
            return level
        }
        return EffortLevel.infer(from: recipe)
    }

    static func effectiveKidFriendly(override: MetadataOverrideProtocol?) -> Bool? {
        override?.isKidFriendly
    }

    static func shouldReInfer(override: MetadataOverrideProtocol?) -> Bool {
        guard let override else { return true }
        return override.source == "inferred"
    }
}
```

- [ ] **Step 5: Add RecipeMetadataOverride to schema**

In `MealPlanner/MealPlannerApp.swift`, add `RecipeMetadataOverride.self` to the schema array:

```swift
let schema = Schema([
    RecipeModel.self,
    MealSlotModel.self,
    CachedMealModel.self,
    CategoryModel.self,
    SlotRuleModel.self,
    RecipeMetadataOverride.self,
])
```

- [ ] **Step 6: Run tests — expect all pass**
- [ ] **Step 7: Commit**
```bash
git add MealPlanner/Infrastructure/Metadata/RecipeMetadataOverride.swift \
       MealPlanner/Infrastructure/Metadata/MetadataResolver.swift \
       MealPlannerTests/MetadataResolverTests.swift \
       MealPlanner/MealPlannerApp.swift
git commit -m "feat: RecipeMetadataOverride model, MetadataResolver, schema registration"
```

---

### Task 4: MetadataInferenceEngine — background batched inference after sync

**Files:**
- Create: `MealPlanner/Infrastructure/Metadata/MetadataInferenceEngine.swift`
- Create: `MealPlannerTests/MetadataInferenceEngineTests.swift`
- Modify: `MealPlanner/Infrastructure/Sync/RecipeSyncEngine.swift` — trigger inference after sync

- [ ] **Step 1: Write failing tests for MetadataInferenceEngine**

Create `MealPlannerTests/MetadataInferenceEngineTests.swift`:

```swift
import XCTest
import SwiftData
@testable import paprikaplanner

final class MetadataInferenceEngineTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

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
        let count = await engine.runSync(context: context)

        XCTAssertEqual(count, 3)
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
        let count = await engine.runSync(context: context)

        XCTAssertEqual(count, 0)
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
        let count = await engine.runSync(context: context)

        XCTAssertEqual(count, 1)
        let overrides = try! context.fetch(FetchDescriptor<RecipeMetadataOverride>())
        XCTAssertEqual(overrides.first?.effortLevel, "elaborate") // updated
    }
}
```

- [ ] **Step 2: Run tests — expect compile error**

- [ ] **Step 3: Implement MetadataInferenceEngine**

Create `MealPlanner/Infrastructure/Metadata/MetadataInferenceEngine.swift`:

```swift
import Foundation
import SwiftData

/// Runs effort-level inference on recipes in batches of 25, off the main thread.
final class MetadataInferenceEngine {
    static let batchSize = 25

    /// Run inference on a background ModelContext. Returns number of recipes processed.
    func runInBackground(container: ModelContainer) async -> Int {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return await runSync(context: context)
    }

    /// Synchronous inference for testing. Processes all eligible recipes.
    func runSync(context: ModelContext) async -> Int {
        // Fetch all recipes
        let recipes = (try? context.fetch(FetchDescriptor<RecipeModel>())) ?? []
        // Fetch existing overrides, keyed by recipeUid
        let overrides = (try? context.fetch(FetchDescriptor<RecipeMetadataOverride>())) ?? []
        let overridesByUid = Dictionary(uniqueKeysWithValues: overrides.map { ($0.recipeUid, $0) })

        var processed = 0

        // Process in batches
        for batchStart in stride(from: 0, to: recipes.count, by: Self.batchSize) {
            let batchEnd = min(batchStart + Self.batchSize, recipes.count)
            let batch = recipes[batchStart..<batchEnd]

            for recipe in batch {
                let existing = overridesByUid[recipe.uid]

                // Skip confirmed/manual overrides
                if !MetadataResolver.shouldReInfer(override: existing) { continue }

                let inferred = EffortLevel.infer(from: recipe)

                if let existing {
                    // Update existing inferred override
                    existing.effortLevel = inferred.rawValue
                    existing.lastModified = Date()
                } else {
                    // Create new override
                    let newOverride = RecipeMetadataOverride(
                        recipeUid: recipe.uid,
                        effortLevel: inferred.rawValue
                    )
                    context.insert(newOverride)
                }
                processed += 1
            }

            // Yield between batches to avoid starving other work
            if batchEnd < recipes.count {
                await Task.yield()
            }
        }

        try? context.save()
        return processed
    }
}
```

- [ ] **Step 4: Run tests — expect all pass**

- [ ] **Step 5: Wire inference into RecipeSyncEngine**

In `MealPlanner/Infrastructure/Sync/RecipeSyncEngine.swift`, after `syncStatus.markRecipesSynced()` (line ~163), add:

```swift
// Run metadata inference in background after recipe sync
Task.detached {
    let engine = MetadataInferenceEngine()
    let inferred = await engine.runInBackground(container: context.container)
    if inferred > 0 {
        SyncEventLog.shared.info("Metadata: inferred effort level for \(inferred) recipes")
    }
}
```

- [ ] **Step 6: Run all tests — expect all pass**
- [ ] **Step 7: Commit**
```bash
git add MealPlanner/Infrastructure/Metadata/MetadataInferenceEngine.swift \
       MealPlannerTests/MetadataInferenceEngineTests.swift \
       MealPlanner/Infrastructure/Sync/RecipeSyncEngine.swift
git commit -m "feat: MetadataInferenceEngine — background batched inference after sync"
```

---

### Task 5: PlanGenerator effort preference + weeknight/weekend awareness

**Files:**
- Modify: `MealPlanner/Features/PlanGeneration 2/PlanGenerator.swift` — add effort scoring
- Create: `MealPlannerTests/PlanGeneratorEffortTests.swift`

- [ ] **Step 1: Write failing tests for effort-aware generation**

Create `MealPlannerTests/PlanGeneratorEffortTests.swift`:

```swift
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
```

- [ ] **Step 2: Run tests — expect compile error**

- [ ] **Step 3: Add effort scoring to PlanGenerator**

Modify `MealPlanner/Features/PlanGeneration 2/PlanGenerator.swift`:

```swift
import Foundation

struct PlanGenerator {
    typealias RecipeChooser = ([RecipeModel]) -> RecipeModel?
    typealias EffortResolver = (RecipeModel, MetadataOverrideProtocol?) -> EffortLevel

    private let chooseRecipe: RecipeChooser
    private let maxSameCuisinePerWeek: Int
    private let effortResolver: EffortResolver

    init(
        maxSameCuisinePerWeek: Int = 2,
        chooseRecipe: @escaping RecipeChooser = { $0.randomElement() },
        effortResolver: @escaping EffortResolver = { recipe, _ in EffortLevel.infer(from: recipe) }
    ) {
        self.maxSameCuisinePerWeek = maxSameCuisinePerWeek
        self.chooseRecipe = chooseRecipe
        self.effortResolver = effortResolver
    }

    func generateWeek(
        from recipes: [RecipeModel],
        excluding excludedRecipeIds: Set<String>,
        startingOn startDate: Date = Date(),
        effortPreferences: [EffortLevel?]? = nil
    ) -> [DayPlan] {
        var days: [DayPlan] = []
        for dayOffset in 0..<7 {
            let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: startDate) ?? startDate
            let preference = effortPreferences?[safe: dayOffset] ?? nil
            let recipe = pickRecipe(from: recipes, for: days, excluding: excludedRecipeIds, effortPreference: preference)
            days.append(DayPlan(date: date, recipe: recipe))
        }
        return days
    }

    func regenerateDay(
        day index: Int, in currentDays: [DayPlan], from recipes: [RecipeModel],
        excluding excludedRecipeIds: Set<String>, effortPreference: EffortLevel? = nil
    ) -> DayPlan? {
        guard index >= 0 && index < currentDays.count else { return nil }
        var daysExcludingTarget = currentDays
        daysExcludingTarget.remove(at: index)
        let recipe = pickRecipe(from: recipes, for: daysExcludingTarget, excluding: excludedRecipeIds, effortPreference: effortPreference)
        return DayPlan(date: currentDays[index].date, recipe: recipe)
    }

    private func pickRecipe(
        from recipes: [RecipeModel], for existingDays: [DayPlan],
        excluding excludedRecipeIds: Set<String>, effortPreference: EffortLevel? = nil
    ) -> RecipeModel? {
        let usedIds = Set(existingDays.compactMap { $0.recipe?.uid })
        var available = recipes.filter { !usedIds.contains($0.uid) && !excludedRecipeIds.contains($0.uid) }

        if available.isEmpty {
            let fallback = recipes.filter { !usedIds.contains($0.uid) }
            return chooseRecipe(fallback)
        }

        // Effort preference: prefer matching, fall back to all
        if let preference = effortPreference {
            let matching = available.filter { effortResolver($0, nil) == preference }
            if !matching.isEmpty { available = matching }
        }

        // Cuisine diversity
        let overusedCuisines = getOverusedCuisines(in: existingDays)
        if !overusedCuisines.isEmpty {
            let diverse = available.filter { recipe in
                let cuisine = CuisineType.detect(from: recipe.categories)
                return cuisine == .unknown || !overusedCuisines.contains(cuisine)
            }
            if !diverse.isEmpty { return chooseRecipe(diverse) }
        }

        return chooseRecipe(available)
    }

    private func getOverusedCuisines(in days: [DayPlan]) -> Set<CuisineType> {
        var counts: [CuisineType: Int] = [:]
        for day in days {
            guard let recipe = day.recipe else { continue }
            let cuisine = CuisineType.detect(from: recipe.categories)
            if cuisine != .unknown { counts[cuisine, default: 0] += 1 }
        }
        return Set(counts.filter { $0.value >= maxSameCuisinePerWeek }.keys)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
```

- [ ] **Step 4: Run all tests — expect all pass** (including existing PlanGeneratorTests)
- [ ] **Step 5: Commit**
```bash
git add MealPlanner/Features/PlanGeneration\ 2/PlanGenerator.swift \
       MealPlannerTests/PlanGeneratorEffortTests.swift
git commit -m "feat: PlanGenerator effort preference + weeknight scoring support"
```

---

### Task 6: Push and verify

- [ ] **Step 1: Run full test suite**
```bash
xcodebuild test -scheme paprikaplanner -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | grep -E '(Test Suite|Executed|FAIL)'
```

- [ ] **Step 2: Push**
```bash
git push origin main
```