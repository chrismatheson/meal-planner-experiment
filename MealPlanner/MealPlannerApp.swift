import SwiftUI
import SwiftData

@main
struct MealPlannerApp: App {
    let container: ModelContainer
    @State private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        do {
            let schema = Schema([
                RecipeModel.self,
                MealSlotModel.self,
                CachedMealModel.self,
                CategoryModel.self,
            ])
            let config = ModelConfiguration(isStoredInMemoryOnly: false)
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
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
