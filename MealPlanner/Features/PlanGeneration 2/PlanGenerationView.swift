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
    let onRegenerateAll: () -> Void
    
    var body: some View {
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onRegenerateAll) {
                    Label("Regenerate All", systemImage: "arrow.clockwise")
                }
            }
        }
    }
}
