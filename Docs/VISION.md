# Product Vision

> *Maintained by: Product Manager*
> *Last Updated: 2026-04-17*

## Vision Statement

**MealPlanner** is **autopilot for meal planning**. It generates your weekly dinner plan from your Paprika recipe library. You just steer.

---

## The Problem

### Who is our user?

| Attribute | Description |
|-----------|-------------|
| **Name** | "Tired of Deciding Dana" |
| **Demographics** | Home cook, 25-55, has a recipe library, plans meals (or wants to) |
| **Goals** | Have a meal plan without the cognitive load of creating one |
| **Frustrations** | Decision fatigue - staring at recipes not knowing what to pick |
| **Tech comfort** | Medium-High (already uses Paprika) |

### What problem are we solving?

**The real problem isn't capturing a meal plan - it's MAKING the plan.**

Plenty of apps let you record what you'll eat. Calendars, Paprika, notes apps. The container exists. But every one of them asks the same thing:

> "What do you want to eat Monday?"

That question is the problem. Multiply it by 7 days and meal planning becomes a chore.

**Pain points**:
1. Decision fatigue - too many recipes, too many choices
2. The plan takes mental effort to create
3. Blank calendar is intimidating
4. "What should we have?" is asked 7+ times per week

**Impact**: Users abandon meal planning entirely, losing the benefits of their curated recipe collection.

---

## The Solution

### Core Value Proposition

| We are NOT | We ARE |
|------------|--------|
| A recipe picker | A plan generator |
| Asking "what do you want?" | Suggesting "how about this?" |
| Another empty calendar | An autopilot that fills the week |

### Key Differentiator

**We generate the plan. User just steers.**

```
[Generate Week] → [Review] → [Regenerate any day] → [Accept] → [Synced to Paprika]
```

User never has to answer "what do you want Monday?" - they only answer "is this okay?"

### Interaction Model

| Old way (Paprika, etc) | New way (MealPlanner) |
|------------------------|----------------------|
| Browse recipes | One-tap generate |
| Pick Monday's meal | Review suggestion |
| Pick Tuesday's meal | "That one's fine" |
| Pick Wednesday's meal | "Not that, try another" |
| × 7 | Accept week |

**Rejection-based steering**: Don't pick from 200 recipes. Just veto bad suggestions until acceptable.

### Design Philosophy

Minimal UI. The app does the thinking. User does the approving.

| Principle | Implication |
|-----------|-------------|
| **Generate, don't browse** | No recipe grid to scroll through |
| **One action per screen** | Generate / Review / Accept |
| **Steer, don't drive** | Regenerate button, not recipe picker |
| **Fast to "done"** | Whole flow in under 60 seconds |

---

## Success Metrics

### North Star Metric

**Plans Accepted**: User generates a week and taps "Use This Plan"

**Target**: 80%+ of generated plans get accepted (with or without regenerations)

### Supporting Metrics

| Metric | Definition | Target | Rationale |
|--------|------------|--------|-----------|
| Time to Accept | Seconds from "Generate" to "Accept" | < 60 sec | Proves it's faster than manual |
| Regenerations per Plan | How many "try another" taps | < 3 avg | Shows generation quality |
| Return Rate | Comes back next week | 70%+ | Habit formation |
| Sync Success | Plans synced to Paprika | 95%+ | Core value delivery |

---

## Scope

### In Scope (v1.0)

- [x] Paprika credential authentication
- [x] Fetch recipe library from Paprika
- [ ] Generate 7-day dinner plan (random, no duplicates)
- [ ] Review week with per-day regenerate
- [ ] Excluded-random regeneration (rejected recipes don't reappear this session)
- [ ] Accept and sync plan to Paprika
- [ ] Offline operation with cached recipes
- [ ] Token persistence (stay logged in)

### Out of Scope (for now)

- Breakfast / lunch (dinner only for v1.0)
- Recipe browsing / manual picking
- Smart generation (constraints, habits, learning)
- Recipe editing/creation (use Paprika)
- Shopping lists (Paprika does this)

### Explicitly NOT Building

- **Recipe picker UI**: User doesn't choose - app suggests
- **Calendar week view**: Just 7 days, today forward
- **Manual assignment**: No drag-drop, no browse-and-pick

---

## Integration: Paprika

### Paprika Recipe Manager 3
- **App Store**: https://apps.apple.com/gb/app/paprika-recipe-manager-3/id1303222868
- **Sync API**: Uses Paprika's cloud sync service
- **Authentication**: Paprika sync credentials (email/password)

### Data Flow
```
┌─────────────┐      ┌─────────────┐      ┌─────────────┐
│   Paprika   │ ───▶ │ MealPlanner │ ───▶ │   Paprika   │
│  (recipes)  │      │  (planning) │      │   (plans)   │
└─────────────┘      └─────────────┘      └─────────────┘
     Sync                Create              Sync Back
```

---

## Future Evolution

### v2.0: Smarter Generation
- Learn from regenerations ("user always rejects fish on weekdays")
- Basic constraints ("no repeats from last week")

### v2.1: Habit-Aware
- Encode weekly patterns (Takeaway Friday, Sunday Roast)
- Recipe metadata (quick vs elaborate, kid-friendly)

### Beyond: Feedback Loop
- "We made this" / "We skipped this" / "Family didn't like it"
- Builds preference model over time

---

## Risks & Assumptions

### Key Assumptions

1. **Random generation is useful** - Even without smarts, having a plan beats no plan
2. **Rejection-based UX works** - Easier to say "not that" than to pick from 200
3. **Paprika sync API is stable** - Reverse-engineered, may change

### Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Paprika changes sync API | Medium | High | Monitor API, graceful degradation |
| Random suggestions feel "dumb" | Medium | Medium | v2.0 adds learning, v1.0 sets expectations |
| Users want manual control | Low | Low | They can use Paprika for that |

---

## Revision History

| Date | Author | Changes |
|------|--------|---------|
| 2026-04-17 | PM Agent | Major pivot: generate-first vision, rejection-based steering |
| 2026-04-17 | PM Agent | Initial version - Paprika companion concept |
