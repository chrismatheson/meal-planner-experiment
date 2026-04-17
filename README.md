# MealPlanner

A companion iOS app for [Paprika Recipe Manager 3](https://www.paprikaapp.com/) focused on quick, gesture-driven meal planning.

## Features (MVP)

- 🔐 **Sign in with Paprika** - Use your existing Paprika sync credentials
- 📚 **View Recipe Library** - Browse all your Paprika recipes
- 📅 **Weekly Meal Planning** - Assign recipes to days at a glance
- 👆 **Swipe to Replace** - Quick gesture to swap recipes
- 🔄 **Sync to Paprika** - Plans sync back to your Paprika app

## Requirements

- iOS 17.0+
- Xcode 15.0+
- A Paprika Recipe Manager 3 account with sync enabled

## Getting Started

### Option 1: Open in Xcode

1. Open the project folder in Xcode (File → Open → select folder)
2. Xcode will generate a project from the Swift files
3. Select a simulator or device
4. Build and run (⌘R)

### Option 2: Use XcodeGen (recommended)

If you have XcodeGen installed:

```bash
xcodegen generate
open MealPlanner.xcodeproj
```

### Option 3: Create Xcode Project Manually

1. Open Xcode
2. File → New → Project → iOS App
3. Name: MealPlanner
4. Interface: SwiftUI
5. Language: Swift
6. Add existing files from `MealPlanner/` folder

## Project Structure

```
MealPlanner/
├── App/                    # App entry, state, navigation
├── Features/
│   ├── Auth/               # Login flow
│   ├── Recipes/            # Recipe list and cards
│   └── MealPlan/           # Weekly planning view
├── Core/                   # Domain models
├── Infrastructure/
│   ├── Network/            # Paprika API client
│   ├── Persistence/        # SwiftData models
│   └── Security/           # Keychain service
└── DesignSystem/           # Theme, colors, components
```

## Architecture

- **Pattern**: MVVM with @Observable (iOS 17+)
- **Persistence**: SwiftData for offline-first caching
- **Networking**: Native URLSession with async/await
- **State**: Environment-based dependency injection

## Documentation

See `Docs/` for detailed documentation:

- [Vision](Docs/VISION.md) - Product vision and scope
- [Architecture](Docs/ARCHITECTURE.md) - Technical architecture
- [Features](Docs/Features/MVP_FEATURES.md) - Feature specifications
- [Design System](Docs/DESIGN_SYSTEM.md) - UI/UX guidelines

## Development

This project uses an agent-based development approach. See `Agents/` for:

- Product Manager - Feature specs and priorities
- Architect - Technical decisions
- Developer - Implementation guidelines
- QA - Testing strategies
- Security - Security requirements
- Designer - UI/UX standards

## License

Private project - not for redistribution.

## Acknowledgments

- [Paprika Recipe Manager](https://www.paprikaapp.com/) - The amazing recipe app this companion enhances
- [kappari](https://github.com/johnwbyrd/kappari) - API documentation reference
