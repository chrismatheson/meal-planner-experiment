#!/bin/bash
# Bump version script for MealPlanner
# Updates MARKETING_VERSION and CURRENT_PROJECT_VERSION based on git commit count

set -e

PROJECT_FILE="MealPlanner.xcodeproj/project.pbxproj"
BUILD_NUM=$(git rev-list --count HEAD)

# Get current base version (without -preN suffix and quotes)
CURRENT_VERSION=$(grep "MARKETING_VERSION" "$PROJECT_FILE" | head -1 | sed 's/.*= \(.*\);/\1/' | sed 's/"//g' | sed 's/-pre[0-9]*//')

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
    release)
        # Remove -preN suffix for stable release
        NEW_VERSION="$MAJOR.$MINOR.$PATCH"
        echo "Creating stable release: $NEW_VERSION"
        sed -i '' "s/MARKETING_VERSION = .*;/MARKETING_VERSION = $NEW_VERSION;/g" "$PROJECT_FILE"
        sed -i '' "s/CURRENT_PROJECT_VERSION = [0-9]*;/CURRENT_PROJECT_VERSION = $BUILD_NUM;/g" "$PROJECT_FILE"
        echo "✅ Version set to $NEW_VERSION (build $BUILD_NUM)"
        exit 0
        ;;
    *)
        # Default: just update build number with current version
        NEW_VERSION="$MAJOR.$MINOR.$PATCH-pre$BUILD_NUM"
        echo "Updating pre-release: $NEW_VERSION (build $BUILD_NUM)"
        sed -i '' "s/MARKETING_VERSION = .*;/MARKETING_VERSION = $NEW_VERSION;/g" "$PROJECT_FILE"
        sed -i '' "s/CURRENT_PROJECT_VERSION = [0-9]*;/CURRENT_PROJECT_VERSION = $BUILD_NUM;/g" "$PROJECT_FILE"
        echo "✅ Version set to $NEW_VERSION"
        exit 0
        ;;
esac

# Apply the version bump
NEW_VERSION="$MAJOR.$MINOR.$PATCH-pre$BUILD_NUM"
sed -i '' "s/MARKETING_VERSION = .*;/MARKETING_VERSION = $NEW_VERSION;/g" "$PROJECT_FILE"
sed -i '' "s/CURRENT_PROJECT_VERSION = [0-9]*;/CURRENT_PROJECT_VERSION = $BUILD_NUM;/g" "$PROJECT_FILE"
echo "✅ Version set to $NEW_VERSION (build $BUILD_NUM)"
