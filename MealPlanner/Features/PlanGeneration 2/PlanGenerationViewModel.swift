import Foundation
import SwiftData

@Observable
final class PlanGenerationViewModel {
    var weekPlan: WeekPlan?
    var isGenerating = false
    var isSyncing = false
    var hasGenerated = false
    var hasSynced = false
    var syncError: String?

    // Countdown timer for auto-sync
    var countdownSeconds: Int = 0
    private var countdownTimer: Timer?

    private let paprikaClient = PaprikaClient()

    /// Generate a new week plan from cached recipes
    func generatePlan(context: ModelContext) {
        isGenerating = true

        // Fetch all cached recipes
        let descriptor = FetchDescriptor<RecipeModel>(
            sortBy: [SortDescriptor(\.name)]
        )

        do {
            let recipes = try context.fetch(descriptor)

            guard !recipes.isEmpty else {
                print("⚠️ No recipes available for generation")
                isGenerating = false
                return
            }

            // Create and generate the plan
            weekPlan = WeekPlan(recipes: recipes)
            weekPlan?.generate()
            hasGenerated = true
            hasSynced = false  // Reset sync state for new plan

            // Start countdown timer
            startCountdown()

            print("✅ Generated week plan with \(weekPlan?.days.count ?? 0) days")
        } catch {
            print("❌ Failed to fetch recipes: \(error)")
        }

        isGenerating = false
    }

    /// Regenerate all days with fresh random selections
    func regenerateAll() {
        weekPlan?.generate()
        hasSynced = false
        startCountdown()  // Reset countdown
    }

    /// Regenerate a specific day
    func regenerateDay(at index: Int) {
        weekPlan?.regenerateDay(at: index)
        hasSynced = false
        startCountdown()  // Reset countdown
    }

    // MARK: - Countdown Timer

    /// Start or restart the 20-second countdown
    func startCountdown() {
        stopCountdown()
        countdownSeconds = 20

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                if self.countdownSeconds > 0 {
                    self.countdownSeconds -= 1
                    if self.countdownSeconds == 0 && !self.hasSynced && !self.isSyncing {
                        // Auto-sync when countdown reaches 0
                        await self.acceptPlan()
                    }
                }
            }
        }
    }

    /// Stop the countdown timer
    func stopCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    /// Manually trigger sync (also stops countdown)
    func syncNow() async {
        stopCountdown()
        countdownSeconds = 0
        await acceptPlan()
    }

    /// Accept the plan and sync to Paprika
    func acceptPlan() async {
        guard let weekPlan = weekPlan else { return }

        isSyncing = true
        syncError = nil

        do {
            // Restore session from Keychain
            let keychain = KeychainService()

            print("🔑 Checking keychain for sync credentials...")
            print("🔑 hasStoredCredentials: \(keychain.hasStoredCredentials)")

            // For syncing, we MUST have email/password because v1 sync API uses Basic Auth
            // Bearer token is not enough for the saveMeals endpoint
            guard let email = try? keychain.getEmail(),
                  let password = try? keychain.getPassword() else {
                print("❌ No email/password in keychain!")
                syncError = "Not logged in"
                isSyncing = false
                return
            }

            print("🔑 Authenticating as \(email) for sync...")
            // Always login to ensure basicAuthHeader is set (needed for v1 sync API)
            let newToken = try await paprikaClient.login(email: email, password: password)
            try? keychain.saveToken(newToken)
            print("🔑 Authenticated successfully")

            // Convert DayPlans to PaprikaMeals
            let meals: [PaprikaMeal] = weekPlan.days.compactMap { day in
                guard let recipe = day.recipe else { return nil }
                // Create a temporary PaprikaRecipe for the model
                let paprikaRecipe = PaprikaRecipe(
                    uid: recipe.uid,
                    name: recipe.name,
                    ingredients: nil,
                    directions: nil,
                    description: nil,
                    servings: nil,
                    prepTime: recipe.prepTime,
                    cookTime: recipe.cookTime,
                    totalTime: recipe.totalTime,
                    rating: nil,
                    categories: nil,
                    photo: nil,
                    photoUrl: recipe.photoUrl,
                    source: nil,
                    sourceUrl: nil,
                    onFavorites: nil,
                    created: nil,
                    hash: nil,
                    photoHash: nil
                )
                return PaprikaMeal(date: day.date, recipe: paprikaRecipe, type: 2)
            }

            guard !meals.isEmpty else {
                syncError = "No meals to sync"
                isSyncing = false
                return
            }

            // Save to Paprika
            try await paprikaClient.saveMeals(meals)

            hasSynced = true
            print("✅ Synced \(meals.count) meals to Paprika")

        } catch {
            syncError = "Sync failed: \(error.localizedDescription)"
            print("❌ Sync failed: \(error)")
        }

        isSyncing = false
    }
}
