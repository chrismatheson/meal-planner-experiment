# MVP Feature Specifications

> *Maintained by: Product Manager Agent*  
> *Last Updated: 2026-04-17*

## MVP Scope Summary

| # | Feature | Priority | Status |
|---|---------|----------|--------|
| 1 | Login with Paprika | P0 | ⚪ Not Started |
| 2 | View Recipe Library | P0 | ⚪ Not Started |
| 3 | View/Create Meal Plan | P0 | ⚪ Not Started |
| 4 | Assign Recipe to Day | P0 | ⚪ Not Started |
| 5 | Replace Recipe (Swipe) | P0 | ⚪ Not Started |
| 6 | Sync to Paprika | P0 | ⚪ Not Started |

---

## Feature 1: Login with Paprika Credentials

**As a** Paprika user  
**I want** to sign in with my Paprika sync credentials  
**So that** I can access my recipe library

### Acceptance Criteria

- [ ] User sees email and password fields
- [ ] User sees "Sign In" button (disabled until both fields have content)
- [ ] On submit, app authenticates with Paprika API
- [ ] On success, user is taken to Recipe Library
- [ ] On failure, user sees clear error message
- [ ] Credentials are stored securely in Keychain
- [ ] User stays logged in between app launches

### UI Notes
- Single screen, centered form
- Paprika-style colors and typography
- "Sign in with your Paprika sync account" header
- Link to Paprika website for account issues

### Error States
| Error | Message |
|-------|---------|
| Invalid credentials | "Invalid email or password. Please try again." |
| Network error | "Unable to connect. Check your internet connection." |
| Server error | "Paprika servers are unavailable. Try again later." |

---

## Feature 2: View Recipe Library

**As a** logged-in user  
**I want** to see all my Paprika recipes  
**So that** I can browse and select recipes for meal planning

### Acceptance Criteria

- [ ] Recipes load automatically after login
- [ ] Recipes display in a grid (2 columns on iPhone)
- [ ] Each recipe card shows: image, title, category, cook time
- [ ] Pull-to-refresh syncs latest recipes from Paprika
- [ ] Search bar filters recipes by name
- [ ] Empty state shown if no recipes
- [ ] Loading state shown during initial fetch

### UI Notes
- Grid layout matching Paprika's recipe grid
- Recipe cards: 1:1 image, title below, metadata in gray
- Search bar at top (iOS standard)
- Tab bar navigation (Recipes | Meal Plan)

---

## Feature 3: View/Create Meal Plan

**As a** user  
**I want** to see a weekly meal plan view  
**So that** I can plan my meals for the coming days

### Acceptance Criteria

- [ ] Default view shows current week (Mon-Sun)
- [ ] Each day shows assigned recipe (if any) or empty slot
- [ ] Tapping empty slot opens recipe picker
- [ ] Tapping assigned recipe shows quick actions (view, replace, remove)
- [ ] Can swipe between weeks
- [ ] Today is visually highlighted
- [ ] Week dates shown in header (e.g., "Apr 14 - 20")

### UI Notes
- Horizontal scrolling week view or vertical day list
- Day columns with date header
- Recipe shown as mini card in slot
- Empty slots have "+" or dashed border

---

## Feature 4: Assign Recipe to Day

**As a** user  
**I want** to assign a recipe to a specific day  
**So that** I know what to cook that day

### Acceptance Criteria

- [ ] Tapping empty slot opens recipe picker
- [ ] Recipe picker shows full recipe library
- [ ] Can search/filter in picker
- [ ] Selecting recipe assigns it to that day
- [ ] Assignment appears immediately (optimistic update)
- [ ] Assignment syncs to Paprika in background

### UI Notes
- Recipe picker as sheet/modal
- Same grid layout as recipe library
- Tap to select → dismiss and assign

---

## Feature 5: Replace Recipe with Swipe

**As a** user  
**I want** to quickly replace a planned recipe  
**So that** I can adjust my plan without friction

### Acceptance Criteria

- [ ] Swipe left on assigned recipe reveals "Replace" action
- [ ] Tapping "Replace" opens recipe picker
- [ ] Selecting new recipe replaces the old one
- [ ] Swipe right reveals "Remove" action
- [ ] Removing clears the slot (no recipe assigned)
- [ ] All changes sync to Paprika

### UI Notes
- Standard iOS swipe actions
- Replace: blue background, arrow icon
- Remove: red background, trash icon
- Haptic feedback on action

---

## Feature 6: Sync to Paprika

**As a** user  
**I want** my meal plans to sync back to Paprika  
**So that** I can see them in the main Paprika app

### Acceptance Criteria

- [ ] All meal plan changes sync automatically
- [ ] Sync happens in background (no blocking UI)
- [ ] Sync indicator shows when syncing
- [ ] Offline changes queue and sync when online
- [ ] Conflicts resolved (last-write-wins for meal plans)
- [ ] Pull-to-refresh forces immediate sync

### UI Notes
- Subtle sync indicator (cloud icon in nav bar)
- No modal spinners - optimistic updates everywhere
- Error toast if sync fails repeatedly

---

## Out of Scope (v1.0)

- Multiple meals per day (breakfast/lunch/dinner)
- Recipe editing or creation
- Shopping list generation
- Nutritional information
- Sharing meal plans
- Widgets
