import Foundation
import SwiftData

@Observable
final class RecipeListViewModel {
    var isLoading = false
    var error: Error?
    
    private let keychain = KeychainService()
    
    func syncRecipes(context: ModelContext) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let client = PaprikaClient(keychain: keychain)
            let paprikaRecipes = try await client.fetchRecipes()
            
            // Fetch existing recipes for updating
            let descriptor = FetchDescriptor<RecipeModel>()
            let existingRecipes = try context.fetch(descriptor)
            let existingByUid = Dictionary(uniqueKeysWithValues: existingRecipes.map { ($0.uid, $0) })
            
            // Update or insert recipes
            for paprikaRecipe in paprikaRecipes {
                if let existing = existingByUid[paprikaRecipe.uid] {
                    existing.update(from: paprikaRecipe)
                } else {
                    let newRecipe = RecipeModel(from: paprikaRecipe)
                    context.insert(newRecipe)
                }
            }
            
            try context.save()
        } catch {
            self.error = error
            print("Failed to sync recipes: \(error)")
        }
    }
}
