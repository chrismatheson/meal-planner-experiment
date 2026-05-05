import Foundation
import SwiftData

@Observable
final class PlanGenerationViewModel {
    var weekPlan: WeekPlan?
    var isGenerating = false
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

    // Undo support - stores previous day assignments before regeneration
    private var undoSnapshot: [DayPlan]?
    var canUndo: Bool { undoSnapshot != nil && !hasSynced }

    private let paprikaClient = PaprikaClient()
    private let syncStatus = SyncStatusManager.shared
    private let rejectionTracker = RejectionTracker.shared
    private let recipeSyncEngine = RecipeSyncEngine()

    /// Passthrough to shared sync status
    var isSyncing: Bool {
        get { syncStatus.isSyncingMeals }
        set { syncStatus.isSyncingMeals = newValue }
    }

    init() {
        let (year, week) = Calendar.currentISOWeek
        currentWeekYear = year
        currentWeekNumber = week
    }

    // MARK: - Load Existing Meals

    /// Debug status message for UI
    var loadingStatus: String = ""

    /// Load existing meals for current week from cache, then refresh from API
    /// Uses stale-while-refresh: show cached data immediately, update in background
    func loadExistingMeals(context: ModelContext, forceRefresh: Bool = false) async {
        // Skip if we already have data for this week (unless forced)
        if !forceRefresh && hasGenerated && weekPlan?.days.count == 7 {
            print("🍽️ loadExistingMeals: Already have data for week \(currentWeekNumber), skipping")
            return
        }

        print("🍽️ loadExistingMeals: Starting for week \(currentWeekNumber) of \(currentWeekYear)")

        // Load recent history for exclusions (last 14 days)
        loadRecentHistory(context: context)

        // 1. STALE: Load from cache immediately (fast, works offline)
        let cachedMeals = loadFromCache(context: context)
        let hasCachedData = !cachedMeals.isEmpty

        if hasCachedData {
            // Show cached data immediately - no loading spinner
            await buildWeekPlanFromMeals(cachedMeals, context: context)
            isFromCache = true
            hasGenerated = true
            loadingStatus = "Showing cached data"
            print("📦 Loaded \(cachedMeals.count) meals from cache for week \(currentWeekNumber)")
        } else {
            // No cache - show loading state
            isLoadingExisting = true
            loadingStatus = "Loading meals..."
            print("📦 Cache empty for week \(currentWeekNumber)")
        }

        // 2. REFRESH: Update from API in background (if online)
        if !forceOffline {
            if hasCachedData {
                loadingStatus = "Updating..."
            }
            await refreshFromAPI(context: context)
        } else {
            loadingStatus = "Offline mode"
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
            loadingStatus = "No credentials"
            isOffline = true
            return
        }

        do {
            loadingStatus = "Authenticating..."
            print("🔄 Authenticating with \(email)...")

            // Authenticate
            let token = try await paprikaClient.login(email: email, password: password)
            try? keychain.saveToken(token)

            // First, sync recipes (needed for images and details)
            loadingStatus = "Syncing recipes..."
            print("🔄 Fetching recipes from Paprika API...")
            await syncRecipes(context: context)

            loadingStatus = "Fetching meals..."
            print("🔄 Fetching meals from Paprika API...")

            // Fetch all meals from API
            let apiMeals = try await paprikaClient.fetchMeals()
            print("🔄 Got \(apiMeals.count) total meals from API")

            // Log all meals for debugging
            for meal in apiMeals.prefix(10) {
                print("   📅 \(meal.name) - \(meal.date)")
            }

            // Filter to current week AND year
            print("🔄 Looking for meals in week \(currentWeekNumber) of year \(currentWeekYear)")
            let currentWeekMeals = apiMeals.filter { meal in
                guard let date = meal.dateValue else {
                    print("   ⚠️ Could not parse date: \(meal.date)")
                    return false
                }
                let (year, week) = Calendar.isoWeek(for: date)
                let matches = year == currentWeekYear && week == currentWeekNumber
                if matches {
                    print("   ✅ Match: \(meal.name) (\(meal.date)) - Week \(week)/\(year)")
                }
                return matches
            }

            print("🔄 Found \(currentWeekMeals.count) meals for week \(currentWeekNumber)/\(currentWeekYear)")

            // Update cache
            await updateCache(with: currentWeekMeals, context: context)

            // Rebuild week plan from fresh data
            let freshCachedMeals = loadFromCache(context: context)
            if !freshCachedMeals.isEmpty {
                await buildWeekPlanFromMeals(freshCachedMeals, context: context)
                isFromCache = false
                hasGenerated = true
                loadingStatus = "Loaded \(freshCachedMeals.count) meals from API"
            } else {
                loadingStatus = "No meals for this week"
            }

            isOffline = false
            print("🔄 Refreshed \(currentWeekMeals.count) meals from API for week \(currentWeekNumber)")

        } catch {
            print("⚠️ API refresh failed: \(error)")
            loadingStatus = "API error: \(error.localizedDescription)"
            isOffline = true
        }
    }

    /// Update cache with meals from API
    @MainActor
    private func updateCache(with meals: [PaprikaMeal], context: ModelContext) {
        // First, clear old cached meals for this week (to avoid stale data)
        let year = currentWeekYear
        let week = currentWeekNumber
        let oldMeals = FetchDescriptor<CachedMealModel>(
            predicate: #Predicate { meal in
                meal.isoWeekYear == year && meal.isoWeekNumber == week
            }
        )

        do {
            let existing = try context.fetch(oldMeals)
            print("🗑️ Clearing \(existing.count) old cached meals for week \(week)/\(year)")
            for old in existing {
                context.delete(old)
            }
        } catch {
            print("⚠️ Failed to clear old cache: \(error)")
        }

        // Now insert fresh meals
        for meal in meals {
            let cached = CachedMealModel(from: meal)
            context.insert(cached)
            print("   💾 Cached: \(meal.name) for \(meal.date)")
        }

        try? context.save()
        print("✅ Cached \(meals.count) meals for week \(week)/\(year)")
    }

    /// Sync recipes from Paprika API to local cache using hash-based incremental sync
    @MainActor
    private func syncRecipes(context: ModelContext) async {
        let result = await recipeSyncEngine.sync(client: paprikaClient, context: context)
        print("✅ Recipe sync: \(result.total) total, \(result.fetched) fetched, \(result.skipped) skipped")
    }

    /// Build WeekPlan from cached meals, filling gaps with recipes
    @MainActor
    private func buildWeekPlanFromMeals(_ meals: [CachedMealModel], context: ModelContext) {
        print("🍽️ buildWeekPlanFromMeals: Building from \(meals.count) cached meals")

        // Fetch recipes for lookup
        let recipeDescriptor = FetchDescriptor<RecipeModel>()
        let recipes = (try? context.fetch(recipeDescriptor)) ?? []
        let recipesByUid = Dictionary(uniqueKeysWithValues: recipes.map { ($0.uid, $0) })
        print("🍽️ Have \(recipes.count) recipes in local cache")

        // Create WeekPlan with available recipes
        weekPlan = WeekPlan(recipes: recipes)

        // Build days for current week
        guard let (monday, _) = Calendar.dateRange(forISOWeek: currentWeekNumber, year: currentWeekYear) else {
            print("❌ Could not get date range for week \(currentWeekNumber)")
            return
        }
        print("🍽️ Week starts: \(monday)")

        var days: [DayPlan] = []
        for dayOffset in 0..<7 {
            let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: monday) ?? monday

            // Find meal for this day
            let mealForDay = meals.first { meal in
                Calendar.current.isDate(meal.date, inSameDayAs: date)
            }

            let recipe: RecipeModel?
            let mealName: String?

            if let meal = mealForDay {
                // We have a meal - try to find matching recipe
                if let recipeUid = meal.recipeUid {
                    recipe = recipesByUid[recipeUid]
                    if recipe == nil {
                        print("   ⚠️ Day \(dayOffset): Meal '\(meal.recipeName)' has recipeUid but no local recipe")
                    }
                } else {
                    recipe = nil
                }
                // Always capture the meal name for display
                mealName = meal.recipeName
                print("   📅 Day \(dayOffset): \(meal.recipeName)")
            } else {
                recipe = nil
                mealName = nil
                print("   📅 Day \(dayOffset): No meal")
            }

            days.append(DayPlan(date: date, recipe: recipe, mealName: mealName))
        }

        weekPlan?.days = days
        print("🍽️ Built week plan with \(days.count) days")
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
        saveUndoSnapshot()

        // Track all current recipes as rejected
        if let currentRecipes = weekPlan?.days.compactMap({ $0.recipe?.uid }) {
            rejectionTracker.rejectRecipes(currentRecipes)
        }

        // Apply exclusions (rejections + history) and regenerate
        applyExclusionsToWeekPlan()
        weekPlan?.generate()
        hasSynced = false
        startCountdown()
    }

    /// Regenerate a specific day
    func regenerateDay(at index: Int) {
        saveUndoSnapshot()

        // Track the rejected recipe
        if let rejectedId = weekPlan?.regenerateDay(at: index) {
            rejectionTracker.rejectRecipe(rejectedId)
        }

        hasSynced = false
        startCountdown()
    }

    /// Apply all exclusions (rejections + history) to the week plan
    private func applyExclusionsToWeekPlan() {
        var exclusions = rejectionTracker.rejectedRecipeIds
        exclusions.formUnion(recentHistoryRecipeIds)
        weekPlan?.setExclusions(exclusions)
        print("📋 Applied exclusions: \(rejectionTracker.rejectionCount) rejected + \(recentHistoryRecipeIds.count) from history")
    }

    /// Recipe UIDs from meals in the last 14 days (to avoid repeats)
    private var recentHistoryRecipeIds: Set<String> {
        // This will be populated from SwiftData context
        // For now, return empty - will be wired up in loadExistingMeals
        cachedRecentRecipeIds
    }

    /// Cached recipe IDs from recent history
    private var cachedRecentRecipeIds: Set<String> = []

    /// Load recent history from SwiftData (last 14 days)
    func loadRecentHistory(context: ModelContext) {
        let fourteenDaysAgo = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()

        let descriptor = FetchDescriptor<CachedMealModel>(
            predicate: #Predicate { $0.date >= fourteenDaysAgo }
        )

        do {
            let recentMeals = try context.fetch(descriptor)
            cachedRecentRecipeIds = Set(recentMeals.compactMap { $0.recipeUid })
            print("📆 Loaded \(cachedRecentRecipeIds.count) recipes from last 14 days")
        } catch {
            print("⚠️ Failed to load recent history: \(error)")
            cachedRecentRecipeIds = []
        }
    }

    // MARK: - Undo Support

    /// Save current state before making changes
    private func saveUndoSnapshot() {
        guard let weekPlan = weekPlan else { return }
        // Deep copy the day plans (recipes are references, which is fine)
        undoSnapshot = weekPlan.days.map { day in
            DayPlan(date: day.date, recipe: day.recipe, mealName: day.mealName)
        }
    }

    /// Restore the previous state before last regeneration
    func undo() {
        guard let snapshot = undoSnapshot, let weekPlan = weekPlan else { return }
        weekPlan.days = snapshot
        undoSnapshot = nil
        hasSynced = false
        startCountdown()  // Restart countdown with restored plan
    }

    /// Clear undo history (called after sync to prevent undoing synced changes)
    private func clearUndoSnapshot() {
        undoSnapshot = nil
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

            // Fetch existing meals to find ones we need to replace
            let existingMeals = try await paprikaClient.fetchMeals()
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"

            // Build a map of date -> existing meal UID for the days we're planning
            var existingMealsByDate: [String: PaprikaMeal] = [:]
            for meal in existingMeals {
                // Extract just the date portion (ignore time)
                let dateOnly = String(meal.date.prefix(10))
                // Only track Dinner (type 2) meals to avoid conflicting with breakfast/lunch
                if meal.type == 2 {
                    existingMealsByDate[dateOnly] = meal
                }
            }
            print("📋 Found \(existingMealsByDate.count) existing dinner meals")

            // Convert DayPlans to PaprikaMeals, reusing UIDs for existing dates
            let meals: [PaprikaMeal] = weekPlan.days.compactMap { day in
                guard let recipe = day.recipe else { return nil }

                let dateStr = dateFormatter.string(from: day.date)

                // Check if there's an existing meal for this date
                let existingMeal = existingMealsByDate[dateStr]
                let mealUid: String

                if let existing = existingMeal {
                    // Reuse the existing UID to UPDATE instead of create duplicate
                    mealUid = existing.uid
                    print("   ♻️ Updating existing meal for \(dateStr): \(existing.name) → \(recipe.name)")
                } else {
                    // Generate new UID for new meal
                    mealUid = UUID().uuidString.uppercased()
                    print("   ➕ Creating new meal for \(dateStr): \(recipe.name)")
                }

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
                return PaprikaMeal(uid: mealUid, date: day.date, recipe: paprikaRecipe, type: 2)
            }

            guard !meals.isEmpty else {
                syncError = "No meals to sync"
                isSyncing = false
                return
            }

            // Save to Paprika (will update existing or create new)
            try await paprikaClient.saveMeals(meals)

            hasSynced = true
            clearUndoSnapshot()  // Can't undo after sync
            rejectionTracker.clearRejections()  // Clear rejections after successful sync
            syncStatus.markMealsSynced()
            print("✅ Synced \(meals.count) meals to Paprika")

            // Also drain any other pending offline changes
            await OfflineSyncQueue.shared.drainIfNeeded()

        } catch {
            syncError = "Sync failed: \(error.localizedDescription)"
            syncStatus.setError(error.localizedDescription)
            print("❌ Sync failed: \(error)")
        }

        isSyncing = false
    }
}
