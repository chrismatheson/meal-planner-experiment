#!/bin/bash
# Bump version script for MealPlanner
#
# Default: Bumps PATCH and BUILD on every run (for each push to main)
# - MARKETING_VERSION: X.Y.Z (2.0.0 → 2.0.1 → 2.0.2)
# - CURRENT_PROJECT_VERSION: Incrementing build number
#
# Usage:
#   ./bump-version.sh         # Bump patch + build (default for pushes)
#   ./bump-version.sh minor   # Bump minor, reset patch (2.0.5 → 2.1.0)
#   ./bump-version.sh major   # Bump major, reset minor+patch (2.1.5 → 3.0.0)
#   ./bump-version.sh build   # Only bump build number, keep version

set -e

PROJECT_FILE="MealPlanner.xcodeproj/project.pbxproj"

# Get current version (strip any quotes)
CURRENT_VERSION=$(grep "MARKETING_VERSION" "$PROJECT_FILE" | head -1 | sed 's/.*= \(.*\);/\1/' | sed 's/"//g')
CURRENT_BUILD=$(grep "CURRENT_PROJECT_VERSION" "$PROJECT_FILE" | head -1 | sed 's/.*= \(.*\);/\1/' | sed 's/"//g')

# Parse version components
MAJOR=$(echo "$CURRENT_VERSION" | cut -d. -f1)
MINOR=$(echo "$CURRENT_VERSION" | cut -d. -f2)
PATCH=$(echo "$CURRENT_VERSION" | cut -d. -f3)
BUILD=$((CURRENT_BUILD + 1))

# Handle arguments
case "$1" in
    major)
        MAJOR=$((MAJOR + 1))
        MINOR=0
        PATCH=0
        echo "Bumping MAJOR: $CURRENT_VERSION → $MAJOR.$MINOR.$PATCH"
        ;;
    minor)
        MINOR=$((MINOR + 1))
        PATCH=0
        echo "Bumping MINOR: $CURRENT_VERSION → $MAJOR.$MINOR.$PATCH"
        ;;
    build)
        # Only bump build number, keep version
        echo "Bumping BUILD only: $CURRENT_VERSION ($CURRENT_BUILD → $BUILD)"
        sed -i '' "s/CURRENT_PROJECT_VERSION = [0-9]*;/CURRENT_PROJECT_VERSION = $BUILD;/g" "$PROJECT_FILE"
        echo "✅ Version: $CURRENT_VERSION (build $BUILD)"
        exit 0
        ;;
    *)
        # Default: bump patch + build (for each push to main)
        PATCH=$((PATCH + 1))
        echo "Bumping PATCH: $CURRENT_VERSION → $MAJOR.$MINOR.$PATCH"
        ;;
esac

# Apply the version bump
NEW_VERSION="$MAJOR.$MINOR.$PATCH"
sed -i '' "s/MARKETING_VERSION = .*;/MARKETING_VERSION = $NEW_VERSION;/g" "$PROJECT_FILE"
sed -i '' "s/CURRENT_PROJECT_VERSION = [0-9]*;/CURRENT_PROJECT_VERSION = $BUILD;/g" "$PROJECT_FILE"
echo "✅ Version: $NEW_VERSION (build $BUILD)"
