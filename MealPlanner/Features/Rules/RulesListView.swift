import SwiftUI

/// Main rules screen — lists all slot-pinning rules with add/delete
struct RulesListView: View {
    @State private var rules: [SlotRule]
    @State private var showingAddRule = false
    
    /// Standalone initializer for preview-driven development
    init(rules: [SlotRule] = []) {
        _rules = State(initialValue: rules)
    }
    
    var body: some View {
        NavigationStack {
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
                    withAnimation {
                        rules.append(newRule)
                        rules.sort { $0.dayOfWeek < $1.dayOfWeek }
                    }
                }
            }
        }
    }
    
    // MARK: - Rules List

    private var rulesList: some View {
        List {
            ForEach(rules) { rule in
                RuleRowView(rule: rule)
                    .listRowInsets(EdgeInsets(top: Spacing.xs, leading: Spacing.md, bottom: Spacing.xs, trailing: Spacing.md))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
            .onDelete { indexSet in
                withAnimation {
                    rules.remove(atOffsets: indexSet)
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

#Preview("Empty state") {
    RulesListView()
}

#Preview("With rules") {
    RulesListView(rules: SlotRule.previews)
}

#Preview("Single rule") {
    RulesListView(rules: [
        SlotRule(dayOfWeek: 6, constraint: .freeform(label: "Takeaway"))
    ])
}
