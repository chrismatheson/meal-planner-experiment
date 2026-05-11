import SwiftUI
import SwiftData

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
    @Environment(MetadataInferenceState.self) private var inferenceState
    @Environment(\.modelContext) private var modelContext
    @State private var keychainStatus = "Checking..."
    @State private var showingBatchReview = false
    @AppStorage("paprikaCategoryWriteBack") private var writeBackEnabled = false
    @AppStorage("ingredientNormalisationEnabled") private var ingredientNormalisationEnabled = true
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
                    NavigationLink {
                        SyncDetailView()
                    } label: {
                        HStack {
                            Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                            Spacer()
                            syncStatusBadge
                        }
                    }
                } header: {
                    Text("Sync")
                } footer: {
                    Text("Meal plans sync automatically after 20 seconds of inactivity.")
                }

                Section {
                    NavigationLink {
                        StorageManagementView()
                    } label: {
                        Label("Storage", systemImage: "internaldrive")
                    }
                } footer: {
                    Text("Review local cache size and clear disposable offline data.")
                }

                // Generation Section - rules + rejection tracker
                Section {
                    NavigationLink {
                        RulesListView()
                    } label: {
                        Label("Slot Rules", systemImage: "list.bullet.rectangle")
                    }

                    let rejectionTracker = RejectionTracker.shared

                    HStack {
                        Label("Rejected Recipes", systemImage: "hand.thumbsdown")
                        Spacer()
                        Text("\(rejectionTracker.rejectionCount)")
                            .foregroundStyle(.secondary)
                    }

                    if rejectionTracker.rejectionCount > 0 {
                        if let lastUpdated = rejectionTracker.lastUpdated {
                            HStack {
                                Label("Last Rejection", systemImage: "clock")
                                Spacer()
                                Text(lastUpdated.formatted(date: .omitted, time: .shortened))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Button("Clear Rejections") {
                            rejectionTracker.clearRejections()
                        }
                    }
                } header: {
                    Text("Generation")
                } footer: {
                    Text("Rejected recipes won't be suggested again this session. Resets after 1 hour or when you sync.")
                }

                // Intelligence Section
                Section {
                    Button { showingBatchReview = true } label: {
                        HStack {
                            Label("Recipe Intelligence", systemImage: "sparkles")
                            Spacer()
                            Text(inferenceState.hasUnreviewed ? "\(inferenceState.unreviewedCount) to review" : "All reviewed")
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)

                    Button {
                        Task {
                            await inferenceState.runManually(container: modelContext.container)
                        }
                    } label: {
                        HStack {
                            Label("Run Intelligence Now", systemImage: "arrow.clockwise")
                            Spacer()
                            if inferenceState.isRunning {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(inferenceState.isRunning)

                    Toggle(isOn: $writeBackEnabled) {
                        Label("Sync categories to Paprika", systemImage: "arrow.up.circle")
                    }

                    Toggle(isOn: $ingredientNormalisationEnabled) {
                        Label("Normalise ingredients", systemImage: "text.alignleft")
                    }
                } header: {
                    Text("Intelligence")
                } footer: {
                    Text("Auto-categorises recipes by effort level and normalises ingredient formatting. Tap 'Run Intelligence Now' if your recipes were synced before this feature was added.")
                }
                .sheet(isPresented: $showingBatchReview) {
                    BatchReviewView(container: modelContext.container)
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
