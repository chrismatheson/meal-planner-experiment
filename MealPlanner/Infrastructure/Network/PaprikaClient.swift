import Foundation

/// Client for Paprika Recipe Manager API v2
actor PaprikaClient {
    private let baseURL = URL(string: "https://www.paprikaapp.com/api/v2/")!
    private var token: String?
    
    // Must identify as Paprika client with platform info
    private let userAgent = "Paprika Recipe Manager 3/3.7.4 (iOS 17.0; iPhone)"
    
    init() {
        // Token stored in memory for now
        // TODO: Add Keychain storage once app is properly signed
    }
    
    init(keychain: KeychainService) {
        // Legacy init for compatibility
    }
    
    // MARK: - Authentication
    
    func login(email: String, password: String) async throws -> String {
        let url = baseURL.appendingPathComponent("account/login/")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Build multipart form data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        
        var body = Data()
        body.appendMultipart(name: "email", value: email, boundary: boundary)
        body.appendMultipart(name: "password", value: password, boundary: boundary)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PaprikaError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw PaprikaError.invalidCredentials
            }
            throw PaprikaError.serverError(httpResponse.statusCode)
        }
        
        // Debug: Print raw response to understand structure
        #if DEBUG
        if let jsonString = String(data: data, encoding: .utf8) {
            print("Login response: \(jsonString)")
        }
        #endif
        
        // Parse JSON manually for more control
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? [String: Any],
              let token = result["token"] as? String else {
            // Check if there's an error in the response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                print("API Error: \(message)")
                if message.contains("Unrecognized") {
                    throw PaprikaError.invalidResponse
                }
            }
            throw PaprikaError.invalidCredentials
        }
        
        self.token = token
        // Skip keychain for now - token stored in memory
        return token
    }
    
    // MARK: - Recipes
    
    /// Fetches recipes (list first, then details for each)
    /// Limited to first 50 for performance - TODO: add pagination
    func fetchRecipes(limit: Int = 50) async throws -> [PaprikaRecipe] {
        // First get the list of recipe UIDs
        let listResponse: RecipesListResponse = try await syncRequest(endpoint: "sync/recipes/")
        
        print("Found \(listResponse.result.count) recipes, fetching first \(min(limit, listResponse.result.count))...")
        
        // Fetch details for each (limited for performance)
        var recipes: [PaprikaRecipe] = []
        for stub in listResponse.result.prefix(limit) {
            do {
                let recipe = try await fetchRecipeDetail(uid: stub.uid)
                recipes.append(recipe)
                print("  Fetched: \(recipe.name)")
            } catch {
                print("  Failed to fetch recipe \(stub.uid): \(error)")
            }
        }
        
        return recipes
    }
    
    func fetchRecipeDetail(uid: String) async throws -> PaprikaRecipe {
        let response: RecipeDetailResponse = try await syncRequest(endpoint: "sync/recipe/\(uid)/")
        return response.result
    }
    
    // MARK: - Meal Plans
    
    func fetchMealItems() async throws -> [PaprikaMealItem] {
        let response: MealItemsResponse = try await syncRequest(endpoint: "sync/menuitems/")
        return response.result
    }
    
    func saveMealItem(_ item: PaprikaMealItem) async throws {
        try await postSyncRequest(endpoint: "sync/menuitem/\(item.uid)/", body: item)
    }

    func deleteMealItem(uid: String) async throws {
        try await deleteRequest(endpoint: "sync/menuitem/\(uid)/")
    }
    
    // MARK: - Private Helpers
    
    private func syncRequest<T: Decodable>(endpoint: String) async throws -> T {
        guard let token = token else {
            throw PaprikaError.notAuthenticated
        }
        
        let url = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"  // Sync endpoints use GET, not POST
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PaprikaError.invalidResponse
        }
        
        #if DEBUG
        if let jsonString = String(data: data, encoding: .utf8) {
            print("API Response (\(endpoint)): \(jsonString.prefix(200))...")
        }
        #endif
        
        if httpResponse.statusCode == 401 {
            throw PaprikaError.notAuthenticated
        }
        
        guard httpResponse.statusCode == 200 else {
            throw PaprikaError.serverError(httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    private func postSyncRequest<T: Encodable>(endpoint: String, body: T) async throws {
        guard let token = token else {
            throw PaprikaError.notAuthenticated
        }

        let url = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONEncoder().encode(body)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw PaprikaError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
    }

    private func deleteRequest(endpoint: String) async throws {
        guard let token = token else {
            throw PaprikaError.notAuthenticated
        }

        let url = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw PaprikaError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
    }
}

// MARK: - Data Extension for Multipart

private extension Data {
    mutating func appendMultipart(name: String, value: String, boundary: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        append("\(value)\r\n".data(using: .utf8)!)
    }
}
