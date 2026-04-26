import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.curleybracketsengineering.paprikaplanner", category: "ImageCache")

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
        .onChange(of: url) { oldURL, newURL in
            // Reset image when URL changes so we don't show stale image
            if oldURL != newURL {
                image = nil
                isLoading = false
            }
        }
        .task(id: url) {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard var url = url else { return }

        // Convert HTTP to HTTPS (iOS App Transport Security blocks HTTP)
        if url.scheme == "http", var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            components.scheme = "https"
            if let httpsURL = components.url {
                url = httpsURL
            }
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

        do {
            // Use custom URLSession configuration that prefers cache
            var request = URLRequest(url: url)
            request.cachePolicy = .returnCacheDataElseLoad

            let config = URLSessionConfiguration.default
            config.urlCache = ImageCache.shared
            config.requestCachePolicy = .returnCacheDataElseLoad
            let session = URLSession(configuration: config)

            let (data, response) = try await session.data(for: request)

            // Cache the response
            let cachedResponse = CachedURLResponse(response: response, data: data)
            ImageCache.shared.storeCachedResponse(cachedResponse, for: request)

            if let uiImage = UIImage(data: data) {
                await MainActor.run {
                    withAnimation(.easeIn(duration: 0.2)) {
                        self.image = uiImage
                        self.isLoading = false
                    }
                }
            } else {
                await MainActor.run { self.isLoading = false }
            }
        } catch {
            // Network failed - check cache one more time (defensive)
            if let cachedResponse = ImageCache.shared.cachedResponse(for: request),
               let uiImage = UIImage(data: cachedResponse.data) {
                await MainActor.run {
                    self.image = uiImage
                    self.isLoading = false
                }
            } else {
                await MainActor.run { self.isLoading = false }
            }
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
