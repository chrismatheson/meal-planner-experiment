import SwiftUI

/// Simple wrapper that uses native .refreshable() for pull-to-refresh
/// and shows sync status at the top
struct PullToRevealRefresh<Content: View>: View {
    let onRefresh: () async -> Void
    let content: () -> Content

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Sync status header - always visible
                SyncStatusBar()
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                // Main content
                content()
            }
        }
        .refreshable {
            await onRefresh()
        }
    }
}

// MARK: - Sync Status Bar

struct SyncStatusBar: View {
    var syncStatus = SyncStatusManager.shared

    var body: some View {
        HStack(spacing: 8) {
            // Sync icon
            Image(systemName: syncStatus.hasPendingChanges ? "arrow.triangle.2.circlepath" : "checkmark.icloud")
                .foregroundStyle(syncStatus.hasPendingChanges ? Color.paprikaPrimary : .secondary)
                .font(.subheadline)

            // Status text
            Text(syncStatus.statusSummary)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()
        }
    }
}
