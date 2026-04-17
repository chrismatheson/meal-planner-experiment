# Product Roadmap

> *Maintained by: Product Manager*
> *Last updated: 2026-04-17*

## Vision

A native iOS app that enhances the Paprika Recipe Manager experience with better meal planning UX, offline support, and smart features.

---

## Current Focus

### 🎯 Now: MVP Completion

**Theme**: Get core meal planning workflow functional

| Feature | Status | Priority | Notes |
|---------|--------|----------|-------|
| Paprika login | 🟢 Complete | - | Working with multipart form auth |
| Recipe list display | 🟢 Complete | - | Grid UI with images |
| **Write-back meal selections** | ⚪ Not Started | P0 | ← *PO Priority* |
| **Token persistence** | ⚪ Not Started | P0 | ← *PO Priority* |
| Recipe data caching | ⚪ Not Started | P1 | Faster subsequent launches |

### 📋 Next: Polish & Full Sync

**Theme**: Complete v1.0 experience

| Feature | Priority | Effort | Dependencies |
|---------|----------|--------|--------------|
| Full recipe sync (pagination) | P1 | M | Token persistence |
| Meal plan week view | P1 | M | Write-back |
| Offline recipe viewing | P1 | M | Data caching |
| Error handling polish | P2 | S | None |

### 🔮 Later (Backlog)

| Feature | Priority | Notes |
|---------|----------|-------|
| Recipe search/filter | P2 | In-app search of cached recipes |
| Recipe detail view | P2 | Full recipe info, ingredients, steps |
| Pull-to-refresh | P3 | Nice UX polish |

---

## Milestones

### 🚀 MVP (v1.0)

**Goal**: Usable app that syncs with Paprika and allows meal planning - works offline
**Status**: In Progress

- [x] User can login with Paprika credentials
- [x] User can view their recipes with images
- [ ] User can assign recipes to meal plan slots
- [ ] Changes sync back to Paprika
- [ ] User stays logged in between sessions
- [ ] App caches recipes locally (SwiftData)
- [ ] App works offline with cached data
- [ ] Syncs changes when connectivity restored

**Success Criteria**: User can plan a week of meals offline, and changes appear in Paprika when back online

### 📈 v1.1 - Enhanced Experience

**Goal**: Polish and quality-of-life improvements

- [ ] Recipe search and filtering
- [ ] Recipe detail view
- [ ] Meal plan week navigation
- [ ] Accessibility audit and fixes
- [ ] Loading states and error handling polish

### 🌟 v2.0 - Auto-populate (Simple)

**Goal**: Reduce manual meal planning effort with basic automation

- [ ] "Fill my week" button - randomly assigns recipes to empty slots
- [ ] Basic exclusions (e.g., "not this recipe again this week")
- [ ] Respects any manually-placed meals

**Philosophy**: Ship simple randomisation, see how it holds up in real life before adding complexity.

### 🔮 v2.1 - Smart Constraints

**Goal**: Intelligent meal planning based on rules and habits

- [ ] Dietary rules (vegetarian Mondays, no nuts, etc.)
- [ ] Habit patterns (takeaway Fridays, Sunday roast, quick meals on busy days)
- [ ] Ingredient-aware suggestions (use what's in the fridge)
- [ ] Meal history awareness (don't repeat too often)

### 🔮 v3.0+ Vision

- [ ] Apple TV companion
  - it mihgt be a nice feature to have the kids involved in selecting meals, or maybe just making suggestions. But i dont want to stick them in front of an iPad or phone.
- [ ] Siri Shortcuts integration
- [ ] Family sharing / multi-user
- [ ] Calendar integration
- [ ] Grocery delivery service integration

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
| 2026-04-17 | PO review: offline added to v1.0, v2.0 split into simple/smart phases, parked grocery/nutrition/widgets |
| 2026-04-17 | Updated with actual MVP status, PO priorities, long-term vision |
| YYYY-MM-DD | Initial roadmap template |
