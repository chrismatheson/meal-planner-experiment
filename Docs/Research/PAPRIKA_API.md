# API Investigation: Paprika Recipe Manager Sync

> **Status**: 🟢 Complete
> **Priority**: P0 - Blocks all development
> **Owner**: Researcher Agent
> **Last Updated**: 2026-04-17

## Overview

- **Service**: Paprika Recipe Manager 3 Cloud Sync
- **App Store**: https://apps.apple.com/gb/app/paprika-recipe-manager-3/id1303222868
- **Official Documentation**: ❌ None - API is undocumented
- **Community Documentation**: ✅ Excellent - multiple reverse-engineering efforts exist
- **Authentication**: Bearer JWT token via email/password login

## Executive Summary

**GOOD NEWS**: The Paprika API has been thoroughly reverse-engineered by the community. Multiple working implementations exist in Python, TypeScript, and Rust. We can build our companion app with confidence.

### Key Findings

| Question | Answer |
|----------|--------|
| Can we authenticate? | ✅ Yes - email/password → JWT token |
| Can we fetch recipes? | ✅ Yes - `/api/v2/sync/recipes/` |
| Can we fetch meal plans? | ✅ Yes - `/api/v2/sync/menuitems/` and `/api/v2/sync/menus/` |
| Can we write meal plans? | ✅ Yes - POST to sync endpoints |
| Data format? | JSON (gzip compressed) |
| Existing libraries? | ✅ Multiple: Python, TypeScript, Rust |

---

## API Details

### Base URL
```
https://www.paprikaapp.com/api/v2/
```

### Authentication

**Endpoint**: `POST /api/v2/account/login/`

- Uses multipart form data with email + password
- Returns JWT token in `result.token`
- Token used as `Authorization: Bearer {token}` header

```swift
// Swift implementation approach
struct PaprikaAuth {
    let email: String
    let password: String

    func login() async throws -> String {
        // POST to /api/v2/account/login/
        // Returns JWT token
    }
}
```

### Sync Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/v2/sync/recipes/` | POST | List all recipes (returns UIDs + metadata) |
| `/api/v2/sync/recipe/{uuid}/` | POST | Get/update single recipe |
| `/api/v2/sync/menuitems/` | POST | **Meal plan entries** ⭐ |
| `/api/v2/sync/menus/` | POST | Menu/meal plan collections |
| `/api/v2/sync/categories/` | POST | Recipe categories |
| `/api/v2/sync/groceryitems/` | POST | Shopping list items |

### Request Format

All sync requests use:
- `Content-Type: multipart/form-data`
- Body contains gzip-compressed JSON
- `User-Agent: Paprika Recipe Manager 3/3.x.x`

### Response Format

```json
{
  "result": { ... }  // or true for success
}
```

---

## Data Models

### Recipe (from API)
```json
{
  "uid": "E5BCA7D4-7FAB-4B1B-AC14-7D5C843B56FA",
  "name": "Best Vegetarian Chili",
  "ingredients": "1 tablespoon olive oil\n½ medium onion...",
  "directions": "Gather all ingredients.\n\nHeat olive oil...",
  "description": "Recipe notes",
  "servings": "4 servings",
  "prep_time": "35 min",
  "cook_time": "1 hour",
  "total_time": "1 hour 35 min",
  "rating": 4,
  "categories": ["Dinner", "Vegetarian"],
  "photo": "BC6BFB89-1301-445C-AB7F-61FF0410E122.jpg",
  "source": "allrecipes.com",
  "source_url": "https://...",
  "on_favorites": true,
  "created": "2024-01-15T10:30:00Z"
}
```

### Menu Item (Meal Plan Entry) ⭐
```json
{
  "uid": "UUID",
  "recipe_uid": "recipe-uuid-here",
  "date": "2024-01-15",
  "order_flag": 0,
  "type_uid": "meal-type-uuid",
  "name": "Recipe name (denormalized)"
}
```

---

## Existing Libraries

### Recommended: kappari (Python)
- **URL**: https://github.com/johnwbyrd/kappari
- **Quality**: Excellent documentation, working code
- **Includes**: Full API docs, schema docs, crypto implementation
- **License**: AGPL-3.0

### Also Available

| Library | Language | Notes |
|---------|----------|-------|
| `paprika-recipes` | Python | pip installable, CLI tool |
| `paprika-api` | TypeScript/Node | npm package |
| `paprika-rs` | Rust | Full client + custom server |
| Multiple MCP servers | Python | Claude integration ready |

---

## Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| API changes without notice | Medium | Version lock User-Agent, monitor for errors |
| Rate limiting | Low | Implement exponential backoff |
| ToS concerns | Low | Accessing own data for personal use is legal |
| Authentication complexity | Low | JWT is standard, libraries handle it |

### Legal Note
Per kappari docs: "Legal reverse engineering for interoperability" - accessing your own data from legitimately purchased software is protected.

---

## Recommendations for Architect

### 1. Use API v2 (not v1)
- v2 is current, v1 is legacy
- All modern clients use v2

### 2. Implement Gzip Handling
- All payloads are gzip compressed
- Swift has native gzip support via `Compression` framework

### 3. Store JWT Token Securely
- Use iOS Keychain for token storage
- Implement token refresh on 401

### 4. Key Endpoints for MVP
```
1. POST /api/v2/account/login/     → Get token
2. POST /api/v2/sync/recipes/      → Get recipe list
3. POST /api/v2/sync/recipe/{uid}/ → Get recipe details
4. POST /api/v2/sync/menuitems/    → Read/write meal plans
```

### 5. Consider Offline-First
- Paprika uses sync architecture (not request/response)
- Cache recipes locally, sync periodically
- Handle conflicts with timestamps

---

## Research Log

| Date | Activity | Findings |
|------|----------|----------|
| 2026-04-17 | Web search for existing implementations | Found multiple GitHub repos with working code |
| 2026-04-17 | Reviewed kappari documentation | Comprehensive API v2 docs, schema, auth flow |
| 2026-04-17 | Reviewed endpoints.md | Confirmed menuitems endpoint for meal planning |
| 2026-04-17 | Reviewed schema.md | Full database schema including recipes, menus |

---

## References

- **kappari** (primary): https://github.com/johnwbyrd/kappari
- **paprika-recipes**: https://github.com/coddingtonbear/paprika-recipes
- **paprika-api (Node)**: https://github.com/joshstrange/paprika-api
- **Original gist**: https://gist.github.com/mattdsteele/7386ec363badfdeaad05a418b9a1f30a
