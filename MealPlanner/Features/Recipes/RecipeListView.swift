import SwiftUI
import SwiftData

struct RecipeListView: View {
    @Environment(\.modelContext) private var modelContext
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
            .refreshable {
                await viewModel.syncRecipes(context: modelContext)
            }
            .task {
                if recipes.isEmpty {
                    await viewModel.syncRecipes(context: modelContext)
                }
            }
        }
    }
    
    private var recipeGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: Spacing.sm) {
                ForEach(filteredRecipes) { recipe in
                    RecipeCard(recipe: recipe)
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
                    await viewModel.syncRecipes(context: modelContext)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.paprikaPrimary)
        }
    }
}

// MARK: - Recipe Card

struct RecipeCard: View {
    let recipe: RecipeModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            // Image
            AsyncImage(url: recipe.imageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(1, contentMode: .fill)
                case .failure:
                    placeholderImage
                case .empty:
                    placeholderImage
                        .overlay {
                            ProgressView()
                        }
                @unknown default:
                    placeholderImage
                }
            }
            .aspectRatio(1, contentMode: .fit)
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
                    .foregroundStyle(.paprikaPrimary.opacity(0.5))
            }
    }
}

#Preview {
    RecipeListView()
        .modelContainer(for: RecipeModel.self, inMemory: true)
}
