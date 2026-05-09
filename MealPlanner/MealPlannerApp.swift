import SwiftUI
import SwiftData

@main
struct MealPlannerApp: App {
    let container: ModelContainer
    @State private var appState = AppState()
    @State private var inferenceState = MetadataInferenceState()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let schema = Schema([
            RecipeModel.self,
            MealSlotModel.self,
            CachedMealModel.self,
            CategoryModel.self,
            SlotRuleModel.self,
            RecipeMetadataOverride.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)

        do {
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            // Schema migration failed — delete the old store and recreate
            // This is safe because all data is re-synced from Paprika API
            SyncEventLog.shared.warning("Schema migration failed — resetting store (\(error.localizedDescription))")
            let url = config.url
            let fileManager = FileManager.default
            let storeName = url.lastPathComponent
            let storeDir = url.deletingLastPathComponent()
            // Delete all related SQLite files
            for suffix in ["", "-wal", "-shm"] {
                let fileURL = storeDir.appendingPathComponent(storeName + suffix)
                try? fileManager.removeItem(at: fileURL)
            }
            do {
                container = try ModelContainer(for: schema, configurations: config)
            } catch {
                fatalError("Failed to initialize ModelContainer after store reset: \(error)")
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(inferenceState)
                .modelContainer(container)
                .onChange(of: appState.isAuthenticated) { _, isAuth in
                    if isAuth, let client = appState.paprikaClient {
                        OfflineSyncQueue.shared.start(client: client, container: container)
                        BackgroundRefreshManager.shared.start(client: client, container: container)
                    } else {
                        OfflineSyncQueue.shared.stop()
                        BackgroundRefreshManager.shared.stop()
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .active:
                        if appState.isAuthenticated, let client = appState.paprikaClient {
                            BackgroundRefreshManager.shared.start(client: client, container: container)
                        }
                    case .background, .inactive:
                        BackgroundRefreshManager.shared.stop()
                    @unknown default:
                        break
                    }
                }
        }
    }
}
