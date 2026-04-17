import Foundation
import SwiftData

@Observable
final class PlanGenerationViewModel {
    var weekPlan: WeekPlan?
    var isGenerating = false
    var hasGenerated = false
    
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
            
            print("✅ Generated week plan with \(weekPlan?.days.count ?? 0) days")
        } catch {
            print("❌ Failed to fetch recipes: \(error)")
        }
        
        isGenerating = false
    }
    
    /// Regenerate all days with fresh random selections
    func regenerateAll() {
        weekPlan?.generate()
    }
    
    /// Regenerate a specific day
    func regenerateDay(at index: Int) {
        weekPlan?.regenerateDay(at: index)
    }
}
