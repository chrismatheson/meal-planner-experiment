import Foundation

/// Tracks recipes that the user has rejected during a planning session
/// Persists to UserDefaults with automatic expiry after 1 hour
@Observable
final class RejectionTracker {
    static let shared = RejectionTracker()
    
    private let expiryInterval: TimeInterval = 3600 // 1 hour
    private let storageKey = "rejectedRecipes"
    private let timestampKey = "rejectedRecipesTimestamp"
    
    /// Set of rejected recipe UIDs (valid for current session)
    private(set) var rejectedRecipeIds: Set<String> = []
    
    /// When rejections were last updated
    private(set) var lastUpdated: Date?
    
    private init() {
        loadFromStorage()
    }
    
    // MARK: - Public API
    
    /// Mark a recipe as rejected (user tapped regenerate)
    func rejectRecipe(_ recipeId: String) {
        rejectedRecipeIds.insert(recipeId)
        lastUpdated = Date()
        saveToStorage()
        print("🚫 Rejected recipe: \(recipeId) (total: \(rejectedRecipeIds.count))")
    }
    
    /// Mark multiple recipes as rejected
    func rejectRecipes(_ recipeIds: [String]) {
        rejectedRecipeIds.formUnion(recipeIds)
        lastUpdated = Date()
        saveToStorage()
        print("🚫 Rejected \(recipeIds.count) recipes (total: \(rejectedRecipeIds.count))")
    }
    
    /// Check if a recipe has been rejected
    func isRejected(_ recipeId: String) -> Bool {
        return rejectedRecipeIds.contains(recipeId)
    }
    
    /// Clear all rejections (called when user accepts/syncs plan)
    func clearRejections() {
        rejectedRecipeIds.removeAll()
        lastUpdated = nil
        UserDefaults.standard.removeObject(forKey: storageKey)
        UserDefaults.standard.removeObject(forKey: timestampKey)
        print("✅ Cleared all rejections")
    }
    
    /// Number of rejected recipes
    var rejectionCount: Int {
        rejectedRecipeIds.count
    }
    
    // MARK: - Persistence
    
    private func saveToStorage() {
        let array = Array(rejectedRecipeIds)
        UserDefaults.standard.set(array, forKey: storageKey)
        UserDefaults.standard.set(Date(), forKey: timestampKey)
    }
    
    private func loadFromStorage() {
        // Check if data has expired
        if let timestamp = UserDefaults.standard.object(forKey: timestampKey) as? Date {
            let age = Date().timeIntervalSince(timestamp)
            if age > expiryInterval {
                // Data expired, clear it
                print("⏰ Rejection data expired (\(Int(age/60)) mins old), clearing")
                clearRejections()
                return
            }
            lastUpdated = timestamp
        }
        
        // Load stored rejections
        if let array = UserDefaults.standard.array(forKey: storageKey) as? [String] {
            rejectedRecipeIds = Set(array)
            print("📂 Loaded \(rejectedRecipeIds.count) rejections from storage")
        }
    }
}
