import SwiftUI
import SwiftData

struct RecipeListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query(sort: \RecipeModel.name) private var recipes: [RecipeModel]
    
    @State private var viewModel = RecipeListViewModel()
    @State private var searchText = ""
    
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
                    LoadingView(message: "Loading recipes...")
                } else if recipes.isEmpty {
                    emptyState
                } else {
                    recipeGrid
                }
            }
            .navigationTitle("Recipes")
            .searchable(text: $searchText, prompt: "Search recipes")
            .toolbar {
                if viewModel.isOffline {
                    ToolbarItem(placement: .topBarTrailing) {
                        Label("Offline", systemImage: "wifi.slash")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .refreshable {
                // Pull-to-refresh always forces a sync, bypassing throttle
                await viewModel.syncRecipes(context: modelContext, client: appState.paprikaClient, force: true)
            }
            .task {
                // Always trigger a sync when view appears
                // Cached data shows immediately via @Query, this refreshes in background
                await viewModel.syncRecipes(context: modelContext, client: appState.paprikaClient)
            }
        }
    }
    
    private var recipeGrid: some View {
        ScrollView {
            VStack(spacing: Spacing.sm) {
                // Staleness indicator when offline
                if viewModel.isOffline {
                    StalenessIndicator(isOffline: true)
                        .padding(.top, Spacing.sm)
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
        .modelContainer(for: RecipeModel.self, inMemory: true)
}
