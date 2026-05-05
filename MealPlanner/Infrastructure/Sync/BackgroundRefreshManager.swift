import Foundation
import SwiftData

/// Periodic in-app sync while the app is foregrounded.
/// NOT iOS background tasks — just a simple timer that fires while the app is active.
/// Runs: recipe sync → category sync → offline queue drain
@Observable
final class BackgroundRefreshManager {
    static let shared = BackgroundRefreshManager()
    
    // MARK: - Configuration
    
    /// Interval between automatic refreshes (default: 15 minutes)
    var refreshInterval: TimeInterval = 900
    
    // MARK: - Observable State
    
    private(set) var isRefreshing = false
    private(set) var lastRefreshTime: Date?
    
    // MARK: - Private
    
    private var timer: Timer?
    private var client: PaprikaClient?
    private var modelContainer: ModelContainer?
    private let syncEngine = RecipeSyncEngine()
    
    private init() {}
    
    // MARK: - Lifecycle
    
    /// Start the background refresh timer.
    /// Call when app enters foreground and user is authenticated.
    func start(client: PaprikaClient, container: ModelContainer) {
        self.client = client
        self.modelContainer = container
        
        stopTimer()
        
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performRefresh()
            }
        }
        
        print("⏰ Background refresh started (every \(Int(refreshInterval))s)")
    }
    
    /// Stop the timer. Call when app enters background or user signs out.
    func stop() {
        stopTimer()
        client = nil
        modelContainer = nil
        print("⏰ Background refresh stopped")
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - Refresh
    
    /// Perform a full background refresh cycle.
    /// Recipes → Categories → Drain offline queue
    @MainActor
    func performRefresh() async {
        guard let client, let modelContainer, !isRefreshing else { return }
        
        isRefreshing = true
        let context = ModelContext(modelContainer)
        
        SyncEventLog.shared.info("Background refresh starting")

        // 1. Recipe sync (incremental, fast after first sync)
        let _ = await syncEngine.sync(client: client, context: context)

        // 2. Category sync
        await syncEngine.syncCategories(client: client, context: context)

        // 3. Drain offline queue
        await OfflineSyncQueue.shared.drainIfNeeded()

        lastRefreshTime = Date()
        isRefreshing = false
        SyncEventLog.shared.success("Background refresh complete")
    }
}
