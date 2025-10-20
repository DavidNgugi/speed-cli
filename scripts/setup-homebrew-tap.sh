#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}Setting up Homebrew tap for Speed CLI...${NC}"

# Check if we're in the right directory
if [ ! -f "VERSION" ]; then
    echo -e "${RED}Error: Please run this script from the speed-cli root directory${NC}"
    exit 1
fi

# Get current version
VERSION=$(cat VERSION)
echo -e "${BLUE}Current version: ${VERSION}${NC}"

# Create GitHub repository for the tap (if it doesn't exist)
echo -e "${YELLOW}Setting up Homebrew tap repository...${NC}"

# Check if GitHub CLI is installed
if ! command -v gh &> /dev/null; then
    echo -e "${RED}Error: GitHub CLI (gh) is required but not installed.${NC}"
    echo "Please install it with: brew install gh"
    exit 1
fi

# Check if user is logged in to GitHub
if ! gh auth status &> /dev/null; then
    echo -e "${RED}Error: Please log in to GitHub CLI first:${NC}"
    echo "Run: gh auth login"
    exit 1
fi

# Create the tap repository
TAP_REPO="homebrew-speed-cli"
echo -e "${BLUE}Creating GitHub repository: ${TAP_REPO}${NC}"

# Check if repository already exists
if gh repo view "$TAP_REPO" &> /dev/null; then
    echo -e "${YELLOW}Repository ${TAP_REPO} already exists${NC}"
else
    gh repo create "$TAP_REPO" --public --description "Homebrew tap for Speed CLI - Internet speed monitoring tool"
    echo -e "${GREEN}Repository created: https://github.com/$(gh api user --jq .login)/${TAP_REPO}${NC}"
fi

# Clone the tap repository
TAP_DIR="../${TAP_REPO}"
if [ -d "$TAP_DIR" ]; then
    echo -e "${YELLOW}Tap directory already exists, updating...${NC}"
    cd "$TAP_DIR"
    git pull origin main
    cd - > /dev/null
else
    echo -e "${BLUE}Cloning tap repository...${NC}"
    git clone "https://github.com/$(gh api user --jq .login)/${TAP_REPO}.git" "$TAP_DIR"
fi

# Copy formula to the tap
echo -e "${BLUE}Copying formula to tap...${NC}"
cp "homebrew-tap/Formula/speed-cli.rb" "$TAP_DIR/Formula/"
cp "homebrew-tap/README.md" "$TAP_DIR/"

# Calculate SHA256 for the formula
echo -e "${BLUE}Calculating SHA256 for version ${VERSION}...${NC}"
ARCHIVE_URL="https://github.com/DavidNgugi/speed-cli/archive/refs/tags/v${VERSION}.tar.gz"
SHA256=$(curl -sL "$ARCHIVE_URL" | shasum -a 256 | cut -d' ' -f1)

# Update the formula with the correct SHA256
sed -i.bak "s/sha256 \"\"/sha256 \"$SHA256\"/" "$TAP_DIR/Formula/speed-cli.rb"
rm "$TAP_DIR/Formula/speed-cli.rb.bak"

# Update the formula with the correct version
sed -i.bak "s/v1.0.0/v${VERSION}/g" "$TAP_DIR/Formula/speed-cli.rb"
rm "$TAP_DIR/Formula/speed-cli.rb.bak"

echo -e "${GREEN}SHA256: ${SHA256}${NC}"

# Commit and push changes
cd "$TAP_DIR"
git add .
git commit -m "Add Speed CLI formula v${VERSION}" || echo "No changes to commit"
git push origin main

echo -e "${GREEN}Homebrew tap setup complete!${NC}"
echo ""
echo -e "${BLUE}To use the tap:${NC}"
echo "1. Add the tap: brew tap $(gh api user --jq .login)/speed-cli"
echo "2. Install: brew install speed-cli"
echo ""
echo -e "${BLUE}Tap repository: https://github.com/$(gh api user --jq .login)/${TAP_REPO}${NC}"

cd - > /dev/null
