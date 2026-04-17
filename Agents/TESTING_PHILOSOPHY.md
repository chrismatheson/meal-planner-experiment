# Testing Philosophy

> **Core Principle**: Tests prove the software works. If tests pass but the app doesn't work, the tests are worthless.

## Red-Green-Refactor

All feature development follows TDD:

```
1. RED    → Write a failing test that defines the expected behavior
2. GREEN  → Write minimal code to make the test pass
3. REFACTOR → Clean up while keeping tests green
```

### What This Means in Practice

**Before writing any feature code:**
```swift
// ❌ WRONG: Write feature, then write tests
func fetchRecipes() async throws -> [Recipe] { ... }
// ... later ...
func test_fetchRecipes() { } // Tests what we built, not what we need

// ✅ RIGHT: Write test first
func test_fetchRecipes_returnsRecipesFromAPI() async throws {
    // This test defines the contract
    let client = PaprikaClient()
    let recipes = try await client.fetchRecipes()
    XCTAssertFalse(recipes.isEmpty)
    XCTAssertNotNil(recipes.first?.name)
}
// Now implement fetchRecipes() to make this pass
```

---

## Mocking Strategy: Mock the Minimum

**Default**: Use real implementations  
**Mock only when**: Real implementation is slow, flaky, expensive, or dangerous

### The Mocking Pyramid

```
        ┌─────────────┐
        │   MOCK      │  ← External payment APIs, destructive operations
        │   (rare)    │
        ├─────────────┤
        │   FAKE      │  ← In-memory databases, local test servers
        │  (sometimes)│
        ├─────────────┤
        │    REAL     │  ← Real API calls, real database, real UI
        │  (default)  │
        └─────────────┘
```

### When to Mock

| Situation | Action | Example |
|-----------|--------|---------|
| External API is free & fast | **Don't mock** | Paprika API |
| External API costs money | Mock | Stripe payments |
| External API is slow (>5s) | Consider faking | Large file uploads |
| Operation is destructive | Mock | Delete user account |
| Need to test error paths | Mock specific errors | Network timeout |

### When NOT to Mock

| Situation | Why Not Mock |
|-----------|--------------|
| "It's easier" | Tests won't catch real integration bugs |
| "It's faster" | A few seconds is worth catching real bugs |
| "It's more reliable" | Flaky real tests reveal flaky real code |

---

## Test Types & Trade-offs

| Type | Speed | Confidence | Flakiness | When to Use |
|------|-------|------------|-----------|-------------|
| Unit (mocked) | ⚡ Fast | 🔴 Low | ✅ Stable | Pure logic, algorithms |
| Integration (real API) | 🐢 Medium | 🟡 Medium | ⚠️ Some | API clients, data layer |
| UI E2E (real app) | 🐌 Slow | 🟢 High | ⚠️ Some | Critical user paths |

### Recommended Distribution

```
Unit Tests:        30%  → Fast feedback on logic
Integration Tests: 40%  → Verify real integrations work  
UI E2E Tests:      30%  → Prove the app actually works
```

---

## Test Requirements by Phase

### Before "Feature Complete"
- [ ] Integration test hits real API and passes
- [ ] At least one happy-path UI test exists

### Before "MVP Complete"  
- [ ] All critical paths have UI tests
- [ ] UI tests run against real backend
- [ ] Tests have been run on real device/simulator (not just "build succeeded")

### Before Release
- [ ] All tests pass
- [ ] Manual smoke test completed
- [ ] No tests skipped without documented reason

---

## Handling Flaky Tests

1. **Investigate first** - Flakiness often reveals real timing bugs
2. **Fix the code** - If it's a race condition, fix it
3. **Fix the test** - Add proper waits, not arbitrary sleeps
4. **Quarantine last resort** - Mark flaky with TODO, fix within 1 sprint

```swift
// ❌ BAD: Hide flakiness
Thread.sleep(forTimeInterval: 2)

// ✅ GOOD: Explicit wait for condition
let element = app.buttons["Submit"]
XCTAssertTrue(element.waitForExistence(timeout: 10))
```

---

## Test Credentials & Secrets

- Store test credentials in environment variables
- Never commit real credentials
- Use dedicated test accounts (e.g., blackhole@mailinator.com)
- Document required env vars in README

```bash
# Required for integration/UI tests
export PAPRIKA_TEST_EMAIL="test@example.com"
export PAPRIKA_TEST_PASSWORD="testpassword"
```
