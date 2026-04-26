import XCTest
@testable import paprikaplanner

final class ImageCacheTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Clear cache before each test
        ImageCache.shared.removeAllCachedResponses()
    }
    
    func testCacheStoresAndRetrievesImage() async throws {
        // Given: A valid image URL (using a small test image)
        let testURL = URL(string: "https://httpbin.org/image/png")!
        let request = URLRequest(url: testURL)
        
        // When: We fetch and cache the image
        let (data, response) = try await URLSession.shared.data(for: request)
        let cachedResponse = CachedURLResponse(response: response, data: data)
        ImageCache.shared.storeCachedResponse(cachedResponse, for: request)
        
        // Then: The cache should contain the response
        XCTAssertTrue(ImageCache.isCached(testURL), "URL should be cached after storing")
        
        // And: We can retrieve valid image data
        let retrievedResponse = ImageCache.shared.cachedResponse(for: request)
        XCTAssertNotNil(retrievedResponse, "Should retrieve cached response")
        XCTAssertGreaterThan(retrievedResponse?.data.count ?? 0, 0, "Cached data should not be empty")
    }
    
    func testCacheReturnsFalseForUncachedURL() {
        // Given: A URL that was never cached
        let uncachedURL = URL(string: "https://example.com/never-cached-\(UUID()).png")!
        
        // Then: isCached should return false
        XCTAssertFalse(ImageCache.isCached(uncachedURL), "Uncached URL should return false")
    }
    
    func testCacheDirectoryExists() {
        // The cache directory should exist after ImageCache.shared is accessed
        _ = ImageCache.shared
        
        let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let cacheDir = cachesDir.appendingPathComponent("recipe_images")
        
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: cacheDir.path, isDirectory: &isDirectory)
        
        XCTAssertTrue(exists, "Cache directory should exist")
        XCTAssertTrue(isDirectory.boolValue, "Should be a directory")
    }
}

// MARK: - SyncStatusManager Tests

final class SyncStatusManagerTests: XCTestCase {
    
    var sut: SyncStatusManager!
    
    override func setUp() {
        super.setUp()
        sut = SyncStatusManager.shared
        // Clear any persisted state
        UserDefaults.standard.removeObject(forKey: "lastRecipeSyncTime")
        UserDefaults.standard.removeObject(forKey: "lastMealSyncTime")
        sut.pendingChangesCount = 0
    }
    
    func testInitialState() {
        XCTAssertNil(sut.lastRecipeSyncTime, "Should start with no recipe sync time")
        XCTAssertNil(sut.lastMealSyncTime, "Should start with no meal sync time")
        XCTAssertEqual(sut.pendingChangesCount, 0, "Should start with no pending changes")
        XCTAssertFalse(sut.hasPendingChanges, "Should have no pending changes")
    }
    
    func testMarkRecipesSynced() {
        // When
        sut.markRecipesSynced()
        
        // Then
        XCTAssertNotNil(sut.lastRecipeSyncTime)
        XCTAssertNil(sut.lastError)
    }
    
    func testMarkMealsSynced() {
        // Given
        sut.pendingChangesCount = 5
        
        // When
        sut.markMealsSynced()
        
        // Then
        XCTAssertNotNil(sut.lastMealSyncTime)
        XCTAssertEqual(sut.pendingChangesCount, 0, "Should clear pending changes")
    }
    
    func testIncrementPending() {
        // When
        sut.incrementPending()
        sut.incrementPending()
        
        // Then
        XCTAssertEqual(sut.pendingChangesCount, 2)
        XCTAssertTrue(sut.hasPendingChanges)
    }
    
    func testStatusSummary_NeverSynced() {
        XCTAssertEqual(sut.statusSummary, "Never synced")
    }
    
    func testStatusSummary_WithPendingAndSync() {
        // Given
        sut.markRecipesSynced()
        sut.incrementPending()
        sut.incrementPending()
        
        // Then - should contain both pending count and time
        XCTAssertTrue(sut.statusSummary.contains("2 pending"))
        XCTAssertTrue(sut.statusSummary.contains("just now") || sut.statusSummary.contains("ago"))
    }
    
    func testRelativeDescription() {
        let now = Date()
        XCTAssertEqual(now.relativeDescription, "just now")
        
        let fiveMinAgo = Date(timeIntervalSinceNow: -300)
        XCTAssertEqual(fiveMinAgo.relativeDescription, "5m ago")
        
        let twoHoursAgo = Date(timeIntervalSinceNow: -7200)
        XCTAssertEqual(twoHoursAgo.relativeDescription, "2h ago")
        
        let oneDayAgo = Date(timeIntervalSinceNow: -86400)
        XCTAssertEqual(oneDayAgo.relativeDescription, "1d ago")
    }
}
