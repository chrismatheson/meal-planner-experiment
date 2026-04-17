import Foundation

/// Client for Paprika Recipe Manager API v2
actor PaprikaClient {
    private let baseURL = URL(string: "https://www.paprikaapp.com/api/v2/")!
    private let keychain: KeychainService
    private var token: String?
    
    // Must identify as Paprika client
    private let userAgent = "Paprika Recipe Manager 3/3.7.4"
    
    init(keychain: KeychainService) {
        self.keychain = keychain
        self.token = try? keychain.getToken()
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
        
        // Try to decode - the API returns {"result": {"token": "..."}} 
        // but may also return {"result": "token_string"} directly
        do {
            let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
            guard let token = loginResponse.result.token else {
                throw PaprikaError.invalidCredentials
            }
            self.token = token
            try keychain.saveToken(token)
            return token
        } catch {
            // Try alternate format where result is the token directly
            struct DirectTokenResponse: Decodable {
                let result: String
            }
            let directResponse = try JSONDecoder().decode(DirectTokenResponse.self, from: data)
            self.token = directResponse.result
            try keychain.saveToken(directResponse.result)
            return directResponse.result
        }
    }
    
    // MARK: - Recipes
    
    func fetchRecipes() async throws -> [PaprikaRecipe] {
        let response: RecipesResponse = try await syncRequest(endpoint: "sync/recipes/")
        return response.result
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
    
    // MARK: - Private Helpers
    
    private func syncRequest<T: Decodable>(endpoint: String) async throws -> T {
        guard let token = token else {
            throw PaprikaError.notAuthenticated
        }
        
        let url = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.httpBody = "{}".data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PaprikaError.invalidResponse
        }
        
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
}

// MARK: - Data Extension for Multipart

private extension Data {
    mutating func appendMultipart(name: String, value: String, boundary: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        append("\(value)\r\n".data(using: .utf8)!)
    }
}
