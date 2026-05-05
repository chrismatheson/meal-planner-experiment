import SwiftUI

/// A single rule displayed as a row — matches DayPlanCard visual hierarchy
struct RuleRowView: View {
    let rule: SlotRule

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Day name — matches DayPlanCard pattern (text, not badge)
            Text(rule.shortDayName)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.paprikaPrimary)
                .frame(width: 40, alignment: .leading)

            // Constraint: icon + name inline
            Label(rule.constraint.displayName, systemImage: rule.constraint.icon)
                .font(.headline)
                .lineLimit(1)

            Spacer()
        }
        .padding(Spacing.md)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        // Accessibility
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(rule.fullDayName): \(rule.constraint.displayName)")
    }
}

// MARK: - Previews

#Preview("Freeform: Takeaway Friday") {
    RuleRowView(rule: SlotRule(dayOfWeek: 6, constraint: .freeform(label: "Takeaway")))
        .padding()
        .background(Color(.systemGroupedBackground))
}

#Preview("Category: Sunday Roast") {
    RuleRowView(rule: SlotRule(dayOfWeek: 1, constraint: .category(uid: "cat-1", name: "Sunday Roast")))
        .padding()
        .background(Color(.systemGroupedBackground))
}

#Preview("Recipe: Specific dish") {
    RuleRowView(rule: SlotRule(dayOfWeek: 4, constraint: .recipe(uid: "rec-1", name: "Spaghetti Carbonara")))
        .padding()
        .background(Color(.systemGroupedBackground))
}

#Preview("All types together") {
    VStack(spacing: Spacing.sm) {
        ForEach(SlotRule.previews) { rule in
            RuleRowView(rule: rule)
        }
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
