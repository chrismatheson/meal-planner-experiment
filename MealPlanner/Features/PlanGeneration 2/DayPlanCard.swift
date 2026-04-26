import SwiftUI

/// Card showing a single day's meal assignment
struct DayPlanCard: View {
    let day: DayPlan
    let onRegenerate: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Recipe image with disk caching - use GeometryReader to ensure proper clipping
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.paprikaCream)
                .frame(width: 80, height: 80)
                .overlay {
                    CachedAsyncImage(url: day.recipe?.imageURL) {
                        Image(systemName: "fork.knife")
                            .font(.title2)
                            .foregroundStyle(Color.paprikaPrimary.opacity(0.5))
                    }
                    .scaledToFill()
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Day and recipe info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(day.dayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.paprikaPrimary)
                    
                    Text(day.shortDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Text(day.displayName)
                    .font(.headline)
                    .lineLimit(2)
                    .foregroundStyle(day.hasMeal ? .primary : .secondary)
                
                if let prepTime = day.recipe?.prepTime, !prepTime.isEmpty {
                    Label(prepTime, systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Regenerate button
            Button(action: onRegenerate) {
                Image(systemName: "arrow.clockwise")
                    .font(.title3)
                    .foregroundStyle(Color.paprikaPrimary)
                    .padding(8)
                    .background(Color.paprikaPrimary.opacity(0.1))
                    .clipShape(Circle())
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}

#Preview {
    // Create a mock PaprikaRecipe to initialize RecipeModel
    let paprikaRecipe = PaprikaRecipe(
        uid: "test",
        name: "Chicken Tikka Masala",
        ingredients: "chicken, spices",
        directions: "Cook it",
        description: nil,
        servings: "4",
        prepTime: "30 mins",
        cookTime: "45 mins",
        totalTime: "1 hr 15 mins",
        rating: 5,
        categories: ["Dinner"],
        photo: nil,
        photoUrl: "https://example.com/image.jpg",
        source: nil,
        sourceUrl: nil,
        onFavorites: false,
        created: nil,
        hash: "abc123",
        photoHash: nil
    )
    let recipe = RecipeModel(from: paprikaRecipe)

    let day = DayPlan(date: Date(), recipe: recipe)

    DayPlanCard(day: day, onRegenerate: {})
        .padding()
        .background(Color(.systemGroupedBackground))
}
