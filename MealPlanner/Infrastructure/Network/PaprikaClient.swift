import Foundation
import Compression

/// Client for Paprika Recipe Manager API
/// Uses v2 for reads, v1/sync for writes (per working implementations)
actor PaprikaClient {
    private let baseURLv2 = URL(string: "https://www.paprikaapp.com/api/v2/")!
    private let baseURLv1Sync = URL(string: "https://www.paprikaapp.com/api/v1/sync/")!

    // Legacy alias for compatibility
    private var baseURL: URL { baseURLv2 }

    private var token: String?
    private var basicAuthHeader: String?  // For v1 API writes

    // Must identify as Paprika client with platform info
    private let userAgent = "Paprika Recipe Manager 3/3.7.4 (iOS 17.0; iPhone)"

    /// URLSession with configured timeouts (default: 30s request, 15s resource)
    let session: URLSession

    /// Default timeout for API requests (seconds)
    static let defaultTimeoutInterval: TimeInterval = 30

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = Self.defaultTimeoutInterval
            config.timeoutIntervalForResource = 60
            self.session = URLSession(configuration: config)
        }
    }

    init(keychain: KeychainService) {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = Self.defaultTimeoutInterval
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    /// Sets the authentication token (for session restoration from Keychain)
    /// Using nonisolated to allow calling from non-async context
    nonisolated func setToken(_ token: String) async {
        await setTokenInternal(token)
    }

    private func setTokenInternal(_ token: String) {
        self.token = token
    }

    /// Returns whether the client has a valid token set
    var hasToken: Bool {
        token != nil
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
        
        let (data, response) = try await session.data(for: request)
        
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

        // Also store Basic Auth for v1 API writes
        let credentials = "\(email):\(password)"
        if let credData = credentials.data(using: .utf8) {
            self.basicAuthHeader = "Basic \(credData.base64EncodedString())"
        }

        return token
    }
    
    // MARK: - Recipes

    /// Fetches all recipe stubs (uid + hash) for incremental sync
    /// Returns the full list with no limit — use hashes to determine which need detail fetching
    func fetchRecipeStubs() async throws -> [RecipeStub] {
        let listResponse: RecipesListResponse = try await syncRequest(endpoint: "sync/recipes/")
        print("📋 Found \(listResponse.result.count) recipe stubs")
        return listResponse.result
    }

    /// Fetches recipes (list first, then details for each)
    /// Limited to first 50 for performance — prefer RecipeSyncEngine for full sync
    @available(*, deprecated, message: "Use RecipeSyncEngine for full hash-based sync")
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
    
    // MARK: - Categories

    /// Fetches all categories from Paprika
    func fetchCategories() async throws -> [PaprikaCategory] {
        let response: CategoriesResponse = try await syncRequest(endpoint: "sync/categories/")
        print("📂 Found \(response.result.count) categories")
        return response.result
    }

    // MARK: - Meal Plans

    func fetchMealItems() async throws -> [PaprikaMealItem] {
        let response: MealItemsResponse = try await syncRequest(endpoint: "sync/menuitems/")
        return response.result
    }

    /// Fetches meals from v1 API (uses date field, different from menuitems)
    func fetchMeals() async throws -> [PaprikaMeal] {
        let response: MealsResponse = try await syncRequest(endpoint: "sync/meals/")
        return response.result
    }

    /// Save a recipe back to Paprika using v1 sync API with gzip compression.
    /// Used for writing back category changes (e.g., MP: Quick, MP: Kid-Friendly).
    func saveRecipe(_ recipe: PaprikaRecipe) async throws {
        guard let authHeader = basicAuthHeader else {
            throw PaprikaError.notAuthenticated
        }

        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(recipe)

        let gzippedData = try gzipCompress(jsonData)

        let boundary = UUID().uuidString
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"data\"; filename=\"data.gz\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(gzippedData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        let url = baseURLv1Sync.appendingPathComponent("recipe/\(recipe.uid)/")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.httpBody = body

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PaprikaError.invalidResponse
        }

        #if DEBUG
        if let responseStr = String(data: data, encoding: .utf8) {
            print("saveRecipe response (\(httpResponse.statusCode)): \(responseStr)")
        }
        #endif

        guard (200...299).contains(httpResponse.statusCode) else {
            throw PaprikaError.serverError(httpResponse.statusCode)
        }
    }

    /// Save meal items using v1 sync API with gzip compression
    /// This is the working approach discovered from paprika-mcp package
    func saveMeals(_ meals: [PaprikaMeal]) async throws {
        guard let authHeader = basicAuthHeader else {
            throw PaprikaError.notAuthenticated
        }

        // Encode meals as JSON array
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .formatted(paprikaDateFormatter)
        let jsonData = try encoder.encode(meals)

        #if DEBUG
        if let jsonStr = String(data: jsonData, encoding: .utf8) {
            print("📦 Meal JSON: \(jsonStr)")
        }
        #endif

        // Gzip compress the JSON (required by Paprika API)
        let gzippedData = try gzipCompress(jsonData)

        #if DEBUG
        print("📦 Gzip size: \(gzippedData.count), header: \(gzippedData.prefix(2).map { String(format: "%02X", $0) }.joined())")
        #endif

        // Build multipart form data with gzipped payload
        let boundary = UUID().uuidString
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"data\"; filename=\"data.gz\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(gzippedData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        // POST to v1 sync API
        let url = baseURLv1Sync.appendingPathComponent("meals/")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.httpBody = body

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PaprikaError.invalidResponse
        }

        #if DEBUG
        if let responseStr = String(data: data, encoding: .utf8) {
            print("saveMeals response (\(httpResponse.statusCode)): \(responseStr)")
        }
        #endif

        guard (200...299).contains(httpResponse.statusCode) else {
            throw PaprikaError.serverError(httpResponse.statusCode)
        }
    }

    /// Legacy single-item save (wraps saveMeals)
    func saveMealItem(_ item: PaprikaMealItem) async throws {
        // Convert to PaprikaMeal format
        let meal = PaprikaMeal(from: item)
        try await saveMeals([meal])
    }

    // Date formatter matching Paprika's format
    private var paprikaDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    /// Gzip compress data using proper RFC 1952 format
    private func gzipCompress(_ data: Data) throws -> Data {
        // Use raw DEFLATE compression
        guard let deflated = compressDeflate(data) else {
            throw PaprikaError.invalidResponse
        }

        var gzipData = Data()

        // Gzip header (10 bytes)
        gzipData.append(contentsOf: [
            0x1f, 0x8b,  // Magic number
            0x08,        // Compression method (deflate)
            0x00,        // Flags
            0x00, 0x00, 0x00, 0x00,  // Modification time
            0x00,        // Extra flags
            0x03         // OS (Unix)
        ])

        gzipData.append(deflated)

        // CRC32 of original data
        let crc = crc32(data)
        gzipData.append(contentsOf: withUnsafeBytes(of: crc.littleEndian) { Array($0) })

        // Original size mod 2^32
        let size = UInt32(truncatingIfNeeded: data.count)
        gzipData.append(contentsOf: withUnsafeBytes(of: size.littleEndian) { Array($0) })

        return gzipData
    }

    /// Raw DEFLATE compression
    private func compressDeflate(_ data: Data) -> Data? {
        let destBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: data.count + 512)
        defer { destBuffer.deallocate() }

        let compressedSize = data.withUnsafeBytes { srcBuffer -> Int in
            return compression_encode_buffer(
                destBuffer, data.count + 512,
                srcBuffer.baseAddress!.assumingMemoryBound(to: UInt8.self), data.count,
                nil,
                COMPRESSION_ZLIB
            )
        }

        guard compressedSize > 0 else { return nil }
        return Data(bytes: destBuffer, count: compressedSize)
    }

    /// CRC32 calculation for gzip footer
    private func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        let polynomial: UInt32 = 0xEDB88320

        for byte in data {
            var temp = crc ^ UInt32(byte)
            for _ in 0..<8 {
                if temp & 1 == 1 {
                    temp = (temp >> 1) ^ polynomial
                } else {
                    temp >>= 1
                }
            }
            crc = temp
        }

        return ~crc
    }

    /// Delete a meal by setting deleted=true and re-syncing
    func deleteMeal(_ meal: PaprikaMeal) async throws {
        var deletedMeal = meal
        deletedMeal.deleted = true
        try await saveMeals([deletedMeal])
    }

    /// Delete a meal by UID (fetches meal first, then marks deleted)
    func deleteMealByUid(_ uid: String) async throws {
        let meals = try await fetchMeals()
        guard let meal = meals.first(where: { $0.uid == uid }) else {
            return  // Already deleted or doesn't exist
        }
        try await deleteMeal(meal)
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
        
        let (data, response) = try await session.data(for: request)
        
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

        let (_, response) = try await session.data(for: request)

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

        let (_, response) = try await session.data(for: request)

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
