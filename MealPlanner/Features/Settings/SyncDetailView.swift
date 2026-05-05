import SwiftUI

/// Detailed sync status with event log, pushed from Settings → Sync section
struct SyncDetailView: View {
    private let syncManager = SyncStatusManager.shared
    private let eventLog = SyncEventLog.shared
    @State private var showCopied = false

    var body: some View {
        List {
            // MARK: - Summary
            Section {
                summaryRow(
                    icon: "arrow.triangle.2.circlepath",
                    label: "Status",
                    value: syncManager.isSyncing ? "Syncing…" : (syncManager.lastError != nil ? "Error" : "Up to date"),
                    valueColor: syncManager.lastError != nil ? .red : .secondary
                )

                if let lastMeal = syncManager.lastMealSyncTime {
                    summaryRow(icon: "fork.knife", label: "Meals", value: lastMeal.formatted(date: .abbreviated, time: .shortened))
                }

                if let lastRecipe = syncManager.lastRecipeSyncTime {
                    summaryRow(icon: "book", label: "Recipes", value: lastRecipe.formatted(date: .abbreviated, time: .shortened))
                }

                if let lastCategory = syncManager.lastCategorySyncTime {
                    summaryRow(icon: "folder", label: "Categories", value: lastCategory.formatted(date: .abbreviated, time: .shortened))
                }

                if let error = syncManager.lastError {
                    HStack(alignment: .top) {
                        Label("Error", systemImage: "exclamationmark.circle")
                            .foregroundStyle(.red)
                        Spacer()
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.trailing)
                    }
                }
            } header: {
                Text("Summary")
            }

            // MARK: - Event Log
            Section {
                if eventLog.events.isEmpty {
                    Text("No events yet. Sync activity will appear here.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color(.systemGroupedBackground))
                } else {
                    ForEach(eventLog.events) { event in
                        eventRow(event)
                    }
                }
            } header: {
                HStack {
                    Text("Event Log")
                    Spacer()
                    if !eventLog.events.isEmpty {
                        Button {
                            UIPasteboard.general.string = eventLog.plainText
                            showCopied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                showCopied = false
                            }
                        } label: {
                            Label(showCopied ? "Copied!" : "Copy", systemImage: showCopied ? "checkmark" : "doc.on.doc")
                                .font(.caption)
                        }
                    }
                }
            } footer: {
                Text("Last \(eventLog.events.count) events. Newest first.")
            }
        }
        .navigationTitle("Sync Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Components

    private func summaryRow(icon: String, label: String, value: String, valueColor: Color = .secondary) -> some View {
        HStack {
            Label(label, systemImage: icon)
            Spacer()
            Text(value)
                .foregroundStyle(valueColor)
        }
    }

    private func eventRow(_ event: SyncEventLog.Event) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: event.level.icon)
                .font(.caption2)
                .foregroundStyle(eventColor(event.level))
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.message)
                    .font(.caption)
                    .fontDesign(.monospaced)

                Text(event.formattedTime)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
    }

    private func eventColor(_ level: SyncEventLog.Event.Level) -> Color {
        switch level {
        case .info: return .secondary
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }
}

// MARK: - Previews

#Preview("Sync Details") {
    NavigationStack {
        SyncDetailView()
    }
}
