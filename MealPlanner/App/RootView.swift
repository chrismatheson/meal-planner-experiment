import SwiftUI

/// Root view that handles authentication routing
struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if appState.isRestoringSession {
                // Show splash while checking for stored session
                SplashView()
            } else if appState.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut, value: appState.isAuthenticated)
        .animation(.easeInOut, value: appState.isRestoringSession)
    }
}

/// Splash screen shown during session restoration
struct SplashView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "fork.knife")
                .font(.system(size: 60))
                .foregroundColor(.paprikaPrimary)

            Text("MealPlanner")
                .font(.largeTitle)
                .fontWeight(.bold)

            ProgressView()
                .tint(.paprikaPrimary)
        }
    }
}

/// Main tab navigation for authenticated users
struct MainTabView: View {
    var body: some View {
        TabView {
            RecipeListView()
                .tabItem {
                    Label("Recipes", systemImage: "book")
                }
            
            MealPlanView()
                .tabItem {
                    Label("Meal Plan", systemImage: "calendar")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .tint(Color.paprikaPrimary)
    }
}

/// Placeholder settings view
struct SettingsView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    if let user = appState.currentUser {
                        Text(user.email)
                    }
                }
                
                Section {
                    Button("Sign Out", role: .destructive) {
                        appState.signOut()
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    RootView()
        .environment(AppState())
}
