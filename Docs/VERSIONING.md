# Versioning

This project uses [Semantic Versioning](https://semver.org/) with build numbers for pre-release tracking.

## Format

Apple's `CFBundleShortVersionString` only allows `X.Y.Z` format, so we use:

```
MARKETING_VERSION: X.Y.Z        (e.g., 2.0.0)
CURRENT_PROJECT_VERSION: N      (e.g., 89 = git commit count)
```

**Display in app**: `2.0.0 (89)` - combining both values.

## Examples

| MARKETING_VERSION | BUILD | Display | Meaning |
|-------------------|-------|---------|---------|
| `2.0.0` | `89` | `2.0.0 (89)` | Dev build 89, working toward 2.0.0 stable |
| `2.0.0` | `100` | `2.0.0 (100)` | Ready for release |
| `2.0.1` | `101` | `2.0.1 (101)` | Patch release |

## Xcode Configuration

- **MARKETING_VERSION** (`CFBundleShortVersionString`): Semantic version, X.Y.Z only
- **CURRENT_PROJECT_VERSION** (`CFBundleVersion`): Git commit count (auto-increments)

## When to Bump

| Action | Version Change |
|--------|----------------|
| Bug fix during dev | Build number auto-increments with each commit |
| New feature complete | Bump MINOR via `./Scripts/bump-version.sh minor` |
| Breaking change | Bump MAJOR via `./Scripts/bump-version.sh major` |

## Script Usage

```bash
./Scripts/bump-version.sh          # Bump PATCH + BUILD (default for each push)
./Scripts/bump-version.sh minor    # 2.0.5 → 2.1.0 (new feature)
./Scripts/bump-version.sh major    # 2.1.5 → 3.0.0 (breaking change)
./Scripts/bump-version.sh build    # Only bump build number, keep version
```

**Default behavior:** Each push to main bumps both PATCH and BUILD.
- `2.0.0 (89)` → `2.0.1 (90)` → `2.0.2 (91)` → ...

## History

| Version | Build | Notes |
|---------|-------|-------|
| 1.0.0 | - | MVP: Login, sync, generate |
| 1.1.0 | - | Polish: Recipe detail, undo, accessibility |
| 1.2.0 | - | Offline: Stale-while-refresh, offline auth |
| 2.0.0 | 89+ | Smarter: Rejection tracking, cuisine diversity |
