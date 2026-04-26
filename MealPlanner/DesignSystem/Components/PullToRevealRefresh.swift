import SwiftUI

/// A scroll view wrapper with two-stage pull interaction:
/// - Small pull (40pt): Reveals sync status info
/// - Large pull (80pt): Triggers refresh action
struct PullToRevealRefresh<Content: View>: View {
    let onRefresh: () async -> Void
    let content: () -> Content
    
    @State private var pullOffset: CGFloat = 0
    @State private var isRefreshing = false
    @State private var showingStatus = false
    
    private let revealThreshold: CGFloat = 40
    private let refreshThreshold: CGFloat = 80
    
    var body: some View {
        GeometryReader { outerGeo in
            ScrollView {
                VStack(spacing: 0) {
                    // Status bar that appears on pull
                    statusBar
                        .frame(height: max(0, pullOffset))
                        .clipped()
                    
                    // Main content
                    content()
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(
                                    key: ScrollOffsetKey.self,
                                    value: geo.frame(in: .named("scroll")).minY
                                )
                            }
                        )
                }
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetKey.self) { offset in
                handleScroll(offset: offset)
            }
        }
    }
    
    private var statusBar: some View {
        HStack(spacing: 12) {
            if isRefreshing {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Syncing...")
                    .font(.subheadline)
            } else {
                // Sync status info
                SyncStatusBar()
                
                Spacer()
                
                // Pull indicator
                if pullOffset > 0 {
                    Text(pullOffset >= refreshThreshold ? "Release to refresh" : "Pull to refresh")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground).opacity(0.95))
    }
    
    private func handleScroll(offset: CGFloat) {
        // Only track positive offset (pulling down)
        pullOffset = max(0, offset)
        
        // Show status when pulled past reveal threshold
        showingStatus = pullOffset >= revealThreshold
        
        // Trigger refresh when released past refresh threshold
        if !isRefreshing && pullOffset >= refreshThreshold {
            triggerRefresh()
        }
    }
    
    private func triggerRefresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        Task {
            await onRefresh()
            await MainActor.run {
                withAnimation {
                    isRefreshing = false
                }
            }
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
        }
    }
}

// MARK: - Scroll Offset Preference Key

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
