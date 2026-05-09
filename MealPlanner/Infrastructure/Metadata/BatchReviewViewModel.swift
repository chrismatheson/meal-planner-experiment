import Foundation
import SwiftData

/// ViewModel for batch review of inferred recipe metadata.
/// Groups unreviewed overrides by effort level with progress tracking.
@Observable
final class BatchReviewViewModel {

    // MARK: - Types

    struct ReviewSection: Identifiable {
        let id = UUID()
        let effortLevel: EffortLevel
        var items: [ReviewItem]
    }

    struct ReviewItem: Identifiable {
        let id: String  // recipeUid
        let recipeName: String
        let imageURL: URL?
        var effortLevel: EffortLevel
        var isKidFriendly: Bool?
        var isReviewed: Bool
    }

    // MARK: - Published State

    var sections: [ReviewSection] = []
    var totalCount: Int = 0
    var reviewedCount: Int = 0

    var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(reviewedCount) / Double(totalCount)
    }

    // MARK: - Load

    func load(container: ModelContainer) async {
        let context = ModelContext(container)

        // Fetch unreviewed overrides
        let overrideDescriptor = FetchDescriptor<RecipeMetadataOverride>(
            predicate: #Predicate { $0.source == "inferred" }
        )
        let overrides = (try? context.fetch(overrideDescriptor)) ?? []

        // Fetch all recipes to get names/images
        let recipeDescriptor = FetchDescriptor<RecipeModel>()
        let recipes = (try? context.fetch(recipeDescriptor)) ?? []
        let recipesByUid = Dictionary(uniqueKeysWithValues: recipes.map { ($0.uid, $0) })

        // Build review items
        var itemsByLevel: [EffortLevel: [ReviewItem]] = [:]

        for override in overrides {
            let level = EffortLevel(rawValue: override.effortLevel ?? "normal") ?? .normal
            let recipe = recipesByUid[override.recipeUid]

            let item = ReviewItem(
                id: override.recipeUid,
                recipeName: recipe?.name ?? "Unknown Recipe",
                imageURL: recipe?.imageURL,
                effortLevel: level,
                isKidFriendly: override.isKidFriendly,
                isReviewed: false
            )

            itemsByLevel[level, default: []].append(item)
        }

        // Build sections in order: quick, normal, elaborate
        let orderedSections = EffortLevel.allCases.compactMap { level -> ReviewSection? in
            guard let items = itemsByLevel[level], !items.isEmpty else { return nil }
            return ReviewSection(effortLevel: level, items: items)
        }

        await MainActor.run {
            self.sections = orderedSections
            self.totalCount = overrides.count
            self.reviewedCount = 0
        }
    }

    // MARK: - Actions

    /// Confirm a recipe's inferred metadata (source → "confirmed")
    func confirmItem(_ itemId: String, container: ModelContainer) {
        let context = ModelContext(container)
        let uid = itemId
        var descriptor = FetchDescriptor<RecipeMetadataOverride>(
            predicate: #Predicate<RecipeMetadataOverride> { $0.recipeUid == uid }
        )
        descriptor.fetchLimit = 1

        guard let override = (try? context.fetch(descriptor))?.first else { return }
        override.source = "confirmed"
        override.lastModified = Date()
        try? context.save()

        // Update local state
        markReviewed(itemId)
    }

    /// Cycle effort level for an item
    func cycleEffort(_ itemId: String, container: ModelContainer) {
        let context = ModelContext(container)
        let uid = itemId
        var descriptor = FetchDescriptor<RecipeMetadataOverride>(
            predicate: #Predicate<RecipeMetadataOverride> { $0.recipeUid == uid }
        )
        descriptor.fetchLimit = 1

        guard let override = (try? context.fetch(descriptor))?.first else { return }
        let current = EffortLevel(rawValue: override.effortLevel ?? "normal") ?? .normal
        let next = current.next
        override.effortLevel = next.rawValue
        override.source = "manual"
        override.needsSync = true
        override.lastModified = Date()
        try? context.save()

        // Update local state
        updateEffortLevel(itemId, to: next)
    }

    /// Toggle kid-friendly for an item
    func toggleKidFriendly(_ itemId: String, container: ModelContainer) {
        let context = ModelContext(container)
        let uid = itemId
        var descriptor = FetchDescriptor<RecipeMetadataOverride>(
            predicate: #Predicate<RecipeMetadataOverride> { $0.recipeUid == uid }
        )
        descriptor.fetchLimit = 1

        guard let override = (try? context.fetch(descriptor))?.first else { return }
        override.isKidFriendly = !(override.isKidFriendly ?? false)
        override.needsSync = true
        override.lastModified = Date()
        try? context.save()

        // Update local state
        updateKidFriendly(itemId, to: override.isKidFriendly)
    }

    // MARK: - Private

    private func markReviewed(_ itemId: String) {
        for i in sections.indices {
            if let j = sections[i].items.firstIndex(where: { $0.id == itemId }) {
                sections[i].items[j].isReviewed = true
                reviewedCount += 1
                return
            }
        }
    }

    private func updateEffortLevel(_ itemId: String, to level: EffortLevel) {
        for i in sections.indices {
            if let j = sections[i].items.firstIndex(where: { $0.id == itemId }) {
                sections[i].items[j].effortLevel = level
                return
            }
        }
    }

    private func updateKidFriendly(_ itemId: String, to value: Bool?) {
        for i in sections.indices {
            if let j = sections[i].items.firstIndex(where: { $0.id == itemId }) {
                sections[i].items[j].isKidFriendly = value
                return
            }
        }
    }
}
