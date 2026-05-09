import Foundation
import SwiftData

/// Observable state tracking unreviewed metadata overrides.
/// Injected into the environment so views can react to post-sync prompts and banners.
@Observable
final class MetadataInferenceState {
    /// Number of overrides with source == "inferred" (not yet reviewed by user)
    private(set) var unreviewedCount: Int = 0

    /// Whether the post-sync prompt should be shown (set after inference completes)
    private(set) var shouldShowPostSyncPrompt: Bool = false

    /// True if there are any unreviewed overrides
    var hasUnreviewed: Bool { unreviewedCount > 0 }

    /// Refresh the unreviewed count from SwiftData
    func refresh(container: ModelContainer) {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<RecipeMetadataOverride>(
            predicate: #Predicate { $0.source == "inferred" }
        )
        unreviewedCount = (try? context.fetchCount(descriptor)) ?? 0
    }

    /// Called after inference completes to trigger the post-sync prompt
    func triggerPostSyncPrompt(inferredCount: Int, container: ModelContainer) {
        refresh(container: container)
        if unreviewedCount > 0 {
            shouldShowPostSyncPrompt = true
        }
    }

    /// Dismiss the post-sync prompt
    func dismissPostSyncPrompt() {
        shouldShowPostSyncPrompt = false
    }
}
