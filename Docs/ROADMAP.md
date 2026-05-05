# Product Roadmap

> *Maintained by: Product Manager*
> *Last updated: 2026-05-05*

## Vision

**Autopilot for meal planning.** Generate a week of dinners from your Paprika library. You just steer.

---

## Current Focus

### 🎯 Now: v2.1 - Habit-Aware Generation

**Theme**: Proper sync foundation + pipeline-based generation with rules and preferences

See [v2.1 milestone](#-v21---habit-aware) for full details.

---

## Milestones

### 🚀 v1.0 - Full MVP ✅ COMPLETE

**Goal**: Generate a week of dinners, auto-sync to Paprika
**Status**: ✅ Complete — verified in Paprika app 2026-04-26

**Core Flow:**
```
Login → "Plan My Week" → Review 7 dinners → Regenerate any → Auto-sync (20s) → ✓ Synced
```

**Checklist:**
- [x] Paprika authentication
- [x] Fetch recipes from Paprika
- [x] Token persistence (stay logged in)
- [x] Recipe caching (offline generation)
- [x] Generate 7-day plan (random, no duplicates in week)
- [x] Review UI: 7 cards (day + recipe + photo)
- [x] Per-day "↻ Another" regenerate button
- [x] "↻ Regenerate All" in toolbar
- [x] 20s countdown timer with auto-sync
- [x] Tap countdown to sync immediately
- [x] Green checkmark on sync success
- [x] **VERIFIED**: Meals appear in Paprika app (2026-04-26)

**Scope:**
- Dinner only (one meal per day)
- Next 7 days (rolling, not calendar week)
- Random generation (no "smart" yet)
- Sync via Paprika v1 API with gzip compression

**Success Criteria**: Generate → tweak → synced in under 30 seconds

### 📈 v1.1 - Polish ✅ COMPLETE

**Goal**: Refinements based on real usage

- [x] Image caching (200MB disk cache, shimmer loading, retry on failure)
- [x] Sync status visibility (SyncStatusManager, pull-to-reveal)
- [x] Skeleton loading screens (WeekPlanSkeletonView)
- [x] Recipe photo tap → RecipeDetailView with ingredients/directions
- [x] "Undo" last regeneration (single-level undo, clears after sync)
- [x] Accessibility audit (VoiceOver labels, hints, combined elements)
- [x] Sync UI redesign (minimal status dot, popover details, Settings integration)

### 📶 v1.2 - Offline Support ✅ COMPLETE

**Goal**: Reliable offline experience with stale-while-refresh pattern

- [x] Persistent image cache (200MB disk URLCache, survives app restart)
- [x] Stale-while-refresh for recipes (show cache immediately, refresh in background)
- [x] Stale-while-refresh for meals (same pattern)
- [x] Staleness indicator (StalenessIndicator component, shows "Synced Xm ago")
- [x] Offline-first auth (skip login when offline if cached data exists)
- [ ] Offline sync queue (queue changes, sync when back online) [deferred to v2.1]

**Pattern**: Always show cached data first → fetch fresh in background → update UI when ready

### 🌟 v2.0 - Smarter Generation ✅ COMPLETE

**Goal**: Generation that learns from rejections and respects variety

#### Shipped
- [x] Session rejection tracking (RejectionTracker with 1-hour expiry)
- [x] Recent history exclusion (14-day CachedMealModel query)
- [x] Regenerate with context (exclusions passed to WeekPlan)
- [x] Rejections visible in Settings
- [x] **Cuisine diversity** (max 2 same cuisine per week, soft constraint)

**Technical Approach**:
- RejectionTracker: UserDefaults-persisted, 1-hour auto-expiry (to be replaced by fatigue scoring in v2.1)
- History query: CachedMealModel last 14 days
- CuisineType: Category keyword matching for cuisine detection

### 🔮 v2.1 - Habit-Aware

**Goal**: Proper sync foundation + pipeline-based generation with rules, preferences, and richer metadata

**Architecture Decision**: Generation uses a **pipeline of stages** — each feature is a filter or scoring stage applied sequentially. Hard rules (user-configured) act as filters; soft preferences act as score multipliers. This keeps the system simple, testable, and extensible without over-engineering a generic rules engine. The dataset (~100-300 recipes, ~10-20 rules) is small enough that filtering and scoring in-memory is effectively instant.

#### Foundation: Proper Sync Layer
The current sync is a fetch-what-you-need pattern capped at 50 recipes. v2.1 needs a full local mirror of the Paprika account to power the scoring pipeline across the entire recipe library.

- [ ] **Full recipe sync** — remove 50-recipe cap. Use hash-based incremental sync: fetch all `{ uid, hash }` stubs, compare to local cache, only fetch changed/new recipes. Initial sync may take ~1 min for large libraries; incremental syncs near-instant.
- [ ] **Categories sync** — fetch from `sync/categories/` endpoint (currently unused). Needed for slot-pinning by category, metadata inference ("Glow Up"), and recipe pack category mapping.
- [ ] **Offline sync queue** — queue changes made while offline, sync when connectivity returns. (Deferred from v1.2)
- [ ] **Background refresh** — periodic sync when app is active, respecting stale-while-refresh pattern

#### Hard Rules (Filters)
- [ ] **Slot-pinning** — assign a specific recipe or category to a day-of-week (e.g., "Takeaway Friday", "Sunday Roast")

#### Soft Preferences (Scoring)
- [ ] **Recipe fatigue with exponential backoff** — replaces both "Hide for a while" and the v2.0 RejectionTracker (1-hour expiry). Every negative signal (rejection, explicit hide, "didn't make it") adds to a fatigue score with exponential compounding. Score decays naturally over time, so recipes always drift back into rotation.
  - Data model: `RecipeFatigue { recipeId, score, lastUpdated }`
  - Exponential bumps: 1st rejection +1, 2nd +2, 3rd +4, 4th +8
  - Linear decay: ~0.1/day (score 1 ≈ 10 days, score 7 ≈ 70 days, score 15 ≈ 5 months)
  - Fatigue is **day-agnostic** — rejection on any day penalises across all days
  - Unifies session rejections, explicit hides, and future "didn't make it" into one scoring mechanism
  - User never sees the score — app just "learns"
  - **Migration**: v2.0 RejectionTracker is retired; session rejections become the first bump (+1) in fatigue score
- [ ] **Recipe metadata** — two dimensions for v2.1:
  - **Effort level** (quick / normal / elaborate) — inferred from Paprika `prep_time` + `cook_time` fields and ingredient count. Quick ≤ 30 min or ≤ 5 ingredients. Elaborate > 60 min or > 15 ingredients.
  - **Kid-friendly** (yes / no / unset) — user-tagged only, too subjective to infer
  - Infer first, user can override. Override model: `RecipeMetadataOverride { recipeId, effortLevel, isKidFriendly }` trumps inferred values
- [ ] **Weeknight vs weekend awareness** — prefer quick/easy recipes Mon-Thu, allow elaborate recipes Fri-Sun. Depends on effort-level metadata being populated.
- [ ] **Protein variety** — ingredient parsing to detect primary protein (chicken, beef, fish, pork, veggie). Max 2 of same protein per week, same pattern as existing cuisine diversity. (Deferred from v2.0)
- [ ] **Variety score indicator** — visual signal of how varied the current plan is (deferred from v2.0)

### 🔮 v3.0+ Vision

- [ ] **Apple TV companion** — kids involved in meal selection on the big screen, no personal devices
- [ ] **Shared rule packs via CloudKit** — public database of community-curated rule/preference packs (food holiday calendars, cultural/religious meal patterns, seasonal preferences, diet templates). No iCloud sign-in required for reads. Seeded from curated content, user submissions with moderation.
- [ ] **Food holiday awareness** — bundled JSON calendar of food-related national days ("National Pie Day", "Fish & Chip Week"). Boosts matching recipes as a soft preference, with optional badge on day cards. Matching via keyword/category against user's library.
- [ ] Breakfast / lunch support
- [ ] Family voting on suggestions
- [ ] Siri: "What's for dinner tonight?"

---

## Prioritization Framework

### Priority Definitions

| Priority | Definition | SLA |
|----------|------------|-----|
| **P0** | Critical - blocks launch or major functionality | Immediate |
| **P1** | High - significant user value | This sprint |
| **P2** | Medium - nice to have | Next sprint |
| **P3** | Low - someday/maybe | Backlog |

### Effort Estimates

| Size | Definition | Typical Duration |
|------|------------|------------------|
| **XS** | Trivial change | < 1 day |
| **S** | Small feature | 1-2 days |
| **M** | Medium feature | 3-5 days |
| **L** | Large feature | 1-2 weeks |
| **XL** | Epic | > 2 weeks (break down!) |

### Prioritization Matrix

```
                    High Impact
                         │
         Quick Wins      │      Big Bets
         (Do First)      │      (Plan Carefully)
                         │
    Low ─────────────────┼───────────────── High
    Effort               │                  Effort
                         │
         Fill-ins        │      Money Pits
         (If Time)       │      (Avoid)
                         │
                    Low Impact
```

---

## Feature Requests & Ideas

### Under Consideration

| Idea | Notes | Status |
|------|-------|--------|
| **"Glow Up Your Recipes"** | MealPlanner analyses your Paprika library and enriches metadata — infers cuisine, effort level, protein type, allergens from existing recipe data. Batch approval UX: "We think these 6 are Quick Weeknight meals — agree?" Enriched data syncs back to Paprika categories. Levels up user recipes to match imported pack quality. Prerequisite for scoring pipeline to work well on user's own recipes. **Important**: manual tagging is against the core value prop ("autopilot") — the app does the analysis, user only steers via approval/correction. **Technical approach**: Apple Intelligence Foundation Models framework (iOS 26+) for on-device LLM inference — zero ops burn, zero API cost, no privacy concerns, no network dependency. Feed recipe title + ingredients + times to on-device model, get structured metadata back (cuisine, effort, protein, kid-friendly, allergens, season). Falls back to keyword heuristics on devices without Apple Intelligence (pre-A17 Pro). Runs in background after sync across full library. | Exploring |
| **Curated recipe packs** | Browse and install themed recipe collections from curated external sources (Gousto first) into Paprika. Recipes transformed into Paprika schema, tagged with source category to separate from user's own recipes. Imported recipes carry rich metadata (cuisine, prep time, allergens, nutrition) which improves generation quality. Packs hosted on CloudKit public database. De-duplication by source URL on sync. | Exploring |
| **"We didn't make this" feedback** | After the plan week passes, user can mark meals they skipped. Feeds into fatigue score (smaller bump than explicit rejection, e.g., +0.5). Noisy signal — user may have skipped for reasons unrelated to the recipe. Needs UX design for when/how to prompt without adding friction. | Exploring |

### Parked (not seeing benefit yet)

| Idea | Notes | Revisit When |
|------|-------|--------------|
| Grocery list generation | Paprika already does this reasonably well | If users request |
| Nutrition tracking | Adds complexity, unclear user need | After v2.0 feedback |
| iOS Widgets | Nice-to-have, not core value prop | v2.0+ polish phase |
| Apple Watch | Limited screen, unclear use case vs phone | After tvOS validated |

### Declined (with rationale)

| Idea | Reason |
|------|--------|
| - | - |

---

## Dependencies & Risks

### External Dependencies

| Dependency | Impact | Mitigation |
|------------|--------|------------|
| Paprika sync API (reverse-engineered) | Core functionality — all reads and writes depend on it | Monitor API behaviour, version-pin User-Agent string, graceful degradation if endpoints change |
| CloudKit (v3.0) | Shared rule packs and recipe packs | Only needed for v3.0 features; core app works without it |
| Gousto API/data (v3.0) | Recipe pack content | Curated manually; no runtime dependency on Gousto API |

### Risks to Timeline

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Paprika changes or removes sync API | Medium | High | App is offline-first with full local cache; would degrade gracefully to read-only cached mode |
| Full recipe sync performance for large libraries | Medium | Medium | Hash-based incremental sync; initial sync is one-time cost; progress UI |
| Recipe metadata inference accuracy | Medium | Low | Inference is best-effort with user override; incorrect inferences don't break generation, just reduce quality |
| RejectionTracker → fatigue migration | Low | Medium | Both systems can coexist during transition; fatigue is additive |

---

## Revision History

| Date | Changes |
|------|---------|
| 2026-05-05 | **v2.1 overhaul**: Added proper sync layer (full recipe sync, categories, offline queue) as foundation. Pipeline architecture over rules engine. Slot-pinning as first hard rule. Recipe fatigue with exponential backoff replacing both "hide for a while" and RejectionTracker. Fleshed out recipe metadata (2 dimensions, infer + override), weeknight/weekend awareness, protein variety. Added "Glow Up Your Recipes" and curated recipe packs to Under Consideration. Shared rule packs via CloudKit and food holiday awareness added to v3.0. Updated status markers (v1.0-v2.0 all complete). Populated Dependencies & Risks with real entries. |
| 2026-04-17 | **Major pivot**: Generate-first vision. Cut manual assignment UI. User steers via regenerate. |
| 2026-04-17 | PO review: offline added to v1.0, v2.0 split into simple/smart phases, parked grocery/nutrition/widgets |
| 2026-04-17 | Updated with actual MVP status, PO priorities, long-term vision |
| YYYY-MM-DD | Initial roadmap template |
