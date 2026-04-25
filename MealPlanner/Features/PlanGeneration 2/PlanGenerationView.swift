import SwiftUI
import SwiftData

/// Main view for generating and reviewing a week plan
struct PlanGenerationView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = PlanGenerationViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoadingExisting {
                    // Loading existing meals
                    LoadingExistingView()
                } else if viewModel.hasGenerated, let weekPlan = viewModel.weekPlan {
                    WeekPlanReviewView(
                        weekPlan: weekPlan,
                        onRegenerateDay: { index in
                            viewModel.regenerateDay(at: index)
                        },
                        hasSynced: viewModel.hasSynced,
                        syncError: viewModel.syncError,
                        isFromCache: viewModel.isFromCache,
                        isOffline: viewModel.isOffline
                    )
                } else {
                    GeneratePromptView(
                        isGenerating: viewModel.isGenerating,
                        isOffline: viewModel.isOffline,
                        onGenerate: {
                            viewModel.generatePlan(context: modelContext)
                        }
                    )
                }
            }
            .navigationTitle("Meal Plan")
            .toolbar {
                // Offline indicator (leading)
                if viewModel.isOffline || viewModel.forceOffline {
                    ToolbarItem(placement: .topBarLeading) {
                        Label("Offline", systemImage: viewModel.forceOffline ? "airplane" : "wifi.slash")
                            .foregroundStyle(.orange)
                            .onLongPressGesture {
                                viewModel.toggleForceOffline()
                            }
                            .accessibilityIdentifier("OfflineIndicator")
                    }
                }

                // Only show toolbar when plan is generated
                if viewModel.hasGenerated {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        // Countdown / Sync button
                        Button {
                            Task {
                                await viewModel.syncNow()
                            }
                        } label: {
                            if viewModel.isSyncing {
                                ProgressView()
                            } else if viewModel.hasSynced {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else {
                                Label {
                                    Text("\(viewModel.countdownSeconds)")
                                } icon: {
                                    Image(systemName: "paperplane.fill")
                                }
                                .foregroundStyle(Color.paprikaPrimary)
                            }
                        }
                        .disabled(viewModel.isSyncing || viewModel.hasSynced || viewModel.isOffline)
                        .accessibilityIdentifier("SyncButton")

                        // Regenerate all button
                        Button {
                            viewModel.regenerateAll()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(viewModel.isSyncing || viewModel.hasSynced)
                        .accessibilityIdentifier("RegenerateButton")
                    }
                }
            }
            .task {
                // Load existing meals on appear
                await viewModel.loadExistingMeals(context: modelContext)
            }
            // Long press anywhere to toggle offline mode (for testing)
            .onLongPressGesture(minimumDuration: 1.5) {
                viewModel.toggleForceOffline()
            }
        }
    }
}

/// Loading indicator while fetching existing meals
struct LoadingExistingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading your meal plan...")
                .foregroundStyle(.secondary)
        }
    }
}

/// Initial prompt to generate a plan
struct GeneratePromptView: View {
    let isGenerating: Bool
    let isOffline: Bool
    let onGenerate: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundStyle(Color.paprikaPrimary)

            Text("Plan Your Week")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Generate 7 dinners from your\nPaprika recipes")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if isOffline {
                Label("Offline - using cached recipes", systemImage: "wifi.slash")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Button(action: onGenerate) {
                HStack {
                    if isGenerating {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "wand.and.stars")
                    }
                    Text("Plan My Week")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.paprikaPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isGenerating)
            .padding(.horizontal, 40)

            Spacer()
            Spacer()
        }
    }
}

/// Review and tweak the generated week plan
struct WeekPlanReviewView: View {
    @Bindable var weekPlan: WeekPlan
    let onRegenerateDay: (Int) -> Void
    let hasSynced: Bool
    let syncError: String?
    var isFromCache: Bool = false
    var isOffline: Bool = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Show cache indicator
                if isFromCache && !hasSynced {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                        Text("Showing cached plan")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // Show error at top if any
                if let error = syncError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(Color.red.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // Show synced confirmation
                if hasSynced {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Synced to Paprika!")
                    }
                    .font(.headline)
                    .foregroundStyle(.green)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                ForEach(Array(weekPlan.days.enumerated()), id: \.element.id) { index, day in
                    DayPlanCard(
                        day: day,
                        onRegenerate: { onRegenerateDay(index) }
                    )
                }
            }
            .padding()
        }
    }
}

#Preview {
    PlanGenerationView()
        .modelContainer(for: RecipeModel.self, inMemory: true)
}
