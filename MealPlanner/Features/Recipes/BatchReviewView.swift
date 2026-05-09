import SwiftUI
import SwiftData

// MARK: - Batch Review View

struct BatchReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = BatchReviewViewModel()
    let container: ModelContainer

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress bar
                ProgressView(value: viewModel.progress)
                    .tint(Color.paprikaPrimary)
                Text("Checked \(viewModel.reviewedCount) of \(viewModel.totalCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, Spacing.md)

                // Grouped card list
                ScrollView {
                    LazyVStack(spacing: Spacing.md) {
                        ForEach(viewModel.sections) { section in
                            Section {
                                ForEach(section.items) { item in
                                    ReviewCard(
                                        item: item,
                                        onCycleEffort: { viewModel.cycleEffort(item.id, container: container) },
                                        onToggleKidFriendly: { viewModel.toggleKidFriendly(item.id, container: container) },
                                        onConfirm: { viewModel.confirmItem(item.id, container: container) }
                                    )
                                }
                            } header: {
                                EffortSectionHeader(level: section.effortLevel, count: section.items.count)
                            }
                        }
                    }
                    .padding(Spacing.md)
                }
            }
            .navigationTitle("Review Recipes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done for now") { dismiss() }
                }
            }
            .task { await viewModel.load(container: container) }
        }
    }
}

// MARK: - Review Card

struct ReviewCard: View {
    let item: BatchReviewViewModel.ReviewItem
    let onCycleEffort: () -> Void
    let onToggleKidFriendly: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                // Thumbnail
                CachedAsyncImage(url: item.imageURL) {
                    Rectangle()
                        .fill(Color.paprikaCream)
                        .overlay {
                            Image(systemName: "fork.knife")
                                .foregroundStyle(Color.paprikaPrimary.opacity(0.3))
                        }
                }
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(item.recipeName)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(2)

                    Button(action: onCycleEffort) {
                        EffortPill(level: item.effortLevel)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }

            HStack {
                Toggle("Kid-Friendly", isOn: Binding(
                    get: { item.isKidFriendly ?? false },
                    set: { _ in onToggleKidFriendly() }
                ))
                .font(.caption)
                .toggleStyle(.switch)
                .controlSize(.mini)
            }

            if !item.isReviewed {
                Button(action: onConfirm) {
                    Label("Looks right", systemImage: "checkmark")
                        .font(.caption.weight(.medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.paprikaPrimary)
                .controlSize(.small)
            } else {
                Label("Confirmed", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(Spacing.sm)
        .background(Color.paprikaCream.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
    }
}

// MARK: - Effort Pill

struct EffortPill: View {
    let level: EffortLevel

    var body: some View {
        Text(level.rawValue.capitalized)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(pillColor.opacity(0.2))
            .foregroundStyle(pillColor)
            .clipShape(Capsule())
    }

    private var pillColor: Color {
        switch level {
        case .quick: .green
        case .normal: Color.paprikaWarm
        case .elaborate: Color.paprikaDeep
        }
    }
}

// MARK: - Effort Section Header

struct EffortSectionHeader: View {
    let level: EffortLevel
    let count: Int

    var body: some View {
        HStack {
            EffortPill(level: level)
            Text("\(count) recipe\(count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}
