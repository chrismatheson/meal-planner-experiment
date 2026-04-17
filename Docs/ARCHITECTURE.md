# Architecture

> *Maintained by: Architect Agent*
> *Last Updated: 2026-04-17*

## Overview

MealPlanner is an **offline-first** iOS app that syncs with Paprika Recipe Manager's cloud service. Users can plan meals locally with instant feedback, while sync happens in the background.

```
┌─────────────────────────────────────────────────────────────┐
│                     Presentation Layer                       │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │  AuthView   │  │ RecipesView │  │ MealPlanView│          │
│  │  + ViewModel│  │  + ViewModel│  │  + ViewModel│          │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘          │
├─────────┴────────────────┴────────────────┴─────────────────┤
│                      Domain Layer                            │
│  ┌────────────────┐  ┌────────────────┐  ┌───────────────┐  │
│  │ RecipeRepository│  │MealPlanRepository│ │SyncCoordinator│ │
│  └───────┬────────┘  └───────┬────────┘  └───────┬───────┘  │
├──────────┴───────────────────┴───────────────────┴──────────┤
│                   Infrastructure Layer                       │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │ SwiftData   │  │PaprikaClient│  │ KeychainService     │  │
│  │ (Local DB)  │  │ (Network)   │  │ (Secure Storage)    │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Tech Stack

| Layer | Technology | Rationale |
|-------|------------|-----------|
| **UI** | SwiftUI | Native, declarative, Apple's direction |
| **State** | `@Observable` (iOS 17+) | Simpler than ObservableObject, less boilerplate |
| **Persistence** | SwiftData | Native Swift ORM, automatic SwiftUI observation |
| **Networking** | URLSession + async/await | Native, full control over gzip encoding |
| **Compression** | Foundation + zlib | Paprika API requires gzip-compressed bodies |
| **Security** | Keychain Services | Secure JWT token and credential storage |
| **DI** | Environment + Constructor | Simple, testable, SwiftUI-native |

## Module Structure

```
MealPlanner/
├── MealPlannerApp.swift        # Entry point
├── App/
│   ├── AppState.swift          # Global app state
│   ├── AppCoordinator.swift    # Navigation coordination
│   └── DependencyContainer.swift
│
├── Features/
│   ├── Auth/
│   │   ├── LoginView.swift
│   │   ├── LoginViewModel.swift
│   │   └── AuthService.swift
│   │
│   ├── Recipes/
│   │   ├── RecipeListView.swift
│   │   ├── RecipeListViewModel.swift
│   │   ├── RecipeDetailView.swift
│   │   └── RecipeCard.swift
│   │
│   └── MealPlan/
│       ├── MealPlanView.swift
│       ├── MealPlanViewModel.swift
│       ├── DayColumn.swift
│       ├── RecipePicker.swift
│       └── SwipeActions.swift
│
├── Core/
│   ├── Domain/
│   │   ├── Models/
│   │   │   ├── Recipe.swift
│   │   │   ├── MealPlan.swift
│   │   │   └── MealSlot.swift
│   │   └── Repositories/
│   │       ├── RecipeRepository.swift
│   │       └── MealPlanRepository.swift
│   │
│   └── Sync/
│       ├── SyncCoordinator.swift
│       ├── SyncQueue.swift
│       └── ConflictResolver.swift
│
├── Infrastructure/
│   ├── Network/
│   │   ├── PaprikaClient.swift
│   │   ├── PaprikaEndpoints.swift
│   │   ├── GzipCoding.swift
│   │   └── NetworkError.swift
│   │
│   ├── Persistence/
│   │   ├── SwiftDataModels.swift
│   │   └── ModelContainer+App.swift
│   │
│   └── Security/
│       └── KeychainService.swift
│
└── DesignSystem/
    ├── Theme.swift
    ├── PaprikaColors.swift
    └── Components/
        ├── RecipeCardView.swift
        └── LoadingView.swift
```

## Key Patterns

### State Management: MVVM with @Observable

```swift
@Observable
final class MealPlanViewModel {
    var mealPlan: MealPlan?
    var isLoading = false
    var error: Error?

    private let repository: MealPlanRepository

    init(repository: MealPlanRepository) {
        self.repository = repository
    }

    func loadCurrentWeek() async {
        isLoading = true
        defer { isLoading = false }

        do {
            mealPlan = try await repository.getCurrentWeek()
        } catch {
            self.error = error
        }
    }

    func assignRecipe(_ recipe: Recipe, to date: Date) async {
        // Optimistic update
        mealPlan?.assign(recipe, to: date)

        // Background sync
        try? await repository.save(mealPlan!)
    }
}
```

### API Client: PaprikaClient

```swift
actor PaprikaClient {
    private let baseURL = URL(string: "https://www.paprikaapp.com/api/v2/")!
    private let keychain: KeychainService
    private var token: String?

    func login(email: String, password: String) async throws -> String {
        let endpoint = baseURL.appendingPathComponent("account/login/")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"

        // Multipart form data
        let body = MultipartFormData()
        body.append(email, forKey: "email")
        body.append(password, forKey: "password")
        request.httpBody = body.encoded()
        request.setValue(body.contentType, forHTTPHeaderField: "Content-Type")

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(LoginResponse.self, from: data)

        self.token = response.result.token
        try keychain.save(token: response.result.token)

        return response.result.token
    }

    func fetchRecipes() async throws -> [Recipe] {
        try await syncRequest(endpoint: "sync/recipes/")
    }

    func fetchMealItems() async throws -> [MealItem] {
        try await syncRequest(endpoint: "sync/menuitems/")
    }

    private func syncRequest<T: Decodable>(endpoint: String) async throws -> T {
        var request = URLRequest(url: baseURL.appendingPathComponent(endpoint))
        request.httpMethod = "POST"
        request.setValue("Bearer \(token ?? "")", forHTTPHeaderField: "Authorization")
        request.setValue("gzip", forHTTPHeaderField: "Content-Encoding")

        // Gzip-compressed empty JSON body for sync requests
        request.httpBody = try "{}".data(using: .utf8)?.gzipped()

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(T.self, from: data)
    }
}
```

### Offline-First Data Flow

```
┌──────────────────────────────────────────────────────────────┐
│                        USER ACTION                            │
│                    (assign recipe to day)                     │
└──────────────────────────┬───────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────────┐
│               1. OPTIMISTIC LOCAL UPDATE                      │
│         SwiftData model updated immediately                   │
│              UI reflects change instantly                     │
└──────────────────────────┬───────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────────┐
│                 2. QUEUE SYNC OPERATION                       │
│        Change added to SyncQueue (persisted)                  │
└──────────────────────────┬───────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────────┐
│              3. BACKGROUND SYNC (when online)                 │
│         SyncCoordinator pushes to Paprika API                 │
│              Handles retries, conflicts                       │
└──────────────────────────────────────────────────────────────┘
```

## Architecture Decision Records

| ADR | Decision | Rationale |
|-----|----------|-----------|
| **ADR-001** | MVVM over TCA | Lower learning curve, Apple-native patterns, sufficient for MVP scope |
| **ADR-002** | SwiftData over Core Data | Swift-native macros, automatic SwiftUI observation, less boilerplate |
| **ADR-003** | Offline-First Sync | Users need offline access; optimistic updates feel fast and responsive |
| **ADR-004** | Native URLSession | Zero dependencies, async/await is clean, full control over gzip encoding |
| **ADR-005** | iOS 17+ minimum | Enables @Observable, latest SwiftUI features, SwiftData |

## Constraints

### Technical Constraints
- **Minimum iOS version**: iOS 17.0
- **Swift version**: 5.9+
- **No third-party dependencies** for: Networking, persistence, UI
- **Xcode**: 15.0+

### Non-Functional Requirements
- **App launch**: < 2 seconds to interactive
- **Offline support**: Full - all features work offline
- **Sync latency**: < 5 seconds when online
- **Memory footprint**: < 100MB typical usage

## Security Considerations

- JWT tokens stored in **Keychain only** (never UserDefaults)
- Credentials never logged or stored in plain text
- All network traffic over HTTPS (enforced by ATS)
- Token refresh on 401 responses

## Future Considerations

- [ ] Widget for Today's meals (WidgetKit)
- [ ] Siri Shortcuts integration
- [ ] Apple Watch companion
- [ ] iCloud sync for app preferences
- [ ] Share meal plans with family members
