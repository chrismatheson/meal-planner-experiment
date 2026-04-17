# Development Handover - v1.0 Generate-First MVP

> Created: 2026-04-17
> Status: Ready to resume
> **⚠️ MAJOR PIVOT**: Generate-first, not manual assignment

## Context

**What's built:**
- ✅ Login with Paprika credentials
- ✅ Recipe fetching from Paprika API
- ✅ ATS configured for S3 images

**What's changed:**
- ❌ Recipe grid UI - **CUT** (user doesn't browse)
- ❌ Manual assignment - **CUT** (app generates)
- ❌ Drag-drop gestures - **CUT** (not needed)

## New v1.0 Flow

```
Login → "Plan My Week" → Review 7 dinners → Regenerate any → Accept → Synced
```

**User never picks recipes. App generates. User just says "not that one, try again."**

## Next Development Tasks (P0)

### 1. Plan Generator

**Goal**: Generate 7 random dinners from recipe library

**Logic:**
- Pull all recipes from cache/API
- Randomly select 7, no duplicates
- Track rejected recipes (excluded from future picks this session)

**New file**: `MealPlanner/Features/PlanGenerator/PlanGenerator.swift`

```swift
class PlanGenerator {
    func generateWeek(from recipes: [RecipeModel], excluding: Set<String>) -> [DayPlan]
    func regenerateDay(day: Int, from recipes: [RecipeModel], excluding: Set<String>) -> DayPlan
}

struct DayPlan {
    let date: Date
    let recipe: RecipeModel
}
```

### 2. Generate Screen

**Goal**: Single button "Plan My Week"

**New file**: `MealPlanner/Features/Generate/GenerateView.swift`

### 3. Review Week Screen

**Goal**: Show 7 days, allow regeneration

**UI:**
- 7 cards (day name + recipe name + photo)
- "↻ Another" button per card
- "↻ Regenerate All" at top
- "Use This Plan" at bottom

**New file**: `MealPlanner/Features/Review/ReviewWeekView.swift`

### 4. Sync Plan to Paprika

**Goal**: Write the 7 meals back to Paprika

**Technical:**
- Research Paprika API for meal plan write
- Likely `POST /api/v2/sync/meals/`
- Send on "Use This Plan" tap

### 5. Token Persistence + Recipe Caching

**Goal**: Offline generation works

**Approach:**
- Keychain for token (existing `KeychainService.swift`)
- SwiftData for recipes (existing `RecipeModel`)
- On launch: load cached, generate from cache if offline

## Test Credentials

```
Email: blackhole@mailinator.com
Password: cessuh-xawtig-xIbpa2
```

## Key Files to Create

| File | Purpose |
|------|---------|
| `PlanGenerator.swift` | Generation logic |
| `GenerateView.swift` | "Plan My Week" button |
| `ReviewWeekView.swift` | 7-day review with regenerate |
| `DayPlanCard.swift` | Single day card component |

## Key Files to Modify

| File | Change |
|------|--------|
| `RootView.swift` | New navigation flow |
| `PaprikaClient.swift` | Add meal write endpoint |
| `AppState.swift` | Track generated plan, rejections |

## What to Delete (optional cleanup)

These were built for manual assignment flow:
- `RecipeListView.swift` - recipe grid (not needed)
- `RecipePickerView.swift` - picker (not needed)
- `MealPlanView.swift` - old week view (replacing)

## Testing Requirements

- Write failing test FIRST
- Test generator produces 7 unique recipes
- Test excluded recipes don't reappear
- Integration test for sync to Paprika

## Resume Command

```
Acting as the Developer agent, implement the Plan Generator following
Docs/HANDOVER_DEV.md. Start with PlanGenerator.swift and write tests first.
```
