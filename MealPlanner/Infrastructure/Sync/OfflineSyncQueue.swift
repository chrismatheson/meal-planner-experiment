import Foundation
import Network
import SwiftData

/// Monitors connectivity and drains locally-modified meals when back online.
/// Uses NWPathMonitor to detect network restoration.
@Observable
final class OfflineSyncQueue {
    static let shared = OfflineSyncQueue()
    
    // MARK: - Observable State
    
    private(set) var isOnline = true
    private(set) var isSyncing = false
    private(set) var pendingCount = 0
    var lastDrainError: String?
    
    // MARK: - Private
    
    private var monitor: NWPathMonitor?
    private let monitorQueue = DispatchQueue(label: "com.mealplanner.networkMonitor")
    private var client: PaprikaClient?
    private var modelContainer: ModelContainer?
    
    private init() {}
    
    // MARK: - Lifecycle
    
    /// Start monitoring network connectivity.
    /// Call once at app launch with the authenticated client and model container.
    func start(client: PaprikaClient, container: ModelContainer) {
        self.client = client
        self.modelContainer = container
        
        monitor?.cancel()
        let newMonitor = NWPathMonitor()
        newMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self else { return }
                let wasOffline = !self.isOnline
                self.isOnline = (path.status == .satisfied)
                
                // Connectivity restored — drain the queue
                if wasOffline && self.isOnline {
                    print("📶 Network restored — draining offline queue")
                    await self.drainIfNeeded()
                }
            }
        }
        newMonitor.start(queue: monitorQueue)
        monitor = newMonitor
        
        // Initial count
        Task { @MainActor in
            self.refreshPendingCount()
        }
    }
    
    /// Stop monitoring (call when app goes to background)
    func stop() {
        monitor?.cancel()
        monitor = nil
    }
    
    // MARK: - Drain
    
    /// Attempt to sync all pending meals. Safe to call multiple times.
    @MainActor
    func drainIfNeeded() async {
        guard isOnline, !isSyncing, let client, let modelContainer else { return }
        
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<CachedMealModel>(
            predicate: #Predicate { $0.needsSync == true }
        )
        
        guard let pendingMeals = try? context.fetch(descriptor),
              !pendingMeals.isEmpty else {
            pendingCount = 0
            return
        }
        
        isSyncing = true
        pendingCount = pendingMeals.count
        lastDrainError = nil
        
        do {
            // Convert to PaprikaMeals and sync
            let paprikaMeals = pendingMeals.map { $0.toPaprikaMeal() }
            try await client.saveMeals(paprikaMeals)
            
            // Mark as synced
            for meal in pendingMeals {
                meal.needsSync = false
            }
            try context.save()
            
            pendingCount = 0
            SyncStatusManager.shared.markMealsSynced()
            print("✅ Drained \(paprikaMeals.count) pending meals")
            
        } catch {
            lastDrainError = error.localizedDescription
            SyncStatusManager.shared.setError(error.localizedDescription)
            print("❌ Offline queue drain failed: \(error)")
        }
        
        isSyncing = false
    }
    
    // MARK: - Count
    
    /// Refresh the pending count from SwiftData
    @MainActor
    func refreshPendingCount() {
        guard let modelContainer else {
            pendingCount = 0
            return
        }
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<CachedMealModel>(
            predicate: #Predicate { $0.needsSync == true }
        )
        pendingCount = (try? context.fetchCount(descriptor)) ?? 0
    }
}
