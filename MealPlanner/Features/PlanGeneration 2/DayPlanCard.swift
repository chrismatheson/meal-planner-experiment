import SwiftUI

/// Card showing a single day's meal assignment
/// Tap the card to view recipe details, tap the refresh button to regenerate
struct DayPlanCard: View {
    let day: DayPlan
    let onRegenerate: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Recipe image - tappable to view details
            recipeImage

            // Day and recipe info - also tappable
            NavigationLink(value: day.recipe) {
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
                        .multilineTextAlignment(.leading)

                    if let prepTime = day.recipe?.prepTime, !prepTime.isEmpty {
                        Label(prepTime, systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .disabled(day.recipe == nil)
            .buttonStyle(.plain)

            Spacer()

            // Regenerate button (separate action, not navigation)
            Button(action: onRegenerate) {
                Image(systemName: "arrow.clockwise")
                    .font(.title3)
                    .foregroundStyle(Color.paprikaPrimary)
                    .padding(12)  // 44pt minimum tap target
                    .background(Color.paprikaPrimary.opacity(0.1))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Change \(day.dayName)'s meal")
            .accessibilityHint("Assigns a different recipe")
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        // Combined accessibility for the whole card
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint(day.recipe != nil ? "Tap to view recipe details" : "")
    }

    private var accessibilityDescription: String {
        var parts = [day.dayName, day.shortDate]
        parts.append(day.displayName)
        if let prepTime = day.recipe?.prepTime, !prepTime.isEmpty {
            parts.append("Prep time: \(prepTime)")
        }
        return parts.joined(separator: ", ")
    }

    // MARK: - Recipe Image

    private var recipeImage: some View {
        NavigationLink(value: day.recipe) {
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
        }
        .disabled(day.recipe == nil)
        .buttonStyle(.plain)
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
