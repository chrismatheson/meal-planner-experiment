import SwiftUI
import SwiftData

struct RecipePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecipeModel.name) private var recipes: [RecipeModel]
    
    @State private var searchText = ""
    
    let onSelect: (RecipeModel) -> Void
    
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
                if recipes.isEmpty {
                    ContentUnavailableView {
                        Label("No Recipes", systemImage: "book")
                    } description: {
                        Text("Sync your recipes from Paprika first.")
                    }
                } else {
                    recipeGrid
                }
            }
            .navigationTitle("Choose Recipe")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .searchable(text: $searchText, prompt: "Search recipes")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var recipeGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: Spacing.sm) {
                ForEach(filteredRecipes) { recipe in
                    Button {
                        onSelect(recipe)
                    } label: {
                        RecipePickerCard(recipe: recipe)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Spacing.md)
        }
    }
}

// MARK: - Recipe Picker Card

struct RecipePickerCard: View {
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
                case .failure, .empty:
                    placeholderImage
                @unknown default:
                    placeholderImage
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            
            // Title
            Text(recipe.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(2)
                .foregroundStyle(.primary)
            
            // Time
            if let time = recipe.displayTime {
                Text(time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(Spacing.sm)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
    }
    
    private var placeholderImage: some View {
        Rectangle()
            .fill(Color.paprikaCream)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                Image(systemName: "fork.knife")
                    .font(.title)
                    .foregroundStyle(Color.paprikaPrimary.opacity(0.5))
            }
    }
}

#Preview {
    RecipePickerView { recipe in
        print("Selected: \(recipe.name)")
    }
    .modelContainer(for: RecipeModel.self, inMemory: true)
}
