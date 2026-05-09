import Foundation

/// Pure planning logic extracted from `WeekPlan` so it can be tested directly.
struct PlanGenerator {
    typealias RecipeChooser = ([RecipeModel]) -> RecipeModel?

    private let chooseRecipe: RecipeChooser
    private let maxSameCuisinePerWeek: Int

    init(
        maxSameCuisinePerWeek: Int = 2,
        chooseRecipe: @escaping RecipeChooser = { $0.randomElement() }
    ) {
        self.maxSameCuisinePerWeek = maxSameCuisinePerWeek
        self.chooseRecipe = chooseRecipe
    }

    func generateWeek(
        from recipes: [RecipeModel],
        excluding excludedRecipeIds: Set<String>,
        startingOn startDate: Date = Date()
    ) -> [DayPlan] {
        var days: [DayPlan] = []

        for dayOffset in 0..<7 {
            let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: startDate) ?? startDate
            let recipe = pickRecipe(
                from: recipes,
                for: days,
                excluding: excludedRecipeIds
            )
            days.append(DayPlan(date: date, recipe: recipe))
        }

        return days
    }

    func regenerateDay(
        day index: Int,
        in currentDays: [DayPlan],
        from recipes: [RecipeModel],
        excluding excludedRecipeIds: Set<String>
    ) -> DayPlan? {
        guard index >= 0 && index < currentDays.count else { return nil }

        var daysExcludingTarget = currentDays
        daysExcludingTarget.remove(at: index)

        let recipe = pickRecipe(
            from: recipes,
            for: daysExcludingTarget,
            excluding: excludedRecipeIds
        )

        return DayPlan(date: currentDays[index].date, recipe: recipe)
    }

    private func pickRecipe(
        from recipes: [RecipeModel],
        for existingDays: [DayPlan],
        excluding excludedRecipeIds: Set<String>
    ) -> RecipeModel? {
        let usedIds = Set(existingDays.compactMap { $0.recipe?.uid })
        var available = recipes.filter { recipe in
            !usedIds.contains(recipe.uid) && !excludedRecipeIds.contains(recipe.uid)
        }

        if available.isEmpty {
            let fallback = recipes.filter { !usedIds.contains($0.uid) }
            return chooseRecipe(fallback)
        }

        let overusedCuisines = getOverusedCuisines(in: existingDays)
        if !overusedCuisines.isEmpty {
            let diverseOptions = available.filter { recipe in
                let cuisine = CuisineType.detect(from: recipe.categories)
                return cuisine == .unknown || !overusedCuisines.contains(cuisine)
            }
            if !diverseOptions.isEmpty {
                return chooseRecipe(diverseOptions)
            }
        }

        return chooseRecipe(available)
    }

    private func getOverusedCuisines(in days: [DayPlan]) -> Set<CuisineType> {
        var cuisineCounts: [CuisineType: Int] = [:]

        for day in days {
            guard let recipe = day.recipe else { continue }
            let cuisine = CuisineType.detect(from: recipe.categories)
            if cuisine != .unknown {
                cuisineCounts[cuisine, default: 0] += 1
            }
        }

        return Set(cuisineCounts.filter { $0.value >= maxSameCuisinePerWeek }.keys)
    }
}
