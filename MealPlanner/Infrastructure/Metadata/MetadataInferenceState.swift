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

    /// Whether inference is currently running
    private(set) var isRunning: Bool = false

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
    @MainActor
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

    /// Stats from the last normalisation run
    private(set) var lastNormalisationStats: (total: Int, normalised: Int, unparseable: Int)?

    /// Manually run inference on all recipes (for pre-synced libraries)
    @MainActor
    func runManually(container: ModelContainer) async {
        guard !isRunning else { return }
        isRunning = true

        let engine = MetadataInferenceEngine()
        let result = await engine.runInBackground(container: container)

        if result.inferred > 0 {
            SyncEventLog.shared.info("Metadata: manually inferred effort level for \(result.inferred) recipes")
        }
        if result.normalised > 0 {
            SyncEventLog.shared.info("Ingredients: normalised \(result.normalised) recipes")
        }

        refresh(container: container)
        isRunning = false

        if result.inferred > 0 && unreviewedCount > 0 {
            shouldShowPostSyncPrompt = true
        }
    }
}
