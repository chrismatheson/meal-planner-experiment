import SwiftUI

/// Sheet for creating a new slot-pinning rule
/// Flow: pick day → pick constraint type → pick value → save
struct AddRuleSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onSave: (SlotRule) -> Void

    @State private var selectedDay: Int = Calendar.current.firstWeekday
    @State private var constraintType: ConstraintType = .freeform
    @State private var freeformText: String = ""
    @State private var selectedCategoryName: String = ""
    @State private var selectedRecipeName: String = ""
    @FocusState private var freeformFocused: Bool

    enum ConstraintType: String, CaseIterable {
        case freeform = "Custom Label"
        case category = "Category"
        case recipe = "Specific Recipe"

        var icon: String {
            switch self {
            case .freeform: return "tag"
            case .category: return "folder"
            case .recipe: return "book.closed"
            }
        }
    }

    private var canSave: Bool {
        switch constraintType {
        case .freeform: return !freeformText.trimmingCharacters(in: .whitespaces).isEmpty
        case .category: return !selectedCategoryName.isEmpty
        case .recipe: return !selectedRecipeName.isEmpty
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                // Day picker
                Section("Day of Week") {
                    dayPicker
                }

                // Constraint type
                Section("What to pin") {
                    Picker("Type", selection: $constraintType) {
                        ForEach(ConstraintType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                // Value input based on type
                Section(constraintType.rawValue) {
                    constraintValueInput
                }

                // Preview
                if canSave {
                    Section("Preview") {
                        RuleRowView(rule: buildRule())
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color(.systemGroupedBackground))
                    }
                }
            }
            .navigationTitle("New Rule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(buildRule())
                        dismiss()
                    }
                    .disabled(!canSave)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Day Picker

    private var dayPicker: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(1...7, id: \.self) { day in
                let symbols = Calendar.current.veryShortWeekdaySymbols
                let label = symbols[day - 1]

                Button {
                    selectedDay = day
                } label: {
                    Text(label)
                        .font(.subheadline)
                        .fontWeight(selectedDay == day ? .bold : .regular)
                        .foregroundStyle(selectedDay == day ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(selectedDay == day ? Color.paprikaPrimary : Color(.tertiarySystemFill))
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Constraint Value Input

    @ViewBuilder
    private var constraintValueInput: some View {
        switch constraintType {
        case .freeform:
            TextField("e.g. Takeaway, Leftovers, Pasta Night", text: $freeformText)
                .focused($freeformFocused)
                .onAppear { freeformFocused = true }

        case .category:
            // Placeholder — will be wired to real categories later
            CategoryPickerPlaceholder(selected: $selectedCategoryName)

        case .recipe:
            // Placeholder — will be wired to real recipes later
            RecipePickerPlaceholder(selected: $selectedRecipeName)
        }
    }

    // MARK: - Build Rule

    private func buildRule() -> SlotRule {
        let constraint: SlotConstraint = switch constraintType {
        case .freeform:
                .freeform(label: freeformText.trimmingCharacters(in: .whitespaces))
        case .category:
                .category(uid: "placeholder", name: selectedCategoryName)
        case .recipe:
                .recipe(uid: "placeholder", name: selectedRecipeName)
        }
        return SlotRule(dayOfWeek: selectedDay, constraint: constraint)
    }
}


// MARK: - Placeholder Pickers (for preview, replaced with real data later)

/// Placeholder for category selection — uses sample data for previews
private struct CategoryPickerPlaceholder: View {
    @Binding var selected: String

    private let sampleCategories = [
        "Sunday Roast", "Quick Meals", "Italian", "Mexican",
        "Vegetarian", "Comfort Food", "BBQ", "Salads"
    ]

    var body: some View {
        ForEach(sampleCategories, id: \.self) { name in
            Button {
                selected = name
            } label: {
                HStack {
                    Label(name, systemImage: "folder")
                        .foregroundStyle(.primary)
                    Spacer()
                    if selected == name {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color.paprikaPrimary)
                            .fontWeight(.semibold)
                    }
                }
            }
        }
    }
}

/// Placeholder for recipe selection — uses sample data for previews
private struct RecipePickerPlaceholder: View {
    @Binding var selected: String

    private let sampleRecipes = [
        "Spaghetti Carbonara", "Chicken Tikka Masala", "Fish & Chips",
        "Beef Tacos", "Mushroom Risotto", "Thai Green Curry"
    ]

    var body: some View {
        ForEach(sampleRecipes, id: \.self) { name in
            Button {
                selected = name
            } label: {
                HStack {
                    Label(name, systemImage: "book.closed")
                        .foregroundStyle(.primary)
                    Spacer()
                    if selected == name {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color.paprikaPrimary)
                            .fontWeight(.semibold)
                    }
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Add Rule - Default") {
    AddRuleSheet { rule in
        print("Saved: \(rule)")
    }
}

#Preview("Rules List → Add Rule") {
    RulesListView(rules: SlotRule.previews)
}