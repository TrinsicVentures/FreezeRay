#!/bin/bash
set -e  # Exit on error

echo "🧪 FreezeRay E2E Integration Tests"
echo "===================================="
echo ""

# 1. Build the CLI
echo "📦 Building CLI..."
swift build -c debug
CLI_PATH=".build/debug/freezeray"

if [ ! -f "$CLI_PATH" ]; then
    echo "❌ CLI binary not found at $CLI_PATH"
    exit 1
fi
echo "✅ CLI built successfully"
echo ""

# 2. Clean test environment
echo "🧹 Cleaning test environment..."
cd FreezeRayTestApp
rm -rf FreezeRay/Fixtures FreezeRay/Tests
rm -rf /tmp/FreezeRay
echo "✅ Test environment cleaned"
echo ""

# 3. Test: Freeze version 1.0.0
echo "🔹 Test: freezeray freeze 1.0.0"
../"$CLI_PATH" freeze 1.0.0

# Verify fixtures created
if [ ! -d "FreezeRay/Fixtures/1.0.0" ]; then
    echo "❌ Fixtures not created for 1.0.0"
    exit 1
fi

# Verify required files exist
for file in "App-1_0_0.sqlite" "schema-1_0_0.json" "schema-1_0_0.sql" "schema-1_0_0.sha256"; do
    if [ ! -f "FreezeRay/Fixtures/1.0.0/$file" ]; then
        echo "❌ Required fixture file missing: $file"
        exit 1
    fi
done

# Verify drift test scaffolded
if [ ! -f "FreezeRay/Tests/AppSchemaV1_DriftTests.swift" ]; then
    echo "❌ Drift test not scaffolded"
    exit 1
fi

echo "✅ Version 1.0.0 frozen successfully"
echo ""

# 4. Test: Freeze version 2.0.0 (with migration test)
echo "🔹 Test: freezeray freeze 2.0.0"
../"$CLI_PATH" freeze 2.0.0

# Verify fixtures created
if [ ! -d "FreezeRay/Fixtures/2.0.0" ]; then
    echo "❌ Fixtures not created for 2.0.0"
    exit 1
fi

# Verify drift test scaffolded
if [ ! -f "FreezeRay/Tests/AppSchemaV2_DriftTests.swift" ]; then
    echo "❌ Drift test not scaffolded for 2.0.0"
    exit 1
fi

# Verify migration test scaffolded
if [ ! -f "FreezeRay/Tests/MigrateV1_0_0toV2_0_0_Tests.swift" ]; then
    echo "❌ Migration test not scaffolded"
    exit 1
fi

echo "✅ Version 2.0.0 frozen successfully"
echo ""

# 5. Test: Scaffolded tests compile
echo "🔹 Test: Scaffolded tests compile"
xcodebuild build-for-testing \
    -project FreezeRayTestApp.xcodeproj \
    -scheme FreezeRayTestApp \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    > /dev/null 2>&1

echo "✅ Scaffolded tests compile successfully"
echo ""

# 6. Test: Force flag overwrites existing fixtures
echo "🔹 Test: Force flag overwrites fixtures"
ORIGINAL_MTIME=$(stat -f %m "FreezeRay/Fixtures/1.0.0")
sleep 1
../"$CLI_PATH" freeze 1.0.0 --force > /dev/null 2>&1
NEW_MTIME=$(stat -f %m "FreezeRay/Fixtures/1.0.0")

if [ "$ORIGINAL_MTIME" = "$NEW_MTIME" ]; then
    echo "❌ Fixtures were not overwritten with --force"
    exit 1
fi

echo "✅ Force flag works correctly"
echo ""

# 7. Test: Error when already frozen (without --force)
echo "🔹 Test: Error when freezing existing version"
if ../"$CLI_PATH" freeze 1.0.0 > /dev/null 2>&1; then
    echo "❌ Should have failed when freezing existing version"
    exit 1
fi

echo "✅ Correctly errors on duplicate freeze"
echo ""

# Summary
echo "===================================="
echo "✅ All E2E tests passed!"
echo ""
echo "Tests run:"
echo "  ✓ CLI builds successfully"
echo "  ✓ freeze 1.0.0 creates fixtures + drift test"
echo "  ✓ freeze 2.0.0 creates fixtures + drift test + migration test"
echo "  ✓ Scaffolded tests compile in iOS project"
echo "  ✓ --force flag overwrites existing fixtures"
echo "  ✓ Error handling for duplicate freeze"
