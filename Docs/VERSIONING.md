# Versioning

This project uses [Semantic Versioning](https://semver.org/) with pre-release identifiers for development builds.

## Format

```
MAJOR.MINOR.PATCH[-preN]
```

| Component | Description |
|-----------|-------------|
| MAJOR | Breaking changes, major milestones |
| MINOR | New features, backwards compatible |
| PATCH | Bug fixes, minor improvements |
| -preN | Pre-release build number (git commit count) |

## Examples

| Version | Meaning |
|---------|---------|
| `1.0.0` | First stable release |
| `2.0.0-pre86` | Development build, 86 commits, working toward 2.0.0 |
| `2.0.0` | Stable 2.0.0 release |
| `2.1.0-pre92` | Development build toward 2.1.0 |

## Xcode Configuration

- **MARKETING_VERSION**: The semver string (e.g., `2.0.0-pre86`)
- **CURRENT_PROJECT_VERSION**: The build number (e.g., `86`)

## When to Bump

| Action | Version Change |
|--------|----------------|
| Bug fix during dev | Keep version, commit count auto-increments |
| New feature complete | Bump MINOR, keep `-preN` |
| Major milestone shipped | Remove `-preN` for stable release |
| Breaking change | Bump MAJOR |

## Release Process

1. Development: `2.0.0-pre86`, `2.0.0-pre87`, ...
2. Ready to ship: Remove `-preN` → `2.0.0`
3. Start next cycle: `2.1.0-pre1` or `2.0.1-pre1`

## History

| Version | Date | Notes |
|---------|------|-------|
| 1.0.0 | - | MVP: Login, sync, generate |
| 1.1.0 | - | Polish: Recipe detail, undo, accessibility |
| 1.2.0 | - | Offline: Stale-while-refresh, offline auth |
| 2.0.0-preN | Current | Smarter: Rejection tracking, protein variety |
