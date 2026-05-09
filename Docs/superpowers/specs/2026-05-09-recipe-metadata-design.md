# Recipe Metadata: Effort Level & Kid-Friendly

> **Status**: Design
> **Date**: 2026-05-09
> **Scope**: Inference engine, override model, batch review UI, Paprika category write-back

## Problem

The generation pipeline treats all recipes as interchangeable. A 2-hour beef wellington and a 15-minute stir fry are equally likely on a Tuesday night. Users have no way to indicate which recipes are kid-friendly. Without metadata, weeknight/weekend awareness and future scoring rules have nothing to work with.

## Solution

Three layers, built incrementally:

1. **Inference engine** — auto-classify recipes from existing Paprika data
2. **Override model** — persist user corrections, track provenance
3. **UI + Paprika sync** — batch review flow, per-recipe editing, lazy category write-back

## Data Model

### EffortLevel (enum)

```
quick     — totalTime ≤ 30 min OR ingredientCount ≤ 5
normal    — everything else (default)
elaborate — totalTime > 60 min OR ingredientCount > 15
```

When both time and ingredient count are available, time wins (a slow cooker recipe with 15 ingredients but 20 min prep is still quick-effort from the cook's perspective). When neither time nor ingredients are parseable, defaults to `normal`.

### TimeParser (pure function)

Parses Paprika freeform time strings to minutes. Must handle:
- `"30 min"`, `"30 minutes"`, `"30 mins"`
- `"1 hour"`, `"1 hr"`, `"1 hr 15 min"`
- `"1:30"` (hours:minutes)
- `"90"` (bare number = minutes)
- Returns `nil` for unparseable strings

### Ingredient count (pure function)

Splits `RecipeModel.ingredients` on newlines, filters blank lines. Returns count.

### RecipeMetadataOverride (SwiftData @Model)

```swift
@Model
final class RecipeMetadataOverride {
    @Attribute(.unique) var recipeUid: String
    var effortLevel: String?        // "quick" | "normal" | "elaborate" | nil
    var isKidFriendly: Bool?        // true | false | nil (unset)
    var source: String              // "inferred" | "confirmed" | "manual"
    var needsSync: Bool             // true if Paprika categories need updating
    var lastModified: Date
}
```

**Source semantics:**
- `inferred` — auto-set by inference engine. Re-inference can overwrite.
- `confirmed` — user approved the inferred value in batch review. Re-inference does NOT overwrite.
- `manual` — user explicitly changed the value. Re-inference does NOT overwrite.

### Resolver (pure function)

```
effectiveEffortLevel(recipe, override?) -> EffortLevel
  if override?.effortLevel != nil → return override value
  else → return inferred from recipe times/ingredients

effectiveKidFriendly(recipe, override?) -> Bool?
  return override?.isKidFriendly  // nil = unset (no inference for kid-friendly)
```

## Inference Lifecycle

### Threading
All inference runs **off the main thread** as a background `Task`. The inference engine is pure computation (time parsing, ingredient counting, threshold checks) with no UI dependency. Results are written to SwiftData on a background `ModelContext` and merged automatically.

### Batching
Inference processes recipes in batches of **25** — a human-comprehensible number that maps well to progress reporting ("Analysed 25 of 180 recipes") and keeps each batch fast enough (~ms) that partial progress is visible. Between batches, yield to avoid starving other work. The batch review prompt only fires once all batches complete.

### Triggers
1. **After recipe sync** — sync engine calls `MetadataInferenceEngine.runInBackground(context:)`. This fetches all recipes without a `confirmed` or `manual` override, batches them in groups of 25, infers effort level for each, and creates/updates `RecipeMetadataOverride` with `source: "inferred"`.
2. **On recipe data change** — if a synced recipe's hash changed (meaning `prepTime`/`cookTime`/`ingredients` may have changed), that recipe is included in the next inference pass. Only overwrites if existing override source is `"inferred"`.
3. **Batch review** — user confirms or changes. Source becomes `"confirmed"` or `"manual"`. `needsSync = true`.
4. **Per-recipe edit** — user taps metadata pill on recipe detail. Source becomes `"manual"`. `needsSync = true`.

## Batch Review UX

### Trigger
After recipe sync completes, if there are unreviewed recipes (overrides with `source: "inferred"`), show a non-blocking prompt: **"We analysed N new recipes — review effort levels now?"** with **"Review"** and **"Later"** buttons.

### Deferral & re-entry
- Dismissing stores nothing — the unreviewed count persists.
- Entry points for resuming:
  - **Recipes tab**: banner at top when unreviewed count > 0: "N recipes to review"
  - **Settings**: "Recipe Metadata" row showing unreviewed count badge

### Review flow (sheet)
- Card stack or scrollable list. Each card shows: recipe photo, name, inferred effort pill, kid-friendly toggle.
- User taps effort pill to cycle: Quick → Normal → Elaborate (or confirm inferred).
- User toggles kid-friendly on/off (default: off/unset).
- "Skip" button to leave as inferred without confirming.
- "Done for now" saves progress, remaining recipes stay unreviewed.
- Progress bar at top: "12 of 47 reviewed".

### Grouping
Present recipes grouped by inferred effort level: "These look Quick", "These look Elaborate". User confirms or corrects per-recipe within the group. This is faster than random order.

## Paprika Category Write-Back

### Permission gate
On first launch after feature ships (or when user enables in Settings), prompt: **"MealPlanner can tag your recipes in Paprika with effort levels and kid-friendly markers. This adds categories like 'MP: Quick' to your Paprika recipes. Allow?"**

- **Allow** — enable write-back, set `paprikaCategoryWriteBack = true` in UserDefaults.
- **Not Now** — disable, can enable later in Settings.
- Revocable in Settings at any time. Revoking does NOT remove existing categories from Paprika (too destructive).

### Category naming
Prefixed to avoid polluting user's category namespace:
- `MP: Quick`, `MP: Normal`, `MP: Elaborate`
- `MP: Kid-Friendly`

### Sync mechanism
Piggybacks on existing meal sync. After meal plan sync completes, if `paprikaCategoryWriteBack == true`:
1. Fetch overrides where `needsSync == true`
2. For each, read recipe's current categories from local cache
3. Remove any existing `MP:` prefixed categories
4. Add the current metadata categories
5. Write updated recipe categories via Paprika API
6. Set `needsSync = false`

This is lazy — no separate sync trigger, no batch API call. A few recipes per sync cycle. If the user has 200 recipes to tag initially, they'll trickle out over several sync cycles, which is fine.

### Failure handling
If a category write fails, `needsSync` stays `true`, retried on next sync. No user-facing error for individual failures — just a Settings indicator: "3 recipes pending sync".

## Integration with Generation Pipeline

### Immediate use (Layer 1 alone)
`PlanGenerator.pickRecipe()` gains an optional `effortPreference: EffortLevel?` parameter. When set, recipes matching that effort level are preferred (scored higher), not hard-filtered. This means a "quick" preference on Tuesday still falls back to "normal" if the quick pool is exhausted.

### Weeknight/weekend awareness (Layer 1 + time context)
The generation pipeline checks the day-of-week for each slot:
- Mon–Thu: prefer `quick`, deprioritise `elaborate`
- Fri–Sun: no preference (all effort levels equal)

This is a soft preference (scoring multiplier), not a hard filter. Users with small libraries won't get empty days.

### Kid-friendly filtering (Layer 2 required)
When a user has tagged recipes as kid-friendly, the generator can offer a "Kid-friendly week" mode or a per-day toggle. This is a future enhancement — the data model supports it now, but the generation UI doesn't need it for v2.1.

## Schema & Migration

`RecipeMetadataOverride` added to the schema in `MealPlannerApp.init()`. SwiftData handles lightweight migration automatically for new models. No changes to `RecipeModel` — effort level is computed (inference) or resolved (override lookup).

## Testing Strategy

### Unit tests (TDD)
- `TimeParser`: all format variations, edge cases (nil, empty, garbage)
- `IngredientCounter`: newline splitting, blank line filtering, nil input
- `EffortLevelInference`: threshold boundaries, time-wins-over-ingredients rule, missing data defaults
- `MetadataResolver`: override trumps inferred, source semantics (inferred/confirmed/manual), nil handling
- `RecipeMetadataOverride` CRUD: create, update, needsSync flag

### Integration tests
- Inference runs after recipe sync, creates overrides
- Batch review updates source from inferred → confirmed
- Paprika write-back adds/removes MP: categories correctly

## Files to create/modify

### New files
- `MealPlanner/Infrastructure/Metadata/EffortLevel.swift` — enum, TimeParser, IngredientCounter, inference
- `MealPlanner/Infrastructure/Metadata/MetadataResolver.swift` — resolver, override lookup
- `MealPlanner/Infrastructure/Persistence/RecipeMetadataOverride.swift` — SwiftData model
- `MealPlanner/Features/Metadata/BatchReviewView.swift` — batch review sheet
- `MealPlanner/Features/Metadata/BatchReviewViewModel.swift` — review logic, progress tracking
- `MealPlannerTests/MetadataTests.swift` — all unit tests

### Modified files
- `MealPlannerApp.swift` — add `RecipeMetadataOverride` to schema
- `RecipeSyncEngine.swift` — trigger inference after sync
- `PlanGenerator.swift` — effort preference parameter
- `RecipeDetailView.swift` — metadata pill display + edit
- `PlanGenerationViewModel.swift` — weeknight/weekend logic
- Settings view — metadata section, Paprika write-back toggle, unreviewed count