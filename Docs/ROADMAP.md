# Product Roadmap

> *Maintained by: Product Manager*
> *Last updated: 2026-04-17*

## Vision

**Autopilot for meal planning.** Generate a week of dinners from your Paprika library. You just steer.

---

## Current Focus

### 🎯 Now: Generate-First MVP

**Theme**: App generates the plan, user just approves

| Feature | Status | Priority | Notes |
|---------|--------|----------|-------|
| Paprika login | 🟢 Complete | - | Working with multipart form auth |
| Recipe fetching | 🟢 Complete | - | Can pull from Paprika |
| **"Plan My Week" generation** | ⚪ Not Started | P0 | Random, no duplicates |
| **Review week UI** | ⚪ Not Started | P0 | 7 cards, regenerate per-day |
| **Sync plan to Paprika** | ⚪ Not Started | P0 | Write back on Accept |
| Token persistence | ⚪ Not Started | P1 | Stay logged in |
| Recipe caching | ⚪ Not Started | P1 | Offline generation |

### ❌ Cut from v1.0 (not needed for generate-first)

| Feature | Reason |
|---------|--------|
| Recipe grid browsing | User doesn't pick recipes |
| Manual assignment UI | Generation does this |
| Drag-drop / swipe gestures | Not needed - just "regenerate" |
| Recipe detail view | Maybe later, not core flow |

---

## Milestones

### 🚀 v1.0 - Generate-First MVP

**Goal**: Generate a week of dinners, steer with regenerate, sync to Paprika
**Status**: In Progress

**Core Flow:**
```
Login → "Plan My Week" → Review 7 dinners → Regenerate any → Accept → Synced
```

**Checklist:**
- [x] Paprika authentication
- [x] Fetch recipes from Paprika
- [ ] Generate 7-day plan (random, no duplicates in week)
- [ ] Review UI: 7 cards (day + recipe + photo)
- [ ] Per-day "↻ Another" (excluded-random)
- [ ] "↻ Regenerate All"
- [ ] "Use This Plan" → sync to Paprika
- [ ] Token persistence (stay logged in)
- [ ] Recipe caching (offline generation)

**Scope:**
- Dinner only (one meal per day)
- Next 7 days (rolling, not calendar week)
- Random generation (no "smart" yet)

**Success Criteria**: Generate → tweak → accept in under 60 seconds

### 📈 v1.1 - Polish

**Goal**: Refinements based on real usage

- [ ] Loading states and error handling
- [ ] Recipe photo tap → show name/description
- [ ] "Undo" last regeneration
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
