import SwiftUI

/// Detailed view of a recipe showing image, ingredients, directions, etc.
struct RecipeDetailView: View {
    let recipe: RecipeModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Hero image
                heroImage
                
                // Content
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    headerSection
                    
                    if let ingredients = recipe.ingredients, !ingredients.isEmpty {
                        ingredientsSection(ingredients)
                    }
                    
                    if let directions = recipe.directions, !directions.isEmpty {
                        directionsSection(directions)
                    }
                    
                    if let source = recipe.source, !source.isEmpty {
                        sourceSection(source)
                    }
                }
                .padding(Spacing.md)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(recipe.name)
                    .font(.headline)
                    .lineLimit(1)
            }
        }
        .ignoresSafeArea(edges: .top)
    }
    
    // MARK: - Hero Image
    
    private var heroImage: some View {
        CachedAsyncImage(url: recipe.imageURL) {
            Rectangle()
                .fill(Color.paprikaCream)
                .overlay {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 60))
                        .foregroundStyle(Color.paprikaPrimary.opacity(0.3))
                }
        }
        .scaledToFill()
        .frame(height: 280)
        .clipped()
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(recipe.name)
                .font(.title2)
                .fontWeight(.bold)
            
            if let description = recipe.recipeDescription, !description.isEmpty {
                Text(description)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            
            // Time and servings badges
            HStack(spacing: Spacing.md) {
                if let time = recipe.displayTime {
                    Label(time, systemImage: "clock")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                if let servings = recipe.servings, !servings.isEmpty {
                    Label(servings, systemImage: "person.2")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                if let rating = recipe.rating, rating > 0 {
                    HStack(spacing: 2) {
                        ForEach(0..<5) { i in
                            Image(systemName: i < rating ? "star.fill" : "star")
                                .font(.caption)
                                .foregroundStyle(i < rating ? Color.paprikaWarm : .gray)
                        }
                    }
                }
            }
            
            // Categories
            if !recipe.categories.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.sm) {
                        ForEach(recipe.categories, id: \.self) { category in
                            Text(category)
                                .font(.caption)
                                .padding(.horizontal, Spacing.sm)
                                .padding(.vertical, Spacing.xs)
                                .background(Color.paprikaLight.opacity(0.5))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Ingredients Section
    
    private func ingredientsSection(_ ingredients: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader("Ingredients", icon: "list.bullet")
            
            Text(ingredients)
                .font(.body)
                .lineSpacing(4)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.paprikaCream.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
    }
    
    // MARK: - Directions Section
    
    private func directionsSection(_ directions: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader("Directions", icon: "text.alignleft")
            
            Text(directions)
                .font(.body)
                .lineSpacing(6)
        }
    }
    
    // MARK: - Source Section
    
    private func sourceSection(_ source: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Source")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            if let url = recipe.sourceUrl, let sourceURL = URL(string: url) {
                Link(source, destination: sourceURL)
                    .font(.subheadline)
                    .foregroundStyle(Color.paprikaPrimary)
            } else {
                Text(source)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, Spacing.md)
    }
    
    // MARK: - Helpers
    
    private func sectionHeader(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.headline)
            .foregroundStyle(Color.paprikaPrimary)
    }
}

// MARK: - Preview

#Preview {
    let paprikaRecipe = PaprikaRecipe(
        uid: "preview-1",
        name: "Spaghetti Carbonara",
        ingredients: """
        1 lb spaghetti
        4 oz pancetta or guanciale
        4 large egg yolks
        1 cup Pecorino Romano, grated
        Freshly ground black pepper
        Salt for pasta water
        """,
        directions: """
        1. Bring a large pot of salted water to boil. Cook spaghetti according to package directions.

        2. While pasta cooks, cut pancetta into small cubes and cook in a large skillet over medium heat until crispy.

        3. In a bowl, whisk together egg yolks, grated cheese, and plenty of black pepper.

        4. When pasta is al dente, reserve 1 cup pasta water, then drain. Add hot pasta to the skillet with pancetta (off heat).

        5. Quickly toss with the egg mixture, adding pasta water as needed to create a creamy sauce. Serve immediately.
        """,
        description: "Classic Roman pasta with eggs, cheese, and cured pork",
        servings: "4 servings",
        prepTime: "10 mins",
        cookTime: "20 mins",
        totalTime: "30 mins",
        rating: 5,
        categories: ["Italian", "Pasta", "Quick Meals"],
        photo: nil,
        photoUrl: nil,
        source: "Serious Eats",
        sourceUrl: "https://www.seriouseats.com",
        onFavorites: false,
        created: nil,
        hash: "preview",
        photoHash: nil
    )

    return NavigationStack {
        RecipeDetailView(recipe: RecipeModel(from: paprikaRecipe))
    }
}
