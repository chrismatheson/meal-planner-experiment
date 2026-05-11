import Foundation
import SwiftData

struct StorageUsageSnapshot: Equatable {
    var recipeCount: Int
    var cachedMealCount: Int
    var categoryCount: Int
    var localDataBytes: Int64
    var imageCacheBytes: Int64

    var totalBytes: Int64 {
        localDataBytes + imageCacheBytes
    }
}

enum StorageUsageError: LocalizedError {
    case pendingMealChanges(Int)

    var errorDescription: String? {
        switch self {
        case .pendingMealChanges(let count):
            return "Sync \(count) pending meal change\(count == 1 ? "" : "s") before clearing local Paprika data."
        }
    }
}

enum StorageUsageManager {
    static func snapshot(context: ModelContext, fileManager: FileManager = .default) throws -> StorageUsageSnapshot {
        let recipeCount = try context.fetch(FetchDescriptor<RecipeModel>()).count
        let cachedMealCount = try context.fetch(FetchDescriptor<CachedMealModel>()).count
        let categoryCount = try context.fetch(FetchDescriptor<CategoryModel>()).count

        return StorageUsageSnapshot(
            recipeCount: recipeCount,
            cachedMealCount: cachedMealCount,
            categoryCount: categoryCount,
            localDataBytes: swiftDataStoreSize(fileManager: fileManager),
            imageCacheBytes: directorySize(at: ImageCache.directoryURL, fileManager: fileManager)
        )
    }

    static func clearImageCache(fileManager: FileManager = .default) throws {
        try ImageCache.clear()
    }

    @MainActor
    static func clearSyncedPaprikaData(context: ModelContext) throws {
        let pendingMeals = try context.fetch(
            FetchDescriptor<CachedMealModel>(predicate: #Predicate<CachedMealModel> { $0.needsSync })
        )
        guard pendingMeals.isEmpty else {
            throw StorageUsageError.pendingMealChanges(pendingMeals.count)
        }

        try context.delete(model: RecipeModel.self)
        try context.delete(model: CachedMealModel.self)
        try context.delete(model: CategoryModel.self)
        try context.save()

        SyncStatusManager.shared.lastRecipeSyncTime = nil
        SyncStatusManager.shared.lastMealSyncTime = nil
        SyncStatusManager.shared.lastCategorySyncTime = nil
        SyncStatusManager.shared.pendingChangesCount = 0
    }

    static func formattedSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    static func directorySize(at url: URL, fileManager: FileManager = .default) -> Int64 {
        guard fileManager.fileExists(atPath: url.path) else { return 0 }

        let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey]
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: Array(keys)) else {
            return 0
        }

        return enumerator.compactMap { item -> Int64? in
            guard let fileURL = item as? URL,
                  let values = try? fileURL.resourceValues(forKeys: keys),
                  values.isRegularFile == true else {
                return nil
            }

            return Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }
        .reduce(0, +)
    }

    private static func swiftDataStoreSize(fileManager: FileManager = .default) -> Int64 {
        let storeURL = ModelConfiguration(isStoredInMemoryOnly: false).url
        let storeDirectory = storeURL.deletingLastPathComponent()
        let storeName = storeURL.lastPathComponent

        return ["", "-wal", "-shm"]
            .map { storeDirectory.appendingPathComponent(storeName + $0) }
            .reduce(0) { total, fileURL in
                total + allocatedSize(of: fileURL, fileManager: fileManager)
            }
    }

    private static func allocatedSize(of fileURL: URL, fileManager: FileManager) -> Int64 {
        guard fileManager.fileExists(atPath: fileURL.path),
              let values = try? fileURL.resourceValues(forKeys: [.fileAllocatedSizeKey, .totalFileAllocatedSizeKey]) else {
            return 0
        }

        return Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
    }
}
