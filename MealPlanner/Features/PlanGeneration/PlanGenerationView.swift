import SwiftUI
import SwiftData

/// Main view for generating and reviewing a week plan
struct PlanGenerationView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = PlanGenerationViewModel()
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.hasGenerated, let weekPlan = viewModel.weekPlan {
                    WeekPlanReviewView(
                        weekPlan: weekPlan,
                        onRegenerateDay: { index in
                            viewModel.regenerateDay(at: index)
                        },
                        onRegenerateAll: {
                            viewModel.regenerateAll()
                        },
                        onAccept: {
                            Task {
                                await viewModel.acceptPlan()
                            }
                        },
                        isSyncing: viewModel.isSyncing,
                        hasSynced: viewModel.hasSynced,
                        syncError: viewModel.syncError
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
                .foregroundStyle(.paprikaPrimary)
            
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
                .background(.paprikaPrimary)
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
    let onRegenerateAll: () -> Void
    let onAccept: () -> Void
    let isSyncing: Bool
    let hasSynced: Bool
    let syncError: String?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(Array(weekPlan.days.enumerated()), id: \.element.id) { index, day in
                        DayPlanCard(
                            day: day,
                            onRegenerate: { onRegenerateDay(index) }
                        )
                    }
                }
                .padding()
            }

            // Accept Plan footer
            VStack(spacing: 8) {
                if let error = syncError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button(action: onAccept) {
                    HStack {
                        if isSyncing {
                            ProgressView()
                                .tint(.white)
                        } else if hasSynced {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Synced to Paprika!")
                        } else {
                            Image(systemName: "paperplane.fill")
                            Text("Accept & Sync to Paprika")
                        }
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(hasSynced ? .green : .paprikaPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isSyncing || hasSynced)
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .background(.ultraThinMaterial)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onRegenerateAll) {
                    Label("Regenerate All", systemImage: "arrow.clockwise")
                }
                .disabled(isSyncing)
            }
        }
    }
}

#Preview {
    PlanGenerationView()
        .modelContainer(for: RecipeModel.self, inMemory: true)
}
