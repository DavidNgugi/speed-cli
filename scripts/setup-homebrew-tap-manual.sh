#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}Manual Homebrew Tap Setup for Speed CLI${NC}"
echo ""

# Check if we're in the right directory
if [ ! -f "VERSION" ]; then
    echo -e "${RED}Error: Please run this script from the speed-cli root directory${NC}"
    exit 1
fi

# Get current version
VERSION=$(cat VERSION)
echo -e "${BLUE}Current version: ${VERSION}${NC}"

# Create the tap directory structure
TAP_DIR="../homebrew-speed-cli"
echo -e "${BLUE}Creating tap directory structure...${NC}"

mkdir -p "$TAP_DIR/Formula"

# Copy formula and README
echo -e "${BLUE}Copying formula files...${NC}"
cp "homebrew-tap/Formula/speed-cli.rb" "$TAP_DIR/Formula/"
cp "homebrew-tap/README.md" "$TAP_DIR/"

# Initialize git repository
cd "$TAP_DIR"
echo -e "${BLUE}Initializing git repository...${NC}"
git init
git add .
git commit -m "Initial commit: Add Speed CLI formula v${VERSION}"

echo -e "${GREEN}Local tap repository created at: $(pwd)${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Create a new GitHub repository named 'homebrew-speed-cli'"
echo "2. Add the remote origin:"
echo "   git remote add origin https://github.com/YOUR_USERNAME/homebrew-speed-cli.git"
echo "3. Push to GitHub:"
echo "   git push -u origin main"
echo ""
echo -e "${BLUE}GitHub repository setup:${NC}"
echo "1. Go to https://github.com/new"
echo "2. Repository name: homebrew-speed-cli"
echo "3. Description: Homebrew tap for Speed CLI - Internet speed monitoring tool"
echo "4. Make it public"
echo "5. Don't initialize with README (we already have one)"
echo ""
echo -e "${BLUE}After creating the GitHub repository, run:${NC}"
echo "cd $TAP_DIR"
echo "git remote add origin https://github.com/YOUR_USERNAME/homebrew-speed-cli.git"
echo "git push -u origin main"
echo ""
echo -e "${GREEN}Then users can install with:${NC}"
echo "brew tap YOUR_USERNAME/speed-cli"
echo "brew install speed-cli"
