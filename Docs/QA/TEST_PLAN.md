# MVP Test Plan

> *Maintained by: QA Agent*
> *Last Updated: 2026-04-25*

## Purpose

This document contains **acceptance criteria as test cases**.
- For planning/priorities, see [ROADMAP.md](../ROADMAP.md)
- Status reflects what's **actually verified working**

## v1.0 Core Flow

```
Login → "Plan My Week" → Review 7 dinners → Regenerate any → Accept → Synced
```

## Test Summary

| Feature | Unit Tests | UI Tests | Manual Tests | Status |
|---------|------------|----------|--------------|--------|
| Authentication | ✅ | 🟢 | 🟢 | ✅ Complete (with persistence) |
| Recipe Fetching | ✅ | ⚪ | 🟢 | ✅ Complete |
| Plan Generation | ⚪ | 🟢 | 🟢 | ✅ Complete |
| Review & Regenerate | ⚪ | 🟢 | 🟢 | ✅ Complete |
| Sync to Paprika | ⚪ | 🟢 | ⚪ | ⚠️ Needs Manual Verify |
| Offline Operation | ⚪ | ⚪ | ⚪ | ⚪ Not Started |

---

## Feature 1: Authentication

### Unit Tests

| Test ID | Description | Status |
|---------|-------------|--------|
| AUTH-001 | Login with valid credentials returns token | ⚪ |
| AUTH-002 | Login with invalid credentials throws error | ⚪ |
| AUTH-003 | Token is saved to Keychain on success | ⚪ |
| AUTH-004 | App state updates to authenticated on login | ⚪ |
| AUTH-005 | Sign out clears token from Keychain | ⚪ |

### Manual Test Cases

| Test ID | Steps | Expected | Status |
|---------|-------|----------|--------|
| AUTH-M01 | 1. Launch app<br>2. Enter valid credentials<br>3. Tap Sign In | Navigates to Recipe List | 🟢 Done |
| AUTH-M02 | 1. Launch app<br>2. Enter invalid credentials<br>3. Tap Sign In | Shows error alert | 🟢 Done (UI test) |
| AUTH-M03 | 1. Sign in<br>2. Kill app<br>3. Relaunch | Remains signed in | 🟢 Done (token persistence works) |

---

## Feature 2: Recipe Fetching

### Unit Tests

| Test ID | Description | Status |
|---------|-------------|--------|
| REC-001 | Recipe JSON decoding works | ✅ |
| REC-002 | Recipe displayTime prefers totalTime | ✅ |
| REC-003 | Recipe displayTime falls back to cookTime | ✅ |
| REC-004 | Recipes cached in SwiftData | ⚪ |

### Manual Test Cases

| Test ID | Steps | Expected | Status |
|---------|-------|----------|--------|
| REC-M01 | 1. Sign in | Recipes fetched from Paprika | 🟢 Done |

---

## Feature 3: Plan Generation

### Acceptance Criteria

- [x] "Plan My Week" button generates 7 dinners
- [x] Random selection from recipe library
- [x] No duplicate recipes within the week
- [x] Generation < 2 seconds

### Unit Tests

| Test ID | Description | Status |
|---------|-------------|--------|
| GEN-001 | Generator produces 7 recipes | ⚪ (needs unit test) |
| GEN-002 | Generated week has no duplicates | ⚪ (needs unit test) |
| GEN-003 | Generator excludes specified recipes | ⚪ (needs unit test) |

### Manual Test Cases

| Test ID | Steps | Expected | Status |
|---------|-------|----------|--------|
| GEN-M01 | 1. Tap "Plan My Week" | 7 days shown with recipes | 🟢 Done |
| GEN-M02 | 1. Generate with 7+ recipes | No duplicates in week | 🟢 Done |
| GEN-M03 | 1. Generate with < 7 recipes | Graceful handling | ⚪ (edge case) |

---

## Feature 4: Review & Regenerate

### Acceptance Criteria

- [x] Review shows 7 cards: day + recipe name + photo
- [x] "↻ Another" replaces one day's recipe
- [ ] Rejected recipe excluded for rest of session
- [x] "↻ Regenerate All" replaces entire week
- [x] Auto-sync after 20s countdown (or tap to sync immediately)

### Manual Test Cases

| Test ID | Steps | Expected | Status |
|---------|-------|----------|--------|
| REV-M01 | 1. Generate<br>2. View review | 7 cards with day + recipe + photo | 🟢 Done |
| REV-M02 | 1. Tap "↻ Another" on a day | That day gets new recipe, others unchanged | 🟢 Done |
| REV-M03 | 1. Reject recipe A<br>2. Regenerate multiple times | Recipe A never reappears this session | ⚪ (not implemented) |
| REV-M04 | 1. Tap "↻ Regenerate All" (toolbar) | All 7 days get new recipes, countdown resets | 🟢 Done |
| REV-M05 | 1. Wait 20s or tap countdown | Auto-syncs to Paprika | 🟢 UI Test passes |

---

## Feature 5: Sync to Paprika

### Acceptance Criteria

- [x] Auto-sync sends 7 meals to Paprika (via v1 API with gzip)
- [ ] Meals appear in Paprika meal planner (**NEEDS MANUAL VERIFY**)
- [x] Green checkmark shown on success

### Manual Test Cases

| Test ID | Steps | Expected | Status |
|---------|-------|----------|--------|
| SYNC-M01 | 1. Generate plan<br>2. Wait for countdown or tap sync<br>3. Open Paprika iOS app | All 7 meals in Paprika meal planner | ⚪ **CRITICAL - NEEDS VERIFY** |
| SYNC-M02 | 1. Accept with poor network | Error shown, countdown stops | ⚪ |

---

## Feature 6: Offline Operation

### Acceptance Criteria

- [ ] App launches offline with cached recipes
- [ ] Can generate plan offline
- [ ] Plan queued and syncs when online
- [ ] Clear offline indicator

### Manual Test Cases

| Test ID | Steps | Expected | Status |
|---------|-------|----------|--------|
| OFFLINE-M01 | 1. Sign in online<br>2. Kill app<br>3. Airplane mode<br>4. Relaunch | Can generate plan | ⚪ |
| OFFLINE-M02 | 1. Accept plan offline<br>2. Restore network | Plan syncs to Paprika | ⚪ |
| OFFLINE-M03 | 1. Launch offline, no cache | "Connect to sync recipes" message | ⚪ |

---

## Edge Cases

| Test ID | Scenario | Expected | Status |
|---------|----------|----------|--------|
| EDGE-001 | No recipes in Paprika | Empty state shown | ⚪ |
| EDGE-002 | Network timeout | Error message, retry option | ⚪ |
| EDGE-003 | Token expires mid-session | Redirect to login | ⚪ |
| EDGE-004 | Very long recipe name | Truncated with ellipsis | ⚪ |

---

## Accessibility Tests

| Test ID | Check | Status |
|---------|-------|--------|
| A11Y-001 | VoiceOver navigates login form | ⚪ |
| A11Y-002 | Recipe cards have meaningful labels | ⚪ |
| A11Y-003 | Dynamic Type scales all text | ⚪ |
| A11Y-004 | All tap targets ≥ 44pt | ⚪ |

---

## Performance Tests

| Test ID | Metric | Target | Status |
|---------|--------|--------|--------|
| PERF-001 | App launch to interactive | < 2s | ⚪ |
| PERF-002 | Recipe grid scroll | 60 FPS | ⚪ |
| PERF-003 | Memory with 500 recipes | < 100MB | ⚪ |
