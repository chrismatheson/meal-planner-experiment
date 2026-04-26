import SwiftUI

/// Shared image cache for recipe photos
/// 50 MB memory, 200 MB disk
enum ImageCache {
    static let shared: URLCache = {
        URLCache(
            memoryCapacity: 50_000_000,
            diskCapacity: 200_000_000,
            diskPath: "recipe_images"
        )
    }()
}

/// An image view that caches images to disk for reliable offline display
/// Replaces AsyncImage with persistent caching and better loading states
struct CachedAsyncImage<Placeholder: View>: View {
    let url: URL?
    let placeholder: () -> Placeholder

    @State private var image: UIImage?
    @State private var isLoading = false
    @State private var loadFailed = false
    @State private var retryCount = 0
    
    init(url: URL?, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
            } else if loadFailed {
                failedView
            } else {
                placeholder()
                    .overlay {
                        if isLoading {
                            shimmerOverlay
                        }
                    }
            }
        }
        .task(id: url) {
            await loadImage()
        }
    }
    
    private var shimmerOverlay: some View {
        ShimmerView()
    }
    
    private var failedView: some View {
        placeholder()
            .overlay {
                VStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                        .font(.title3)
                    Text("Tap to retry")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
            }
            .onTapGesture {
                retryCount += 1
                loadFailed = false
                Task { await loadImage() }
            }
    }
    
    private func loadImage() async {
        guard let url = url else {
            loadFailed = true
            return
        }
        
        // Check cache first
        let request = URLRequest(url: url)
        if let cachedResponse = ImageCache.shared.cachedResponse(for: request),
           let uiImage = UIImage(data: cachedResponse.data) {
            self.image = uiImage
            return
        }
        
        // Fetch from network
        isLoading = true
        defer { isLoading = false }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Cache the response
            let cachedResponse = CachedURLResponse(response: response, data: data)
            ImageCache.shared.storeCachedResponse(cachedResponse, for: request)
            
            if let uiImage = UIImage(data: data) {
                await MainActor.run {
                    withAnimation(.easeIn(duration: 0.2)) {
                        self.image = uiImage
                    }
                }
            } else {
                loadFailed = true
            }
        } catch {
            print("Image load failed: \(error.localizedDescription)")
            loadFailed = true
        }
    }
}

// MARK: - Shimmer Effect

struct ShimmerView: View {
    @State private var phase: CGFloat = 0
    
    var body: some View {
        LinearGradient(
            colors: [
                Color.gray.opacity(0.1),
                Color.gray.opacity(0.3),
                Color.gray.opacity(0.1)
            ],
            startPoint: .init(x: phase - 0.5, y: 0.5),
            endPoint: .init(x: phase + 0.5, y: 0.5)
        )
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                phase = 1.5
            }
        }
    }
}

// MARK: - Convenience Init

extension CachedAsyncImage where Placeholder == Color {
    init(url: URL?) {
        self.init(url: url) { Color.paprikaCream }
    }
}
