import SwiftUI

/// A shimmering placeholder view for loading states
struct SkeletonView: View {
    var cornerRadius: CGFloat = CornerRadius.medium
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.gray.opacity(0.2))
            .overlay {
                ShimmerView()
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            }
    }
}

/// A skeleton version of DayPlanCard for loading states
struct SkeletonDayPlanCard: View {
    var body: some View {
        HStack(spacing: 12) {
            // Image placeholder
            SkeletonView(cornerRadius: 8)
                .frame(width: 80, height: 80)
            
            // Text placeholders
            VStack(alignment: .leading, spacing: 8) {
                SkeletonView()
                    .frame(width: 80, height: 12)
                
                SkeletonView()
                    .frame(width: 150, height: 16)
                
                SkeletonView()
                    .frame(width: 60, height: 10)
            }
            
            Spacer()
            
            // Button placeholder
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 40, height: 40)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}

/// A skeleton version of RecipeCard for loading states  
struct SkeletonRecipeCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            // Image placeholder
            SkeletonView()
                .aspectRatio(1, contentMode: .fit)
            
            // Title placeholder
            SkeletonView()
                .frame(height: 14)
            
            // Metadata placeholder
            SkeletonView()
                .frame(width: 80, height: 10)
        }
        .recipeCardStyle()
    }
}

/// Loading state for the week plan that shows skeleton cards
struct WeekPlanSkeletonView: View {
    var body: some View {
        VStack(spacing: 16) {
            // Week header skeleton
            SkeletonView()
                .frame(width: 100, height: 12)
            
            // 7 skeleton cards
            ForEach(0..<7, id: \.self) { _ in
                SkeletonDayPlanCard()
            }
        }
        .padding()
    }
}

#Preview("Skeleton Day Card") {
    SkeletonDayPlanCard()
        .padding()
        .background(Color(.systemGroupedBackground))
}

#Preview("Week Plan Loading") {
    WeekPlanSkeletonView()
        .background(Color(.systemGroupedBackground))
}
