# ADR-003: Dynamic Test Generation

**Status:** Accepted
**Date:** 2025-10-10
**Deciders:** Core Team
**Related:** ADR-001 (CLI Architecture)

## Context

To freeze a schema, we need to execute code in an iOS simulator that:
1. Calls the macro-generated `__freezeray_freeze_X_Y_Z()` function
2. Creates a ModelContainer with the schema
3. Exports SQLite database and schema information

### Challenge: How to Execute Code in Simulator?

**Problem:** VersionedSchema enums are type definitions with no runtime presence. The app's normal execution path doesn't touch schema types, and macro-generated freeze functions are static methods requiring explicit invocation.

**Options:**
1. Modify app entry point to call freeze functions
2. Create pre-made test files for every version
3. Generate test files dynamically when needed

## Decision

**CLI generates temporary test files on-the-fly** that Xcode's folder references auto-discover.

### Workflow

1. **CLI discovers `@FreezeSchema(version: "3.0.0")` via SwiftSyntax AST parsing**
2. **CLI generates temporary test file:**
   ```swift
   // FreezeRayTestAppTests/FreezeSchemaV3_0_0_Test.swift
   import XCTest
   import FreezeRay
   @testable import FreezeRayTestApp

   final class FreezeSchemaV3_0_0_Test: XCTestCase {
       func testFreezeSchemaV3_0_0() throws {
           try AppSchemaV3.__freezeray_freeze_3_0_0()
       }
   }
   ```
3. **Xcode folder references** (blue folders) auto-discover new `.swift` files
4. **CLI runs `xcodebuild test`** (single command - builds AND runs):
   ```bash
   xcodebuild -project ... test \
     -only-testing:FreezeRayTestAppTests/FreezeSchemaV3_0_0_Test
   ```
5. **Test executes in iOS simulator**, writes fixtures
6. **Runtime exports to `/tmp`** (see ADR-002)
7. **CLI extracts fixtures** from `/tmp`
8. **CLI deletes temporary test file** (cleanup via `defer` block)

## Consequences

### Positive

- ✅ Works with any version number format (1.0.1, 2.5.3, etc.)
- ✅ No pre-made test files to maintain in FreezeRay package
- ✅ XCTest provides standard, reliable code execution harness
- ✅ Works with standard `xcodebuild` workflows
- ✅ No modification to app's entry point required
- ✅ Automatic cleanup (temp file deleted after execution)
- ✅ Test bundle provides proper sandboxed environment

### Negative

- ❌ Test target must have at least one permanent Swift file (empty test target = no executable)
- ❌ Test bundle vs app bundle distinction can be confusing
- ❌ Requires understanding of Xcode folder references

### Neutral

- XCTest is used as code execution harness, not for actual testing
- Generated test file is temporary, not committed to repo
- Convention-based naming: `FreezeSchemaV{version}_Test`

## Key Discoveries

### Test Bundle Container vs App Container

**Critical insight:** Unit tests run in **test bundle sandbox**, not app sandbox:
- Test bundle ID: `{AppBundleID}Tests` (e.g., `com.example.AppTests`)
- Separate container from app
- Ephemeral XCTestDevices directory (see ADR-002)

### Empty Test Target Problem

**Problem:** Test target with zero Swift files produces empty bundle (no executable).

**Error:** `"The bundle 'FreezeRayTestAppTests' couldn't be loaded because its executable couldn't be located."`

**Solution:** Test target must have at least one permanent Swift file:
```swift
// FreezeRayTests.swift (permanent file)
import XCTest

final class FreezeRayTests: XCTestCase {
    // Ensures test bundle has executable
    // CLI-generated tests are added alongside this file
}
```

### Build Strategy

**Initially tried:** Separate `build-for-testing` + `test-without-building`
**Problem:** Newly generated files weren't compiled

**Solution:** Use single `xcodebuild test` command:
- Ensures new files are compiled
- More reliable
- Simpler

## Alternatives Considered

### 1. Pre-Made Test Files

**Decision:** Rejected

Ship pre-made test files like `FreezeV1_0_0_Test.swift` with FreezeRay package.

**Pros:**
- No generation needed
- Always available

**Cons:**
- Can't cover all possible version numbers
- Bloats package
- Requires maintenance for each version pattern

### 2. Modify App Entry Point

**Decision:** Rejected

Inject freeze call into app's `@main` with environment variable:
```swift
if ProcessInfo.processInfo.environment["FREEZE_VERSION"] != nil {
    // Call freeze function
    exit(0)
}
```

**Pros:**
- App-native execution

**Cons:**
- Modifies production code for tooling
- Fragile
- Doesn't work well with SwiftUI apps
- Hard to coordinate with CLI

### 3. Swift Package Manager Test Target

**Decision:** Rejected

Use SPM test target instead of Xcode test bundle.

**Pros:**
- Could work without Xcode project

**Cons:**
- Doesn't work for Xcode-based projects (most iOS apps)
- SPM tests run differently than Xcode tests
- Less control over simulator environment

## Implementation

**File:** `Sources/freezeray-cli/Commands/FreezeCommand.swift`

```swift
func generateFreezeTest(
    version: String,
    schemaType: String,
    appTarget: String,
    testTargetDir: URL
) -> URL {
    let versionSafe = version.replacingOccurrences(of: ".", with: "_")

    let testContent = """
    import XCTest
    import FreezeRay
    @testable import \(appTarget)

    final class FreezeSchemaV\(versionSafe)_Test: XCTestCase {
        func testFreezeSchemaV\(versionSafe)() throws {
            try \(schemaType).__freezeray_freeze_\(versionSafe)()
        }
    }
    """

    let testFile = testTargetDir.appendingPathComponent("FreezeSchemaV\(versionSafe)_Test.swift")
    try testContent.write(to: testFile, atomically: true, encoding: .utf8)

    return testFile
}
```

**Cleanup:**
```swift
defer {
    try? FileManager.default.removeItem(at: testFile)
}
```

## References

- Implementation: `Sources/freezeray-cli/Commands/FreezeCommand.swift`
- SimulatorManager: `Sources/freezeray-cli/Simulator/SimulatorManager.swift`
- Sprint: project/sprints/v0.4.0-sprint_1-freeze-command.md
- Related: ADR-002 (fixture extraction from test bundle)
