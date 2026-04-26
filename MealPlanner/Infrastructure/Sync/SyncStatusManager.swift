import Foundation
import SwiftUI

/// Manages and persists sync status across the app
@Observable
final class SyncStatusManager {
    static let shared = SyncStatusManager()
    
    // MARK: - Persisted State
    
    /// Last time recipes were synced from Paprika
    var lastRecipeSyncTime: Date? {
        get { UserDefaults.standard.object(forKey: "lastRecipeSyncTime") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "lastRecipeSyncTime") }
    }
    
    /// Last time meals were synced to Paprika
    var lastMealSyncTime: Date? {
        get { UserDefaults.standard.object(forKey: "lastMealSyncTime") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "lastMealSyncTime") }
    }
    
    /// Number of local changes waiting to sync
    var pendingChangesCount: Int = 0
    
    // MARK: - Transient State
    
    /// Currently syncing recipes
    var isSyncingRecipes = false
    
    /// Currently syncing meals
    var isSyncingMeals = false
    
    /// Last sync error message
    var lastError: String?
    
    // MARK: - Computed
    
    var isSyncing: Bool {
        isSyncingRecipes || isSyncingMeals
    }
    
    var hasPendingChanges: Bool {
        pendingChangesCount > 0
    }
    
    var lastSyncDescription: String {
        guard let date = mostRecentSyncTime else {
            return "Never synced"
        }
        return "Synced \(date.relativeDescription)"
    }
    
    var statusSummary: String {
        var parts: [String] = []
        
        if hasPendingChanges {
            parts.append("\(pendingChangesCount) pending")
        }
        
        if let lastSync = mostRecentSyncTime {
            parts.append(lastSync.relativeDescription)
        } else {
            parts.append("Never synced")
        }
        
        return parts.joined(separator: " • ")
    }
    
    private var mostRecentSyncTime: Date? {
        [lastRecipeSyncTime, lastMealSyncTime]
            .compactMap { $0 }
            .max()
    }
    
    // MARK: - Actions
    
    func markRecipesSynced() {
        lastRecipeSyncTime = Date()
        lastError = nil
    }
    
    func markMealsSynced() {
        lastMealSyncTime = Date()
        pendingChangesCount = 0
        lastError = nil
    }
    
    func incrementPending() {
        pendingChangesCount += 1
    }
    
    func setError(_ message: String) {
        lastError = message
    }
    
    private init() {}
}

// MARK: - Date Extension

extension Date {
    var relativeDescription: String {
        let now = Date()
        let diff = now.timeIntervalSince(self)
        
        if diff < 60 {
            return "just now"
        } else if diff < 3600 {
            let mins = Int(diff / 60)
            return "\(mins)m ago"
        } else if diff < 86400 {
            let hours = Int(diff / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(diff / 86400)
            return "\(days)d ago"
        }
    }
}
