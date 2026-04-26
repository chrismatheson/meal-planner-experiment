import SwiftUI

/// Shows when cached data was last updated
/// Part of the stale-while-refresh pattern
struct StalenessIndicator: View {
    var isOffline: Bool = false
    private let syncManager = SyncStatusManager.shared
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
            Text(message)
                .font(.caption)
        }
        .foregroundStyle(foregroundColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(backgroundColor)
        .clipShape(Capsule())
    }
    
    private var icon: String {
        if isOffline {
            return "wifi.slash"
        }
        return "clock.arrow.circlepath"
    }
    
    private var message: String {
        if isOffline {
            return "Offline • \(syncManager.lastSyncDescription)"
        }
        return syncManager.lastSyncDescription
    }
    
    private var foregroundColor: Color {
        if isOffline {
            return .orange
        }
        // Check staleness level
        if let lastSync = syncManager.lastMealSyncTime {
            let age = Date().timeIntervalSince(lastSync)
            if age > 3600 { // > 1 hour
                return .orange
            }
        }
        return .secondary
    }
    
    private var backgroundColor: Color {
        if isOffline {
            return .orange.opacity(0.15)
        }
        return .secondary.opacity(0.1)
    }
}

#Preview("Recent") {
    StalenessIndicator()
}

#Preview("Offline") {
    StalenessIndicator(isOffline: true)
}
