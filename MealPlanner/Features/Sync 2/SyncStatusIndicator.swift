import SwiftUI

/// Minimal sync status indicator for toolbar
/// Shows a colored dot/icon that expands to show details on tap
struct SyncStatusIndicator: View {
    let countdownSeconds: Int
    let isSyncing: Bool
    let hasSynced: Bool
    let hasError: Bool
    let onSyncNow: () async -> Void
    
    @State private var showingDetails = false
    
    var body: some View {
        Button {
            showingDetails = true
        } label: {
            statusIcon
                .frame(width: 24, height: 24)
        }
        .popover(isPresented: $showingDetails) {
            SyncStatusPopover(
                countdownSeconds: countdownSeconds,
                isSyncing: isSyncing,
                hasSynced: hasSynced,
                hasError: hasError,
                onSyncNow: onSyncNow,
                onDismiss: { showingDetails = false }
            )
            .presentationCompactAdaptation(.popover)
        }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Tap to view sync details")
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        if isSyncing {
            ProgressView()
                .scaleEffect(0.8)
        } else if hasSynced {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        } else if hasError {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
        } else if countdownSeconds > 0 {
            // Pending changes - orange dot
            Circle()
                .fill(Color.orange)
                .frame(width: 10, height: 10)
        } else {
            // Idle/ready state
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundStyle(.secondary)
        }
    }
    
    private var accessibilityLabel: String {
        if isSyncing { return "Syncing to Paprika" }
        if hasSynced { return "Synced to Paprika" }
        if hasError { return "Sync error" }
        if countdownSeconds > 0 { return "Changes pending, syncing in \(countdownSeconds) seconds" }
        return "Sync status"
    }
}

/// Popover showing detailed sync status
struct SyncStatusPopover: View {
    let countdownSeconds: Int
    let isSyncing: Bool
    let hasSynced: Bool
    let hasError: Bool
    let onSyncNow: () async -> Void
    let onDismiss: () -> Void
    
    private let lastSyncTime = SyncStatusManager.shared.lastMealSyncTime
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Sync Status")
                    .font(.headline)
                Spacer()
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            // Status
            HStack(spacing: 8) {
                statusIndicator
                VStack(alignment: .leading, spacing: 2) {
                    Text(statusTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    if let subtitle = statusSubtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Last sync time
            if let lastSync = lastSyncTime {
                HStack {
                    Image(systemName: "clock")
                        .foregroundStyle(.secondary)
                    Text("Last synced: \(lastSync.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Sync Now button (only when not synced and not syncing)
            if !hasSynced && !isSyncing {
                Button {
                    Task {
                        await onSyncNow()
                    }
                } label: {
                    Text("Sync Now")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.paprikaPrimary)
            }
        }
        .padding()
        .frame(width: 220)
    }
    
    @ViewBuilder
    private var statusIndicator: some View {
        if isSyncing {
            ProgressView()
        } else if hasSynced {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        } else if hasError {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
        } else {
            Circle()
                .fill(Color.orange)
                .frame(width: 12, height: 12)
        }
    }
    
    private var statusTitle: String {
        if isSyncing { return "Syncing..." }
        if hasSynced { return "Synced" }
        if hasError { return "Sync Error" }
        return "Changes Pending"
    }
    
    private var statusSubtitle: String? {
        if isSyncing { return "Sending to Paprika" }
        if hasSynced { return "Meal plan is up to date" }
        if hasError { return "Tap to retry" }
        if countdownSeconds > 0 { return "Auto-sync in \(countdownSeconds)s" }
        return nil
    }
}

#Preview("Pending") {
    SyncStatusIndicator(
        countdownSeconds: 15,
        isSyncing: false,
        hasSynced: false,
        hasError: false,
        onSyncNow: {}
    )
    .padding()
}

#Preview("Synced") {
    SyncStatusIndicator(
        countdownSeconds: 0,
        isSyncing: false,
        hasSynced: true,
        hasError: false,
        onSyncNow: {}
    )
    .padding()
}
