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
