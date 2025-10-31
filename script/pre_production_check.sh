#!/bin/bash
set -e

echo "========================================="
echo "Flutter Pre-Production Health Check"
echo "========================================="

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check 1: Flutter & Dart
echo -e "${YELLOW}[1/8] Checking Flutter & Dart versions...${NC}"
flutter --version
dart --version

# Check 2: Dependencies
echo -e "${YELLOW}[2/8] Installing dependencies...${NC}"
flutter clean
flutter pub get --enforce-lockfile

# Check 3: Code Analysis
echo -e "${YELLOW}[3/8] Running flutter analyze...${NC}"
flutter analyze || exit 1
echo -e "${GREEN}✓ Analysis passed${NC}"

# Check 4: Code Format
echo -e "${YELLOW}[4/8] Checking code format...${NC}"
dart format --set-exit-if-changed lib/ test/ 2>/dev/null || {
    echo -e "${RED}✗ Format issues found. Run: dart format lib/ test/${NC}"
    exit 1
}

# Check 5: Unit Tests
echo -e "${YELLOW}[5/8] Running unit tests...${NC}"
flutter test --no-pub --coverage || exit 1
echo -e "${GREEN}✓ Tests passed${NC}"

# Check 6: Security Audit
echo -e "${YELLOW}[6/8] Running security audit...${NC}"
dart pub audit

# Check 7: Build Config
echo -e "${YELLOW}[7/8] Verifying build configuration...${NC}"
flutter doctor -v
echo -e "${GREEN}✓ Build environment OK${NC}"

# Check 8: Version Check
echo -e "${YELLOW}[8/8] Verifying version configuration...${NC}"
VERSION=$(grep "^version:" pubspec.yaml | head -1 | awk '{print $2}')
echo -e "${GREEN}✓ App version: $VERSION${NC}"

echo -e "\n${GREEN}=========================================${NC}"
echo -e "${GREEN}All pre-production checks PASSED! ✓${NC}"
echo -e "${GREEN}Ready to build for production${NC}"
echo -e "${GREEN}=========================================${NC}"
