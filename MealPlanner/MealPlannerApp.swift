import SwiftUI
import SwiftData

@main
struct MealPlannerApp: App {
    let container: ModelContainer
    @State private var appState = AppState()
    
    init() {
        do {
            let schema = Schema([
                RecipeModel.self,
                MealSlotModel.self,
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
        }
    }
}
