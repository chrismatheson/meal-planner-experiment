import SwiftUI
import SwiftData

/// Main rules screen — lists all slot-pinning rules with add/delete
struct RulesListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SlotRuleModel.dayOfWeek) private var ruleModels: [SlotRuleModel]
    @State private var showingAddRule = false

    /// Computed view-layer rules from persisted models
    private var rules: [SlotRule] {
        ruleModels.map { $0.toSlotRule() }
    }

    var body: some View {
        Group {
            if rules.isEmpty {
                emptyState
            } else {
                rulesList
            }
        }
        .navigationTitle("My Rules")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddRule = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddRule) {
            AddRuleSheet { newRule in
                let model = SlotRuleModel(from: newRule)
                modelContext.insert(model)
            }
        }
    }

    // MARK: - Rules List

    private var rulesList: some View {
        List {
            ForEach(ruleModels, id: \.id) { ruleModel in
                RuleRowView(rule: ruleModel.toSlotRule())
                    .listRowInsets(EdgeInsets(top: Spacing.xs, leading: Spacing.md, bottom: Spacing.xs, trailing: Spacing.md))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
            .onDelete { indexSet in
                for index in indexSet {
                    modelContext.delete(ruleModels[index])
                }
            }
        }
        .listStyle(.plain)
        .background(Color(.systemGroupedBackground))
        .scrollContentBackground(.hidden)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Rules Yet", systemImage: "list.bullet.rectangle")
        } description: {
            Text("Set a rule for any day of the week.\nFor example, \"Takeaway Friday\" or \"Sunday Roast\".")
        } actions: {
            Button {
                showingAddRule = true
            } label: {
                Text("Add Rule")
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.paprikaPrimary)
        }
    }
}

// MARK: - Previews

#Preview("Rules List") {
    NavigationStack {
        RulesListView()
    }
    .modelContainer(for: [SlotRuleModel.self, RecipeModel.self, CategoryModel.self], inMemory: true)
}
