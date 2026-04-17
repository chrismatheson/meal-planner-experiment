# MVP Test Plan

> *Maintained by: QA Agent*
> *Last Updated: 2026-04-17*

## Purpose

This document contains **acceptance criteria as test cases**.
- For planning/priorities, see [ROADMAP.md](../ROADMAP.md)
- Status here reflects what's **actually verified working**

## Test Summary

| Feature | Unit Tests | UI Tests | Manual Tests | Status |
|---------|------------|----------|--------------|--------|
| Authentication | ✅ | ⚪ | 🟢 | Working (no persistence) |
| Recipe Library | ✅ | ⚪ | 🟢 | Working (first 50) |
| Meal Planning | ⚪ | ⚪ | ⚪ | Not Started |
| Sync (write-back) | ⚪ | ⚪ | ⚪ | Not Started |
| Offline Operation | ⚪ | ⚪ | ⚪ | Not Started |

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
| AUTH-M02 | 1. Launch app<br>2. Enter invalid credentials<br>3. Tap Sign In | Shows error alert | ⚪ |
| AUTH-M03 | 1. Sign in<br>2. Kill app<br>3. Relaunch | Remains signed in | ⚪ (needs token persistence) |

---

## Feature 2: Recipe Library

### Unit Tests

| Test ID | Description | Status |
|---------|-------------|--------|
| REC-001 | Recipe JSON decoding works | ✅ |
| REC-002 | Recipe displayTime prefers totalTime | ✅ |
| REC-003 | Recipe displayTime falls back to cookTime | ✅ |
| REC-004 | Recipes sync from API to SwiftData | ⚪ |

### Manual Test Cases

| Test ID | Steps | Expected | Status |
|---------|-------|----------|--------|
| REC-M01 | 1. Sign in<br>2. View Recipes tab | Grid of recipes appears | 🟢 Done |
| REC-M02 | 1. Pull to refresh | Recipes sync from Paprika | ⚪ |
| REC-M03 | 1. Type in search<br>2. Search for recipe | Filtered results shown | ⚪ |
| REC-M04 | 1. Disable network<br>2. Launch app | Cached recipes display | ⚪ (needs offline) |

---

## Feature 3: Meal Planning

### Unit Tests

| Test ID | Description | Status |
|---------|-------------|--------|
| MEAL-001 | MealItem JSON decoding works | ✅ |
| MEAL-002 | MealItem date parsing works | ✅ |
| MEAL-003 | Assigning recipe creates MealSlot | ⚪ |
| MEAL-004 | Removing meal deletes MealSlot | ⚪ |

### Manual Test Cases

| Test ID | Steps | Expected | Status |
|---------|-------|----------|--------|
| MEAL-M01 | 1. Go to Meal Plan tab | Current week shown | ⚪ |
| MEAL-M02 | 1. Tap empty slot<br>2. Select recipe | Recipe assigned to day | ⚪ |
| MEAL-M03 | 1. Swipe left on meal<br>2. Tap Replace | Picker opens, can swap | ⚪ |
| MEAL-M04 | 1. Swipe right on meal<br>2. Tap Remove | Slot becomes empty | ⚪ |
| MEAL-M05 | 1. Navigate to next week | Week advances | ⚪ |
| MEAL-M06 | 1. Tap "Today" button | Returns to current week | ⚪ |

---

## Feature 4: Sync (Write-back)

### Manual Test Cases

| Test ID | Steps | Expected | Status |
|---------|-------|----------|--------|
| SYNC-M01 | 1. Assign recipe<br>2. Open Paprika app | Meal appears in Paprika | ⚪ |
| SYNC-M02 | 1. Disable network<br>2. Assign recipe<br>3. Enable network | Syncs when online | ⚪ |

---

## Feature 5: Offline Operation

### Acceptance Criteria

- [ ] App launches without network and shows cached recipes
- [ ] User can browse cached recipes offline
- [ ] User can assign meals offline (queued locally)
- [ ] Changes sync automatically when connectivity restored
- [ ] Clear indication of offline state to user

### Manual Test Cases

| Test ID | Steps | Expected | Status |
|---------|-------|----------|--------|
| OFFLINE-M01 | 1. Sign in with network<br>2. Kill app<br>3. Enable airplane mode<br>4. Relaunch | Cached recipes display | ⚪ |
| OFFLINE-M02 | 1. While offline, assign recipe to meal slot | Assignment saved locally | ⚪ |
| OFFLINE-M03 | 1. While offline, make changes<br>2. Disable airplane mode | Changes sync to Paprika | ⚪ |
| OFFLINE-M04 | 1. Launch with no network, no cache | Appropriate empty/error state | ⚪ |

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
