import SwiftUI
import os.log

private let logger = Logger(subsystem: "PaprikaPlanner", category: "ImageCache")

/// Shared image cache for recipe photos
/// 50 MB memory, 200 MB disk
enum ImageCache {
    static let shared: URLCache = {
        let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let cacheDir = cachesDir.appendingPathComponent("recipe_images")

        // Ensure directory exists
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)

        return URLCache(
            memoryCapacity: 50_000_000,
            diskCapacity: 200_000_000,
            directory: cacheDir
        )
    }()

    /// For testing - check if URL is cached
    static func isCached(_ url: URL) -> Bool {
        let request = URLRequest(url: url)
        return shared.cachedResponse(for: request) != nil
    }
}

/// An image view that caches images to disk for reliable offline display
/// Replaces AsyncImage with persistent caching and shimmer loading state
struct CachedAsyncImage<Placeholder: View>: View {
    let url: URL?
    let placeholder: () -> Placeholder

    @State private var image: UIImage?
    @State private var isLoading = false

    init(url: URL?, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
            } else {
                placeholder()
                    .overlay {
                        if isLoading {
                            ShimmerView()
                        }
                    }
            }
        }
        .task(id: url) {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard let url = url else {
            logger.warning("⚠️ CachedAsyncImage: No URL provided")
            return
        }

        logger.info("🖼️ Loading image: \(url.absoluteString, privacy: .public)")

        // Check cache first
        let request = URLRequest(url: url)
        if let cachedResponse = ImageCache.shared.cachedResponse(for: request),
           let uiImage = UIImage(data: cachedResponse.data) {
            logger.debug("✓ Cache hit for \(url.lastPathComponent)")
            self.image = uiImage
            return
        }

        // Fetch from network
        isLoading = true

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            logger.debug("Downloaded \(data.count) bytes from \(url.lastPathComponent)")

            // Cache the response
            let cachedResponse = CachedURLResponse(response: response, data: data)
            ImageCache.shared.storeCachedResponse(cachedResponse, for: request)

            if let uiImage = UIImage(data: data) {
                logger.debug("✓ Image decoded: \(url.lastPathComponent)")
                await MainActor.run {
                    withAnimation(.easeIn(duration: 0.2)) {
                        self.image = uiImage
                        self.isLoading = false
                    }
                }
            } else {
                logger.error("✗ Failed to decode image data")
                await MainActor.run { self.isLoading = false }
            }
        } catch {
            logger.error("✗ Network error: \(error.localizedDescription)")
            await MainActor.run { self.isLoading = false }
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
