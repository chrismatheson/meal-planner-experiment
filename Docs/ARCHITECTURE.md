# Architecture

> *Maintained by: Architect*

## Overview

<!-- High-level description of the system architecture -->

```
┌─────────────────────────────────────────────────────────────┐
│                        App Layer                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │   Views     │  │   Views     │  │   Views     │         │
│  │  (SwiftUI)  │  │  (SwiftUI)  │  │  (SwiftUI)  │         │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘         │
│         │                │                │                 │
│  ┌──────┴──────┐  ┌──────┴──────┐  ┌──────┴──────┐         │
│  │ ViewModels  │  │ ViewModels  │  │ ViewModels  │         │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘         │
├─────────┼────────────────┼────────────────┼─────────────────┤
│         └────────────────┼────────────────┘                 │
│                   Domain Layer                              │
│         ┌────────────────┴────────────────┐                 │
│         │         Use Cases               │                 │
│         │       Domain Models             │                 │
│         └────────────────┬────────────────┘                 │
├──────────────────────────┼──────────────────────────────────┤
│                    Data Layer                               │
│         ┌────────────────┴────────────────┐                 │
│         │        Repositories             │                 │
│         └───────┬─────────────────┬───────┘                 │
│          ┌──────┴──────┐   ┌──────┴──────┐                  │
│          │   Local     │   │   Remote    │                  │
│          │ (SwiftData) │   │   (API)     │                  │
│          └─────────────┘   └─────────────┘                  │
└─────────────────────────────────────────────────────────────┘
```

## Tech Stack

| Layer | Technology | Rationale |
|-------|------------|-----------|
| UI | SwiftUI | Native, declarative, Apple's future |
| State | [TBD: @Observable / TCA] | [Rationale] |
| Persistence | SwiftData | Native, Swift-first ORM |
| Networking | URLSession + async/await | Native, sufficient |
| DI | Environment / Constructor | Simple, testable |

## Module Structure

```
Sources/
├── App/                    # App entry point, configuration
├── Features/               # Feature modules
│   ├── [Feature]/
│   │   ├── Views/
│   │   ├── ViewModels/
│   │   └── Models/
├── Core/                   # Shared business logic
│   ├── Domain/            # Domain models, use cases
│   └── Data/              # Repositories, data sources
├── Infrastructure/         # External interfaces
│   ├── Network/
│   ├── Persistence/
│   └── System/
└── DesignSystem/          # Reusable UI components
```

## Key Patterns

### State Management

<!-- Document the chosen state management approach -->

**Pattern**: [MVVM / TCA / MV]

**Rationale**: [Why this pattern]

```swift
// Example of the pattern
```

### Dependency Injection

**Approach**: [Constructor / Environment / Container]

```swift
// Example of DI approach
```

### Navigation

**Pattern**: [NavigationStack with typed destinations]

```swift
// Example of navigation pattern
```

## Architecture Decision Records

<!-- Link to ADRs or list key decisions -->

| ADR | Decision | Date |
|-----|----------|------|
| [ADR-001](ADR/001-state-management.md) | [Decision title] | YYYY-MM-DD |

## Constraints

### Technical Constraints
- Minimum iOS version: **[iOS X]**
- Swift version: **[X.X]**
- No third-party dependencies for: [areas]

### Non-Functional Requirements
- App launch: < **[X]** seconds
- Memory footprint: < **[X]** MB
- Offline support: **[Yes/No/Partial]**

## Future Considerations

<!-- Things to keep in mind for future architecture evolution -->

- [ ] [Future consideration 1]
- [ ] [Future consideration 2]
