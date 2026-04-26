# Product Roadmap

> *Maintained by: Product Manager*
> *Last updated: 2026-04-25*

## Vision

**Autopilot for meal planning.** Generate a week of dinners from your Paprika library. You just steer.

---

## Current Focus

### 🎯 Now: v1.0 MVP - Generate & Sync

**Theme**: App generates the plan, user reviews, auto-syncs to Paprika

| Feature | Status | Priority | Notes |
|---------|--------|----------|-------|
| Paprika login | 🟢 Complete | - | Working with multipart form auth |
| Recipe fetching | 🟢 Complete | - | Can pull from Paprika |
| Token persistence | 🟢 Complete | - | Stay logged in across app restarts |
| Recipe caching | 🟢 Complete | - | Offline generation works |
| **"Plan My Week" generation** | 🟢 Complete | - | Random, no duplicates in week |
| **Review week UI** | 🟢 Complete | - | 7 cards with photo, regenerate per-day |
| **20s countdown auto-sync** | 🟢 Complete | - | Tap to sync early or wait |
| **Sync plan to Paprika** | 🟢 Complete | - | v1 API with gzip - **verified in Paprika app 2026-04-26** |

### ❌ Cut from v1.0 (not needed for generate-first)

| Feature | Reason |
|---------|--------|
| Recipe grid browsing | User doesn't pick recipes |
| Manual assignment UI | Generation does this |
| Drag-drop / swipe gestures | Not needed - just "regenerate" |
| Recipe detail view | Maybe later, not core flow |

---

## Milestones

### 🚀 v1.0 - Full MVP (Current)

**Goal**: Generate a week of dinners, auto-sync to Paprika
**Status**: Feature-complete, needs manual verification

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

### 📈 v1.1 - Polish (In Progress)

**Goal**: Refinements based on real usage

- [x] Image caching (200MB disk cache, shimmer loading, retry on failure)
- [x] Sync status visibility (SyncStatusManager, pull-to-reveal)
- [x] Skeleton loading screens (WeekPlanSkeletonView)
- [x] Recipe photo tap → RecipeDetailView with ingredients/directions
- [x] "Undo" last regeneration (single-level undo, clears after sync)
- [ ] Accessibility audit

### 🌟 v2.0 - Smarter Generation

**Goal**: Generation that learns from rejections

- [ ] Track rejected recipes per session
- [ ] "Don't suggest this one for a while"
- [ ] No repeats from last week
- [ ] Basic variety rules (not same protein 3x)

### 🔮 v2.1 - Habit-Aware

**Goal**: Encode weekly patterns and preferences

- [ ] Fixed slots (Takeaway Friday, Sunday Roast)
- [ ] Recipe metadata (quick vs elaborate, kid-friendly)
- [ ] Weeknight vs weekend awareness
- [ ] Learns from "we didn't make this" feedback

### 🔮 v3.0+ Vision

- [ ] **Apple TV companion** - Kids involved in meal selection on the big screen, no personal devices
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

| Idea | Requested By | Votes | Status |
|------|--------------|-------|--------|
| [Idea 1] | [Source] | [#] | Evaluating |
| [Idea 2] | [Source] | [#] | Needs research |

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
| [iOS version feature] | [Impact] | [Plan] |
| [API availability] | [Impact] | [Plan] |

### Risks to Timeline

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| [Risk 1] | H/M/L | H/M/L | [Plan] |

---

## Revision History

| Date | Changes |
|------|---------|
| 2026-04-17 | **Major pivot**: Generate-first vision. Cut manual assignment UI. User steers via regenerate. |
| 2026-04-17 | PO review: offline added to v1.0, v2.0 split into simple/smart phases, parked grocery/nutrition/widgets |
| 2026-04-17 | Updated with actual MVP status, PO priorities, long-term vision |
| YYYY-MM-DD | Initial roadmap template |
