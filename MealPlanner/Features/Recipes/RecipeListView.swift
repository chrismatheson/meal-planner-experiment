import SwiftUI
import SwiftData

struct RecipeListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Environment(MetadataInferenceState.self) private var inferenceState
    @Query(sort: \RecipeModel.name) private var recipes: [RecipeModel]

    @State private var viewModel = RecipeListViewModel()
    @State private var searchText = ""
    @State private var showingBatchReview = false
    
    private var filteredRecipes: [RecipeModel] {
        if searchText.isEmpty {
            return recipes
        }
        return recipes.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    private let columns = [
        GridItem(.flexible(), spacing: Spacing.sm),
        GridItem(.flexible(), spacing: Spacing.sm)
    ]
    
    var body: some View {
        NavigationStack {
            Group {
                if recipes.isEmpty && viewModel.isLoading {
                    syncProgressView
                } else if recipes.isEmpty {
                    emptyState
                } else {
                    recipeGrid
                }
            }
            .navigationTitle("Recipes")
            .searchable(text: $searchText, prompt: "Search recipes")
            .toolbar { }
            .refreshable {
                // Pull-to-refresh always forces a sync, bypassing throttle
                await viewModel.syncRecipes(context: modelContext, client: appState.paprikaClient, force: true)
            }
            .task {
                // Wire inference state so post-sync prompt fires automatically
                viewModel.syncEngine.inferenceState = inferenceState
                // Always trigger a sync when view appears
                // Cached data shows immediately via @Query, this refreshes in background
                await viewModel.syncRecipes(context: modelContext, client: appState.paprikaClient)
            }
            .alert("Recipe Intelligence",
                   isPresented: Binding(
                       get: { inferenceState.shouldShowPostSyncPrompt },
                       set: { _ in inferenceState.dismissPostSyncPrompt() })) {
                Button("Let's see") { showingBatchReview = true }
                Button("Not now", role: .cancel) { inferenceState.dismissPostSyncPrompt() }
            } message: {
                Text("We've auto-categorised \(inferenceState.unreviewedCount) recipes. Take a quick look?")
            }
            .sheet(isPresented: $showingBatchReview) {
                BatchReviewView(container: modelContext.container)
            }
        }
    }
    
    private var recipeGrid: some View {
        ScrollView {
            VStack(spacing: Spacing.sm) {
                if inferenceState.hasUnreviewed {
                    Button { showingBatchReview = true } label: {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("We've categorised \(inferenceState.unreviewedCount) recipes — check our work?")
                                .font(.subheadline)
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .padding(Spacing.sm)
                        .background(Color.paprikaLight.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                    }
                    .buttonStyle(.plain)
                }

                LazyVGrid(columns: columns, spacing: Spacing.sm) {
                    ForEach(filteredRecipes) { recipe in
                        RecipeCard(recipe: recipe)
                    }
                }
            }
            .padding(Spacing.md)
        }
    }
    
    /// Shows progress during initial full sync (when no cached data exists)
    private var syncProgressView: some View {
        VStack(spacing: Spacing.md) {
            let engine = viewModel.syncEngine
            switch engine.phase {
            case .fetchingStubs, .comparing:
                ProgressView()
                    .controlSize(.large)
                Text("Checking for recipes...")
                    .font(.headline)
            case .fetchingDetails:
                ProgressView(value: engine.progress)
                    .progressViewStyle(.linear)
                    .padding(.horizontal, Spacing.xl)
                Text("Syncing recipes (\(engine.syncedRecipes)/\(engine.totalRecipes))")
                    .font(.headline)
                Text("First sync downloads your full library")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            default:
                LoadingView(message: "Loading recipes...")
            }
        }
        .padding()
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Recipes", systemImage: "book")
        } description: {
            Text("Your Paprika recipes will appear here after syncing.")
        } actions: {
            Button("Sync Now") {
                Task {
                    await viewModel.syncRecipes(context: modelContext, client: appState.paprikaClient)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.paprikaPrimary)
        }
    }
}

// MARK: - Recipe Card

struct RecipeCard: View {
    let recipe: RecipeModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            // Image with disk caching
            CachedAsyncImage(url: recipe.imageURL) {
                placeholderImage
            }
            .aspectRatio(1, contentMode: .fill)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            
            // Title
            Text(recipe.name)
                .font(.headline)
                .lineLimit(2)
                .foregroundStyle(.primary)
            
            // Metadata
            HStack(spacing: Spacing.xs) {
                if let category = recipe.firstCategory {
                    Text(category)
                }
                if let time = recipe.displayTime {
                    if recipe.firstCategory != nil {
                        Text("•")
                    }
                    Text(time)
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        .recipeCardStyle()
    }
    
    private var placeholderImage: some View {
        Rectangle()
            .fill(Color.paprikaCream)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                Image(systemName: "fork.knife")
                    .font(.largeTitle)
                    .foregroundStyle(Color.paprikaPrimary.opacity(0.5))
            }
    }
}

#Preview {
    RecipeListView()
        .environment(AppState())
        .environment(MetadataInferenceState())
        .modelContainer(for: RecipeModel.self, inMemory: true)
}
