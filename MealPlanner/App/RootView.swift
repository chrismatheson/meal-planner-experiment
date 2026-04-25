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
            PlanGenerationView()
                .tabItem {
                    Label("Plan", systemImage: "sparkles")
                }

            RecipeListView()
                .tabItem {
                    Label("Recipes", systemImage: "book")
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
    @State private var keychainStatus = "Checking..."

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if let user = appState.currentUser {
                        Text(user.email)
                    }
                }

                #if DEBUG
                Section("Debug: Keychain Status") {
                    Text(keychainStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("SettingsKeychainStatus")

                    if let error = KeychainService.lastError {
                        Text("Last Error: \(error)")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Button("Refresh Status") {
                        refreshKeychainStatus()
                    }
                }
                #endif

                Section {
                    Button("Sign Out", role: .destructive) {
                        appState.signOut()
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                refreshKeychainStatus()
            }
        }
    }

    private func refreshKeychainStatus() {
        let keychain = KeychainService()
        var parts: [String] = []

        if let email = try? keychain.getEmail() {
            parts.append("✓ email: \(email)")
        } else {
            parts.append("✗ email")
        }

        if (try? keychain.getPassword()) != nil {
            parts.append("✓ password")
        } else {
            parts.append("✗ password")
        }

        if (try? keychain.getToken()) != nil {
            parts.append("✓ token")
        } else {
            parts.append("✗ token")
        }

        keychainStatus = parts.joined(separator: " | ")
    }
}

#Preview {
    RootView()
        .environment(AppState())
}
