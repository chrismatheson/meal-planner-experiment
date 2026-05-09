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
                    LoadingExistingView(status: viewModel.loadingStatus)
                } else if viewModel.hasGenerated, let weekPlan = viewModel.weekPlan {
                    WeekPlanReviewView(
                        weekPlan: weekPlan,
                        onRegenerateDay: { index in
                            viewModel.regenerateDay(at: index)
                        },
                        onRefresh: {
                            await viewModel.loadExistingMeals(context: modelContext, forceRefresh: true)
                        }
                    )
                } else {
                    GeneratePromptView(
                        isGenerating: viewModel.isGenerating,

                        onGenerate: {
                            viewModel.generatePlan(context: modelContext)
                        }
                    )
                }
            }
            .navigationTitle("Meal Plan")
            .toolbar {
                // Only show toolbar when plan is generated
                if viewModel.hasGenerated {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        // Sync status indicator (minimal dot, expands on tap)
                        SyncStatusIndicator(
                            countdownSeconds: viewModel.countdownSeconds,
                            isSyncing: viewModel.isSyncing,
                            hasSynced: viewModel.hasSynced,
                            hasError: viewModel.syncError != nil,
                            onSyncNow: {
                                await viewModel.syncNow()
                            }
                        )
                        .accessibilityIdentifier("SyncButton")

                        // Undo button (only visible when undo is available)
                        if viewModel.canUndo {
                            Button {
                                viewModel.undo()
                            } label: {
                                Image(systemName: "arrow.uturn.backward")
                            }
                            .accessibilityIdentifier("UndoButton")
                            .accessibilityLabel("Undo last change")
                        }

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
            // Navigation to recipe detail view
            .navigationDestination(for: RecipeModel.self) { recipe in
                RecipeDetailView(recipe: recipe)
            }
        }
    }

    // MARK: - Accessibility Helpers

    private var syncButtonAccessibilityLabel: String {
        if viewModel.isSyncing {
            return "Syncing to Paprika"
        } else if viewModel.hasSynced {
            return "Synced to Paprika"
        } else {
            return "Sync in \(viewModel.countdownSeconds) seconds"
        }
    }
}

/// Loading indicator while fetching existing meals - shows skeleton cards
struct LoadingExistingView: View {
    var status: String = "Loading..."

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Status message at top
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading your meal plan...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top)

                // Skeleton cards
                WeekPlanSkeletonView()
            }
        }
    }
}

/// Initial prompt to generate a plan
struct GeneratePromptView: View {
    let isGenerating: Bool
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
    var onRefresh: (() async -> Void)?

    var body: some View {
        PullToRevealRefresh {
            await onRefresh?()
        } content: {
            LazyVStack(spacing: 16) {
                // Week info header
                let (year, week) = Calendar.currentISOWeek
                Text("Week \(week) of \(year)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

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
