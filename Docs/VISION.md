# Product Vision

> *Maintained by: Product Manager*

## Vision Statement

**MealPlanner** helps **Paprika users** to **effortlessly plan their weekly meals** by **providing a focused, gesture-driven planning experience that syncs with their existing recipe library**.

---

## The Problem

### Who is our user?

| Attribute | Description |
|-----------|-------------|
| **Name** | "Organized Oliver" |
| **Demographics** | Home cook, 25-55, plans meals to save time/money |
| **Goals** | Plan the week's meals quickly, reduce decision fatigue |
| **Frustrations** | Paprika's meal planning is clunky, too many taps to assign recipes |
| **Tech comfort** | Medium-High (already uses Paprika) |

### What problem are we solving?

**Current state**: Paprika users manage recipes well but struggle with meal planning. The built-in planner requires too many taps and context switches.

**Pain points**:
1. Meal planning in Paprika is buried and tedious
2. Too many taps to assign a recipe to a day
3. Changing plans mid-week is friction-heavy
4. No quick "what should I cook?" suggestions

**Impact**: Users fall back to "what's in the fridge?" decisions, losing the benefit of their curated recipe collection.

---

## The Solution

### Core Value Proposition

| We are NOT | We ARE |
|------------|--------|
| A recipe manager | A meal planning layer |
| Replacing Paprika | Enhancing Paprika |
| A standalone app | A companion that syncs |

### Key Differentiators

1. **Gesture-First Planning**: Swipe to assign, swipe to replace - minimal taps
2. **Paprika Sync**: Uses your existing library, syncs plans back
3. **Focused UX**: Does one thing exceptionally well - meal planning
4. **Seamless Experience**: Feels like a natural extension of Paprika, not a foreign app

### Design Philosophy

This app should feel like it **belongs to the Paprika family**. Users moving between Paprika and MealPlanner should experience continuity, not jarring context switches.

| Principle | Implication |
|-----------|-------------|
| **Visual Continuity** | Match Paprika's color palette, typography, and spacing |
| **Interaction Patterns** | Follow Paprika's established gestures and navigation |
| **Familiar Components** | Recipe cards, lists, and details should feel recognizable |
| **Enhanced, Not Different** | Add value through focus, not through novelty |

> **Owner**: The Designer agent is responsible for auditing Paprika's design language and maintaining our Design System to ensure alignment. See [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md).

---

## Success Metrics

### North Star Metric

**Weekly Plans Created**: Number of users who create a complete week plan

**Target**: 70% of active users create at least one plan per week

### Supporting Metrics

| Metric | Definition | Target | Rationale |
|--------|------------|--------|-----------|
| Activation | User creates first meal plan | 80% within first session | Proves immediate value |
| Retention | Return within 7 days | 60% | Indicates habit formation |
| Plan Completion | Days filled in a plan | Avg 5+ days | Shows utility |
| Sync Success | Plans synced to Paprika | 95%+ | Core value delivery |

---

## Scope

### In Scope (MVP)

- [ ] Paprika credential authentication
- [ ] Fetch and display recipe library from Paprika sync
- [ ] Create meal plans for configurable period (default: 7 days)
- [ ] Assign recipes to days via swipe gesture
- [ ] Replace recipes in plan with quick swipe
- [ ] Sync completed plans back to Paprika

### Out of Scope (Future)

- [ ] Recipe editing/creation (use Paprika for that)
- [ ] Shopping list generation (Paprika does this)
- [ ] Nutritional tracking
- [ ] Multiple meal types per day (breakfast/lunch/dinner)
- [ ] Household/family sharing

### Explicitly NOT Building

- **Recipe Management**: Paprika handles this well - we don't duplicate
- **Shopping Lists**: Paprika generates these from meal plans
- **Social Features**: Focus on personal utility first

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

## Risks & Assumptions

### Key Assumptions

1. **Paprika sync API is stable** - Validate: Reverse-engineer and test API stability
2. **Users want a separate planning app** - Validate: User interviews, landing page test
3. **Swipe UX is intuitive** - Validate: Usability testing

### Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Paprika changes sync API | Medium | High | Monitor API, version lock, graceful degradation |
| Legal/ToS issues with Paprika | Low | High | Research ToS, consider reaching out to Paprika team |
| Users don't see value over built-in | Medium | Medium | Focus on UX speed, gather testimonials |

---

## Revision History

| Date | Author | Changes |
|------|--------|---------|
| 2026-04-17 | PM Agent | Initial version - Paprika companion concept |
