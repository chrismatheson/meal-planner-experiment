import Foundation
import SwiftData

@Observable
final class MealPlanViewModel {
    var mealSlots: [Date: MealSlotModel] = [:]
    var isLoading = false
    var error: Error?
    var client: PaprikaClient?
    
    func loadMealSlots(for dates: [Date], context: ModelContext) {
        let calendar = Calendar.current
        
        // Fetch all meal slots
        let descriptor = FetchDescriptor<MealSlotModel>()
        
        do {
            let allSlots = try context.fetch(descriptor)
            
            // Build dictionary keyed by date (day only)
            mealSlots = [:]
            for slot in allSlots {
                let dayStart = calendar.startOfDay(for: slot.date)
                mealSlots[dayStart] = slot
            }
        } catch {
            self.error = error
            print("Failed to load meal slots: \(error)")
        }
    }
    
    func mealSlot(for date: Date) -> MealSlotModel? {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        return mealSlots[dayStart]
    }
    
    func assignRecipe(_ recipe: RecipeModel, to date: Date, context: ModelContext) {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        
        // Remove existing slot if any
        if let existing = mealSlots[dayStart] {
            context.delete(existing)
        }
        
        // Create new slot
        let slot = MealSlotModel(date: dayStart, recipe: recipe)
        context.insert(slot)
        mealSlots[dayStart] = slot
        
        do {
            try context.save()
        } catch {
            self.error = error
            print("Failed to save meal slot: \(error)")
        }
        
        // Sync in background
        Task {
            await syncSlot(slot)
        }
    }
    
    func removeMeal(for date: Date, context: ModelContext) {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        
        if let existing = mealSlots[dayStart] {
            context.delete(existing)
            mealSlots.removeValue(forKey: dayStart)
            
            do {
                try context.save()
            } catch {
                self.error = error
            }
        }
    }
    
    private func syncSlot(_ slot: MealSlotModel) async {
        guard let client = client else { return }
        
        do {
            let paprikaItem = slot.toPaprikaModel()
            try await client.saveMealItem(paprikaItem)
            
            // Mark as synced
            slot.needsSync = false
        } catch {
            print("Failed to sync meal slot: \(error)")
            // Keep needsSync = true for retry later
        }
    }
    
    func syncAllPendingSlots(context: ModelContext) async {
        let descriptor = FetchDescriptor<MealSlotModel>(
            predicate: #Predicate { $0.needsSync }
        )
        
        do {
            let pendingSlots = try context.fetch(descriptor)
            for slot in pendingSlots {
                await syncSlot(slot)
            }
        } catch {
            print("Failed to fetch pending slots: \(error)")
        }
    }
}
