#!/bin/bash
#
# Release script for Speed CLI
# Usage: ./scripts/release.sh [version]
#

set -e

# Get version from VERSION file or argument
if [ -n "$1" ]; then
    VERSION="$1"
else
    VERSION=$(cat VERSION)
fi

echo "Creating release v${VERSION}..."

# Check if we're on main branch
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "main" ]; then
    echo "Error: Must be on main branch to create release"
    exit 1
fi

# Check if working directory is clean
if [ -n "$(git status --porcelain)" ]; then
    echo "Error: Working directory is not clean. Commit changes first."
    exit 1
fi

# Update VERSION file
echo "$VERSION" > VERSION

# Update version in scripts
sed -i.bak "s/VERSION=\"[^\"]*\"/VERSION=\"$VERSION\"/g" src/speed_cli.sh
sed -i.bak "s/VERSION=\"[^\"]*\"/VERSION=\"$VERSION\"/g" install.sh
rm -f src/speed_cli.sh.bak install.sh.bak

# Update README version badge
sed -i.bak "s/version-[^-]*-blue/version-$VERSION-blue/g" README.md
rm -f README.md.bak

# Commit version changes
git add VERSION src/speed_cli.sh install.sh README.md
git commit -m "Bump version to v$VERSION"

# Create tag
git tag -a "v$VERSION" -m "Release v$VERSION"

echo "Release v$VERSION created!"
echo ""
echo "Next steps:"
echo "1. Push to GitHub:"
echo "   git push origin main"
echo "   git push origin v$VERSION"
echo ""
echo "2. Create GitHub release:"
echo "   - Go to https://github.com/DavidNgugi/speed-cli/releases"
echo "   - Click 'Create a new release'"
echo "   - Tag: v$VERSION"
echo "   - Title: Speed CLI v$VERSION"
echo "   - Description: See CHANGELOG.md for details"
