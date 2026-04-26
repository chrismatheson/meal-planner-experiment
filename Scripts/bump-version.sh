#!/bin/bash
# Bump version script for MealPlanner
# Updates MARKETING_VERSION (X.Y.Z) and CURRENT_PROJECT_VERSION (git commit count)
#
# Apple's CFBundleShortVersionString only allows X.Y.Z format, so we use:
# - MARKETING_VERSION: Semantic version (2.0.0)
# - CURRENT_PROJECT_VERSION: Build number from git commit count (89)
# - App displays: "2.0.0 (89)"

set -e

PROJECT_FILE="MealPlanner.xcodeproj/project.pbxproj"
BUILD_NUM=$(git rev-list --count HEAD)

# Get current version (strip any quotes)
CURRENT_VERSION=$(grep "MARKETING_VERSION" "$PROJECT_FILE" | head -1 | sed 's/.*= \(.*\);/\1/' | sed 's/"//g')

# Parse version components
MAJOR=$(echo "$CURRENT_VERSION" | cut -d. -f1)
MINOR=$(echo "$CURRENT_VERSION" | cut -d. -f2)
PATCH=$(echo "$CURRENT_VERSION" | cut -d. -f3)

# Handle arguments
case "$1" in
    major)
        MAJOR=$((MAJOR + 1))
        MINOR=0
        PATCH=0
        echo "Bumping MAJOR: $CURRENT_VERSION -> $MAJOR.$MINOR.$PATCH"
        ;;
    minor)
        MINOR=$((MINOR + 1))
        PATCH=0
        echo "Bumping MINOR: $CURRENT_VERSION -> $MAJOR.$MINOR.$PATCH"
        ;;
    patch)
        PATCH=$((PATCH + 1))
        echo "Bumping PATCH: $CURRENT_VERSION -> $MAJOR.$MINOR.$PATCH"
        ;;
    *)
        # Default: just update build number, keep version
        echo "Updating build number: $CURRENT_VERSION ($BUILD_NUM)"
        sed -i '' "s/CURRENT_PROJECT_VERSION = [0-9]*;/CURRENT_PROJECT_VERSION = $BUILD_NUM;/g" "$PROJECT_FILE"
        echo "✅ Version: $CURRENT_VERSION (build $BUILD_NUM)"
        exit 0
        ;;
esac

# Apply the version bump
NEW_VERSION="$MAJOR.$MINOR.$PATCH"
sed -i '' "s/MARKETING_VERSION = .*;/MARKETING_VERSION = $NEW_VERSION;/g" "$PROJECT_FILE"
sed -i '' "s/CURRENT_PROJECT_VERSION = [0-9]*;/CURRENT_PROJECT_VERSION = $BUILD_NUM;/g" "$PROJECT_FILE"
echo "✅ Version: $NEW_VERSION (build $BUILD_NUM)"
