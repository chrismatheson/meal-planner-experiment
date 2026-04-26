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

/// App settings view with sync status as a canonical home
struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var keychainStatus = "Checking..."
    private let syncManager = SyncStatusManager.shared

    var body: some View {
        NavigationStack {
            List {
                // Account Section
                Section {
                    if let user = appState.currentUser {
                        HStack {
                            Label("Account", systemImage: "person.circle")
                            Spacer()
                            Text(user.email)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Button("Sign Out", role: .destructive) {
                        appState.signOut()
                    }
                } header: {
                    Text("Paprika Account")
                }
                
                // Sync Section
                Section {
                    // Status row
                    HStack {
                        Label("Status", systemImage: "arrow.triangle.2.circlepath")
                        Spacer()
                        syncStatusBadge
                    }
                    
                    // Last meal sync
                    if let lastMealSync = syncManager.lastMealSyncTime {
                        HStack {
                            Label("Last Meal Sync", systemImage: "fork.knife")
                            Spacer()
                            Text(lastMealSync.formatted(date: .abbreviated, time: .shortened))
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    // Last recipe sync
                    if let lastRecipeSync = syncManager.lastRecipeSyncTime {
                        HStack {
                            Label("Last Recipe Sync", systemImage: "book")
                            Spacer()
                            Text(lastRecipeSync.formatted(date: .abbreviated, time: .shortened))
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Sync")
                } footer: {
                    Text("Meal plans sync automatically after 20 seconds of inactivity.")
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
                
                // About Section
                Section {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text(Bundle.main.appVersion)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                refreshKeychainStatus()
            }
        }
    }
    
    @ViewBuilder
    private var syncStatusBadge: some View {
        if syncManager.isSyncing {
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Syncing")
                    .foregroundStyle(.secondary)
            }
        } else if syncManager.lastError != nil {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
                Text("Error")
                    .foregroundStyle(.red)
            }
        } else {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Up to date")
                    .foregroundStyle(.secondary)
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

// MARK: - Bundle Extension

extension Bundle {
    var appVersion: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

#Preview {
    RootView()
        .environment(AppState())
}
