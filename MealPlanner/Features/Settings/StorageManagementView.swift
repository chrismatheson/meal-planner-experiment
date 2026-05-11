import SwiftData
import SwiftUI

struct StorageManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var snapshot = StorageUsageSnapshot(
        recipeCount: 0,
        cachedMealCount: 0,
        categoryCount: 0,
        localDataBytes: 0,
        imageCacheBytes: 0
    )
    @State private var errorMessage: String?
    @State private var isRefreshing = false
    @State private var showingImageClearConfirmation = false
    @State private var showingDataClearConfirmation = false

    var body: some View {
        List {
            Section {
                storageRow("Total Storage", value: StorageUsageManager.formattedSize(snapshot.totalBytes), icon: "internaldrive")
                storageRow("Recipe Photos", value: StorageUsageManager.formattedSize(snapshot.imageCacheBytes), icon: "photo")
                storageRow("Local Paprika Data", value: StorageUsageManager.formattedSize(snapshot.localDataBytes), icon: "cylinder")
            } header: {
                Text("Usage")
            } footer: {
                Text("Recipe photos are stored in the system Caches directory and can be purged by iOS. Local Paprika data is kept for offline use and rebuilt by syncing.")
            }

            Section {
                storageRow("Recipes", value: "\(snapshot.recipeCount)", icon: "book")
                storageRow("Meal Plan Items", value: "\(snapshot.cachedMealCount)", icon: "calendar")
                storageRow("Categories", value: "\(snapshot.categoryCount)", icon: "tag")
            } header: {
                Text("Local Records")
            }

            Section {
                Button(role: .destructive) {
                    showingImageClearConfirmation = true
                } label: {
                    Label("Clear Recipe Photo Cache", systemImage: "trash")
                }
                .disabled(snapshot.imageCacheBytes == 0)

                Button(role: .destructive) {
                    showingDataClearConfirmation = true
                } label: {
                    Label("Clear Local Paprika Data", systemImage: "trash")
                }
                .disabled(snapshot.recipeCount == 0 && snapshot.cachedMealCount == 0 && snapshot.categoryCount == 0)
            } footer: {
                Text("Clearing local Paprika data keeps your account, settings, and planning rules. Unsynced meal changes must be synced first.")
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Storage")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    refresh()
                } label: {
                    if isRefreshing {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(isRefreshing)
                .accessibilityLabel("Refresh storage usage")
            }
        }
        .confirmationDialog("Clear recipe photo cache?", isPresented: $showingImageClearConfirmation, titleVisibility: .visible) {
            Button("Clear Photo Cache", role: .destructive) {
                clearImageCache()
            }
        } message: {
            Text("Photos will download again when recipes are viewed.")
        }
        .confirmationDialog("Clear local Paprika data?", isPresented: $showingDataClearConfirmation, titleVisibility: .visible) {
            Button("Clear Local Data", role: .destructive) {
                clearSyncedData()
            }
        } message: {
            Text("Recipes, meal plan cache, and categories will be removed from this device and rebuilt on the next sync.")
        }
        .onAppear(perform: refresh)
    }

    private func storageRow(_ title: String, value: String, icon: String) -> some View {
        HStack {
            Label(title, systemImage: icon)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }

    private func refresh() {
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            snapshot = try StorageUsageManager.snapshot(context: modelContext)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func clearImageCache() {
        do {
            try StorageUsageManager.clearImageCache()
            refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func clearSyncedData() {
        do {
            try StorageUsageManager.clearSyncedPaprikaData(context: modelContext)
            refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        StorageManagementView()
    }
}
