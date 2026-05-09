import Foundation

enum MetadataResolver {
    /// Resolve effective effort level: override trumps inference.
    static func effectiveEffortLevel(recipe: RecipeModel, override: MetadataOverrideProtocol?) -> EffortLevel {
        if let raw = override?.effortLevel, let level = EffortLevel(rawValue: raw) {
            return level
        }
        return EffortLevel.infer(from: recipe)
    }

    /// Resolve kid-friendly status: only comes from overrides (no inference).
    static func effectiveKidFriendly(override: MetadataOverrideProtocol?) -> Bool? {
        override?.isKidFriendly
    }

    /// Whether re-inference should overwrite this override.
    /// Only "inferred" source gets overwritten; "confirmed" and "manual" are preserved.
    static func shouldReInfer(override: MetadataOverrideProtocol?) -> Bool {
        guard let override else { return true }
        return override.source == "inferred"
    }
}
