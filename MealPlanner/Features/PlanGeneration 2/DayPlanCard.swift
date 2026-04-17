import SwiftUI

/// Card showing a single day's meal assignment
struct DayPlanCard: View {
    let day: DayPlan
    let onRegenerate: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Recipe image
            AsyncImage(url: day.recipe?.imageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    Image(systemName: "photo")
                        .font(.title)
                        .foregroundStyle(.secondary)
                case .empty:
                    ProgressView()
                @unknown default:
                    Color.gray.opacity(0.2)
                }
            }
            .frame(width: 80, height: 80)
            .background(Color.gray.opacity(0.1))
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
                
                Text(day.recipe?.name ?? "No recipe")
                    .font(.headline)
                    .lineLimit(2)
                
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
                    .background(Color.paprikaPrimary.opacity(0.15))
                    .clipShape(Circle())
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}
