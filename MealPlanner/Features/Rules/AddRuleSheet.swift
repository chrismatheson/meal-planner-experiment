import SwiftUI
import SwiftData

/// Sheet for creating a new slot-pinning rule
/// Flow: pick day → pick constraint type → pick value → save
struct AddRuleSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \CategoryModel.name) private var categories: [CategoryModel]
    @Query(sort: \RecipeModel.name) private var recipes: [RecipeModel]

    let onSave: (SlotRule) -> Void

    @State private var selectedDay: Int = Calendar.current.firstWeekday
    @State private var constraintType: ConstraintType = .freeform
    @State private var freeformText: String = ""
    @State private var selectedCategoryUid: String = ""
    @State private var selectedCategoryName: String = ""
    @State private var selectedRecipeUid: String = ""
    @State private var selectedRecipeName: String = ""
    @State private var searchText: String = ""
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
        case .category: return !selectedCategoryUid.isEmpty
        case .recipe: return !selectedRecipeUid.isEmpty
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
            categoryPicker

        case .recipe:
            recipePicker
        }
    }

    // MARK: - Category Picker

    private var categoryPicker: some View {
        Group {
            if categories.isEmpty {
                ContentUnavailableView("No Categories", systemImage: "folder",
                    description: Text("Sync your Paprika categories first."))
            } else {
                ForEach(categories, id: \.uid) { category in
                    Button {
                        selectedCategoryUid = category.uid
                        selectedCategoryName = category.name
                    } label: {
                        HStack {
                            Label(category.name, systemImage: "folder")
                                .foregroundStyle(.primary)
                            Spacer()
                            if selectedCategoryUid == category.uid {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.paprikaPrimary)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Recipe Picker

    private var filteredRecipes: [RecipeModel] {
        if searchText.isEmpty { return recipes }
        return recipes.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var recipePicker: some View {
        Group {
            if recipes.isEmpty {
                ContentUnavailableView("No Recipes", systemImage: "book.closed",
                    description: Text("Sync your Paprika recipes first."))
            } else {
                TextField("Search recipes…", text: $searchText)
                ForEach(filteredRecipes, id: \.uid) { recipe in
                    Button {
                        selectedRecipeUid = recipe.uid
                        selectedRecipeName = recipe.name
                    } label: {
                        HStack {
                            Label(recipe.name, systemImage: "book.closed")
                                .foregroundStyle(.primary)
                            Spacer()
                            if selectedRecipeUid == recipe.uid {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.paprikaPrimary)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Build Rule

    private func buildRule() -> SlotRule {
        let constraint: SlotConstraint = switch constraintType {
        case .freeform:
                .freeform(label: freeformText.trimmingCharacters(in: .whitespaces))
        case .category:
                .category(uid: selectedCategoryUid, name: selectedCategoryName)
        case .recipe:
                .recipe(uid: selectedRecipeUid, name: selectedRecipeName)
        }
        return SlotRule(dayOfWeek: selectedDay, constraint: constraint)
    }
}

// MARK: - Previews

#Preview("Add Rule") {
    AddRuleSheet { rule in
        print("Saved: \(rule)")
    }
    .modelContainer(for: [SlotRuleModel.self, RecipeModel.self, CategoryModel.self], inMemory: true)
}

#Preview("Rules List → Add Rule") {
    NavigationStack {
        RulesListView()
    }
    .modelContainer(for: [SlotRuleModel.self, RecipeModel.self, CategoryModel.self], inMemory: true)
}