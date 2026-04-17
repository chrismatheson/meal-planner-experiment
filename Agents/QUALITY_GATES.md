# Quality Gates

> **Lesson Learned**: MVP was declared "complete" but failed on first real use because integration tests were skipped.

## Mandatory Gates

No phase can be marked complete without passing these gates:

### Phase 1: Discovery → Design
- [ ] **API requirements documented** with ALL headers, auth patterns, error cases
- [ ] **Integration risks identified** (rate limits, required headers, auth flow)

### Phase 2: Foundation → Features  
- [ ] **API client has integration test** that hits real endpoint (can be manual)
- [ ] **Authentication flow verified** with real credentials at least once

### Phase 3: Features → QA
- [ ] **Happy path works end-to-end** - not just "builds successfully"
- [ ] **Core user journey tested manually** before declaring feature complete

### Phase 4: QA → Release
- [ ] **All P0 test cases pass** (not just written, actually executed)
- [ ] **Smoke test checklist completed** with evidence

---

## Integration Test Requirements

For ANY external API integration:

### Minimum Tests (Before "Complete")
```swift
// These MUST pass against real API before MVP is done:

func test_authentication_withValidCredentials_succeeds() async throws {
    // REAL API CALL - not mocked
}

func test_authentication_withInvalidCredentials_failsGracefully() async throws {
    // REAL API CALL - verify error handling
}

func test_coreFeature_afterAuth_works() async throws {
    // REAL API CALL - verify the main feature works
}
```

### What We Missed (Paprika Example)

```swift
// This test would have caught the User-Agent issue:
func test_login_againstRealPaprikaAPI() async throws {
    let client = PaprikaClient(keychain: MockKeychain())
    
    // This would have failed with "Unrecognized client"
    // and we'd have caught it BEFORE demo
    let token = try await client.login(
        email: "test@example.com", 
        password: "testpass"
    )
    
    XCTAssertFalse(token.isEmpty)
}
```

---

## Smoke Test Checklist

Before ANY demo or "MVP complete" declaration:

### Authentication
- [ ] Can launch app
- [ ] Can see login screen
- [ ] Can enter credentials
- [ ] Login with VALID credentials succeeds
- [ ] Login with INVALID credentials shows error (not crash)
- [ ] After login, main screen appears

### Core Feature
- [ ] Primary data loads (recipes, etc.)
- [ ] Can perform main action (create meal plan, etc.)
- [ ] Data persists after app restart

### Error Handling
- [ ] Network offline shows appropriate message
- [ ] Invalid data doesn't crash app

---

## Agent Responsibilities Update

### Researcher Agent
- [ ] Must create `INTEGRATION_CHECKLIST.md` for any external API
- [ ] Must flag ALL required headers, auth patterns, gotchas
- [ ] Must include "verification test" that Developer/QA can run

### Developer Agent  
- [ ] Must write integration test BEFORE marking API client "done"
- [ ] Must run test against real API at least once
- [ ] Must not rely solely on "it compiles"

### QA Agent
- [ ] Must execute (not just write) critical path tests
- [ ] Must verify integration tests exist and pass
- [ ] Must block "complete" status if smoke tests not run

### Orchestrator
- [ ] Must require smoke test evidence before phase completion
- [ ] Must not mark MVP complete without integration verification
- [ ] Must ask "has this been tested against real [API/service]?"

---

## Post-Mortem: Paprika User-Agent Bug

**What happened**: App launched, login failed with "Unrecognized client"

**Root cause**: Paprika API requires `User-Agent: Paprika Recipe Manager 3/x.x.x` header

**Why it wasn't caught**:
1. Research mentioned User-Agent but didn't flag it as REQUIRED
2. No integration test was written or executed
3. "Build succeeds" was treated as "feature works"
4. QA test plan existed but was never executed

**Fix**: Added User-Agent header to all API requests

**Process fix**: This document - mandatory quality gates
