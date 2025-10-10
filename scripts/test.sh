#!/bin/bash
set -euo pipefail

# FreezeRay Test Suite
# Validates both SPM and Xcode build paths

echo "🧪 FreezeRay Test Suite"
echo "======================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

FAILURES=0

# Test 1: SPM build
echo -e "${BLUE}▶ Test 1: SPM build (macOS)${NC}"
if swift build -c debug; then
    echo -e "${GREEN}✅ SPM build passed${NC}"
else
    echo -e "${RED}❌ SPM build failed${NC}"
    FAILURES=$((FAILURES + 1))
fi
echo ""

# Test 2: SPM tests
echo -e "${BLUE}▶ Test 2: SPM tests (macOS)${NC}"
if swift test; then
    echo -e "${GREEN}✅ SPM tests passed${NC}"
else
    echo -e "${RED}❌ SPM tests failed${NC}"
    FAILURES=$((FAILURES + 1))
fi
echo ""

# Test 3: Xcode build for iOS
echo -e "${BLUE}▶ Test 3: Xcode build (iOS Simulator)${NC}"
cd TestApp
set +e  # Temporarily disable exit-on-error
OUTPUT=$(xcodebuild -scheme TestApp -destination 'generic/platform=iOS Simulator' build 2>&1)
EXIT_CODE=$?
set -e  # Re-enable exit-on-error
if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✅ iOS build passed${NC}"
else
    echo -e "${RED}❌ iOS build failed (exit code: $EXIT_CODE)${NC}"
    echo "$OUTPUT"
    FAILURES=$((FAILURES + 1))
fi
cd ..
echo ""

# Test 4: Xcode tests on iOS Simulator
echo -e "${BLUE}▶ Test 4: Xcode tests (iOS Simulator)${NC}"
cd TestApp
# Use latest available iOS Simulator for testing (tests require concrete device)
set +e  # Temporarily disable exit-on-error
OUTPUT=$(xcodebuild test -scheme TestApp -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1)
EXIT_CODE=$?
set -e  # Re-enable exit-on-error
if [ $EXIT_CODE -eq 0 ] && echo "$OUTPUT" | grep -q "Test Suite.*passed"; then
    echo -e "${GREEN}✅ iOS Simulator Xcode tests passed${NC}"
else
    echo -e "${RED}❌ iOS Simulator Xcode tests failed (exit code: $EXIT_CODE)${NC}"
    echo "$OUTPUT"
    FAILURES=$((FAILURES + 1))
fi
cd ..
echo ""

# Summary
echo "======================="
if [ $FAILURES -eq 0 ]; then
    echo -e "${GREEN}✅ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ $FAILURES test(s) failed${NC}"
    exit 1
fi
