import Foundation
import SwiftData

@Observable
final class PlanGenerationViewModel {
    var weekPlan: WeekPlan?
    var isGenerating = false
    var isSyncing = false
    var isLoadingExisting = false
    var hasGenerated = false
    var hasSynced = false
    var syncError: String?

    // Offline mode support
    var isOffline = false
    var forceOffline = false  // User can force offline via long-press
    var isFromCache = false   // True if showing cached data (not fresh from API)

    // Current ISO week being displayed
    private(set) var currentWeekYear: Int = 0
    private(set) var currentWeekNumber: Int = 0

    // Countdown timer for auto-sync
    var countdownSeconds: Int = 0
    private var countdownTimer: Timer?

    private let paprikaClient = PaprikaClient()

    init() {
        let (year, week) = Calendar.currentISOWeek
        currentWeekYear = year
        currentWeekNumber = week
    }

    // MARK: - Load Existing Meals

    /// Load existing meals for current week from cache, then refresh from API
    func loadExistingMeals(context: ModelContext) async {
        isLoadingExisting = true

        // 1. First, load from cache (fast, works offline)
        let cachedMeals = loadFromCache(context: context)
        if !cachedMeals.isEmpty {
            await buildWeekPlanFromMeals(cachedMeals, context: context)
            isFromCache = true
            hasGenerated = true
            print("📦 Loaded \(cachedMeals.count) meals from cache for week \(currentWeekNumber)")
        }

        // 2. Then, refresh from API if online
        if !forceOffline {
            await refreshFromAPI(context: context)
        }

        isLoadingExisting = false
    }

    /// Load meals from SwiftData cache for current week
    private func loadFromCache(context: ModelContext) -> [CachedMealModel] {
        let year = currentWeekYear
        let week = currentWeekNumber

        let descriptor = FetchDescriptor<CachedMealModel>(
            predicate: #Predicate { meal in
                meal.isoWeekYear == year && meal.isoWeekNumber == week
            },
            sortBy: [SortDescriptor(\.date)]
        )

        do {
            return try context.fetch(descriptor)
        } catch {
            print("❌ Failed to load cached meals: \(error)")
            return []
        }
    }

    /// Refresh meals from Paprika API and update cache
    private func refreshFromAPI(context: ModelContext) async {
        let keychain = KeychainService()

        guard let email = try? keychain.getEmail(),
              let password = try? keychain.getPassword() else {
            print("⚠️ No credentials, staying with cached data")
            isOffline = true
            return
        }

        do {
            // Authenticate
            let token = try await paprikaClient.login(email: email, password: password)
            try? keychain.saveToken(token)

            // Fetch all meals from API
            let apiMeals = try await paprikaClient.fetchMeals()

            // Filter to current week and cache them
            let currentWeekMeals = apiMeals.filter { meal in
                guard let date = meal.dateValue else { return false }
                let (year, week) = Calendar.isoWeek(for: date)
                return year == currentWeekYear && week == currentWeekNumber
            }

            // Update cache
            await updateCache(with: currentWeekMeals, context: context)

            // Rebuild week plan from fresh data
            let freshCachedMeals = loadFromCache(context: context)
            if !freshCachedMeals.isEmpty {
                await buildWeekPlanFromMeals(freshCachedMeals, context: context)
                isFromCache = false
                hasGenerated = true
            }

            isOffline = false
            print("🔄 Refreshed \(currentWeekMeals.count) meals from API for week \(currentWeekNumber)")

        } catch {
            print("⚠️ API refresh failed, using cache: \(error)")
            isOffline = true
        }
    }

    /// Update cache with meals from API
    @MainActor
    private func updateCache(with meals: [PaprikaMeal], context: ModelContext) {
        for meal in meals {
            // Check if already cached
            let uid = meal.uid
            let descriptor = FetchDescriptor<CachedMealModel>(
                predicate: #Predicate { $0.uid == uid }
            )

            do {
                let existing = try context.fetch(descriptor)
                if existing.isEmpty {
                    // Insert new
                    let cached = CachedMealModel(from: meal)
                    context.insert(cached)
                }
                // Note: We could update existing here if needed
            } catch {
                print("❌ Cache update error: \(error)")
            }
        }

        try? context.save()
    }

    /// Build WeekPlan from cached meals, filling gaps with recipes
    @MainActor
    private func buildWeekPlanFromMeals(_ meals: [CachedMealModel], context: ModelContext) {
        // Fetch recipes for lookup
        let recipeDescriptor = FetchDescriptor<RecipeModel>()
        let recipes = (try? context.fetch(recipeDescriptor)) ?? []
        let recipesByUid = Dictionary(uniqueKeysWithValues: recipes.map { ($0.uid, $0) })

        // Create WeekPlan with available recipes
        weekPlan = WeekPlan(recipes: recipes)

        // Build days for current week
        guard let (monday, _) = Calendar.dateRange(forISOWeek: currentWeekNumber, year: currentWeekYear) else {
            return
        }

        var days: [DayPlan] = []
        for dayOffset in 0..<7 {
            let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: monday) ?? monday

            // Find meal for this day
            let mealForDay = meals.first { meal in
                Calendar.current.isDate(meal.date, inSameDayAs: date)
            }

            let recipe: RecipeModel?
            if let meal = mealForDay, let recipeUid = meal.recipeUid {
                recipe = recipesByUid[recipeUid]
            } else {
                recipe = nil
            }

            days.append(DayPlan(date: date, recipe: recipe))
        }

        weekPlan?.days = days
    }

    /// Generate a new week plan from cached recipes (replaces existing)
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

    /// Toggle force offline mode (for testing)
    func toggleForceOffline() {
        forceOffline.toggle()
        isOffline = forceOffline
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
