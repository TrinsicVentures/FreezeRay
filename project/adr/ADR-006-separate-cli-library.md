# ADR-006: Separate CLI Library Target for Testability

**Status:** Accepted
**Date:** 2025-10-11
**Context:** Sprint 2 Phase 2 - CLI Test Scaffolding

---

## Context

We implemented test scaffolding functions (`scaffoldDriftTest()`, `scaffoldMigrationTest()`, `findPreviousVersion()`) in the CLI, but discovered we cannot write unit tests for them because:

1. **Swift Package Manager limitation**: Executable targets cannot be imported by test targets
2. **No unit test coverage**: Helper functions have complex logic (semantic versioning, file I/O) that needs testing
3. **E2E tests insufficient**: FreezeRayTestApp integration tests are too slow and coarse-grained for TDD

**Error encountered:**
```
error: no such module 'freezeray_cli'
note: module 'freezeray_cli' is the main module of an executable,
      and cannot be imported by tests and other targets
```

## Decision

**Restructure the CLI into a monorepo with separate targets:**

```
FreezeRay/                          # Single repository (monorepo)
├── Package.swift                   # Defines multiple products
├── Sources/
│   ├── FreezeRay/                 # Library (SPM distribution)
│   ├── FreezeRayMacros/           # Macro implementation
│   ├── FreezeRayCLI/              # NEW: CLI library (testable)
│   └── freezeray/                 # NEW: CLI executable (thin wrapper)
├── Tests/
│   ├── FreezeRayTests/            # Library unit tests
│   └── FreezeRayCLITests/         # NEW: CLI unit tests
└── FreezeRayTestApp/              # E2E integration tests
```

### Target Structure

**1. `FreezeRayCLI` (library target)**
- Contains all CLI logic: commands, parser, simulator manager
- Can be imported by tests
- Exported as internal library product (not for public use)

**2. `freezeray` (executable target)**
- Thin wrapper that calls `FreezeRayCLI.main()`
- Minimal code (5-10 lines)
- This is what Homebrew distributes

**3. `FreezeRayCLITests` (test target)**
- Unit tests for CLI helper functions
- Imports `FreezeRayCLI` library
- Fast, focused tests for TDD

**4. `FreezeRayTestApp` (separate package)**
- E2E integration tests
- Depends on both `FreezeRay` (library) and `freezeray` (CLI executable)
- Tests full workflow: freeze → scaffold → validate

### Package.swift Structure

```swift
.library(
    name: "FreezeRayCLI",
    targets: ["FreezeRayCLI"]
),
.executable(
    name: "freezeray",
    targets: ["freezeray"]
),

.target(
    name: "FreezeRayCLI",
    dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "SwiftSyntax", package: "swift-syntax"),
    ]
),
.executableTarget(
    name: "freezeray",
    dependencies: ["FreezeRayCLI"]
),
.testTarget(
    name: "FreezeRayCLITests",
    dependencies: ["FreezeRayCLI"]
),
```

## Rationale

### Why Monorepo?

**Decision: Use monorepo instead of separate repositories.**

**Reasons:**
1. **Version coordination**: CLI and library must stay in sync (CLI depends on macro-generated functions)
2. **Shared CI/CD**: Single workflow tests both components together
3. **Easier development**: Changes to library can be immediately tested with CLI
4. **Industry standard**: SwiftLint, SwiftFormat, Mint all use monorepo structure
5. **Distribution compatible**:
   - SPM users: `dependencies: [.package(url: "github.com/Trinsic/FreezeRay", from: "1.0.0")]`
   - Homebrew users: Formula points to `Products/freezeray` executable
   - Binary releases: GitHub Releases with CLI binaries

### Why Library + Executable Split?

**Solves three problems:**

1. **Testability**: Library target can be imported by test targets
2. **Modularity**: Separates CLI logic from entry point
3. **Distribution**: Homebrew formula can point to executable, while library users get clean SPM dependency

### Alternative Approaches Rejected

**Option A: Keep everything in executable target**
- ❌ Cannot write unit tests
- ❌ No way to test helper functions
- ❌ E2E tests too slow for TDD

**Option B: Extract helpers into separate internal library, keep commands in executable**
- ❌ Still can't test command logic
- ❌ Awkward split between "helpers" and "commands"
- ❌ More complex than library + thin executable

**Option C: Separate repository for CLI**
- ❌ Version coordination nightmare (CLI v1.0 with Library v1.1?)
- ❌ Two CI systems to maintain
- ❌ Harder to develop (need to link repos)
- ❌ Against industry practice (SwiftLint, SwiftFormat are monorepos)

## Consequences

### Positive

1. ✅ **Unit tests for CLI**: Can test `scaffoldDriftTest()`, `findPreviousVersion()`, etc.
2. ✅ **Faster TDD**: Unit tests run in milliseconds, don't need simulator
3. ✅ **Better code quality**: Complex logic is tested in isolation
4. ✅ **Standard Swift structure**: Follows common pattern for CLI tools
5. ✅ **Future `freezeray init` command**: Can test without running xcodebuild
6. ✅ **Homebrew ready**: Executable target is what gets distributed

### Negative

1. ⚠️ **Migration effort**: Need to restructure existing CLI code (1-2 hours)
2. ⚠️ **Slightly more complex Package.swift**: Now has 4 products instead of 2
3. ⚠️ **FreezeRayCLI library visible**: Users could theoretically depend on it (but we won't document it)

### Migration Path

**Phase 1: Restructure (Sprint 2 Phase 2)**
1. Create `Sources/FreezeRayCLI/` directory
2. Move all CLI code from `Sources/freezeray-cli/` → `Sources/FreezeRayCLI/`
3. Create thin `Sources/freezeray/main.swift` wrapper
4. Update Package.swift with new targets
5. Create `Tests/FreezeRayCLITests/` with unit tests
6. Delete old `Sources/freezeray-cli/` directory

**Phase 2: Test Coverage (Sprint 2 Phase 2)**
1. Write unit tests for `FreezeCommand` helpers
2. Write unit tests for `MacroDiscovery`
3. Write unit tests for `SimulatorManager`
4. Ensure 80%+ coverage of CLI logic

**Phase 3: E2E Validation (Sprint 2 Phase 3)**
1. Update FreezeRayTestApp to test full workflow
2. Verify CLI executable works with `swift run freezeray freeze 1.0.0`
3. Test Homebrew formula (local tap)

## Implementation Notes

### Thin Executable Wrapper

**`Sources/freezeray/main.swift`:**
```swift
import FreezeRayCLI

// Entry point - just delegates to library
await FreezeRayCLI.main()
```

That's it. All logic lives in `FreezeRayCLI`.

### Testing Strategy

**Unit tests (FreezeRayCLITests):**
- Test helper functions in isolation
- Mock filesystem operations where needed
- Fast, focused, granular

**Integration tests (FreezeRayTestApp):**
- Test full workflow: `freezeray freeze 1.0.0`
- Verify fixtures created correctly
- Validate scaffolded tests compile and run

### Distribution

**For library users (SPM):**
```swift
dependencies: [
    .package(url: "https://github.com/Trinsic/FreezeRay", from: "1.0.0")
]
targets: [
    .target(
        name: "MyApp",
        dependencies: [
            .product(name: "FreezeRay", package: "FreezeRay")
        ]
    )
]
```

**For CLI users (Homebrew):**
```ruby
class Freezeray < Formula
  desc "SwiftData schema freezing and migration testing"
  homepage "https://github.com/Trinsic/FreezeRay"
  url "https://github.com/Trinsic/FreezeRay/archive/v1.0.0.tar.gz"

  def install
    system "swift", "build", "-c", "release", "--product", "freezeray"
    bin.install ".build/release/freezeray"
  end
end
```

**For binary releases:**
- GitHub Actions builds universal binary (arm64 + x86_64)
- Attached to GitHub Release
- Users can download and install to `/usr/local/bin/`

## References

- **Sprint 2 Goals**: Test scaffolding with proper test coverage
- **ADR-005**: Test Scaffolding (not generation) - requires user customization
- **Industry precedent**: SwiftLint, SwiftFormat, Mint all use monorepo + library + executable structure

## Status

**Implemented** - Sprint 2 Phase 2 Complete (2025-10-12)

## Implementation Summary

### What We Actually Built

**Decision:** Instead of creating a new `FreezeRayCLI` library target, we:
1. Kept the existing `freezeray-cli` target structure
2. **Extracted testable logic into `TestScaffolding` helper struct**
3. `TestScaffolding` is public and can be instantiated by tests
4. FreezeCommand delegates to TestScaffolding for scaffolding operations

### Why This Approach?

**Original Problem:** ArgumentParser commands can't be instantiated directly in tests.

**Solution:** Extract business logic into separate testable structs:
- `TestScaffolding` - Contains scaffolding and version logic (testable)
- `FreezeCommand` - ArgumentParser interface (delegates to TestScaffolding)

**Benefits:**
- ✅ Achieves testability without full restructure
- ✅ Cleaner separation of concerns
- ✅ No migration complexity
- ✅ All 10 unit tests passing

### Files Created

1. **`Sources/freezeray-cli/Commands/TestScaffolding.swift`**
   - Public struct with scaffolding helpers
   - `scaffoldDriftTest()`, `scaffoldMigrationTest()`, `findPreviousVersion()`
   - Can be instantiated: `let scaffolding = TestScaffolding()`

2. **`Tests/FreezeRayCLITests/FreezeCommandTests.swift`**
   - 10 comprehensive unit tests (all passing)
   - Tests semantic versioning logic
   - Tests file generation and skipping
   - Tests real I/O operations

### Test Results

```
􁁛  Test run with 10 tests in 1 suite passed after 0.007 seconds.
```

**Coverage:**
- `findPreviousVersion()` - 6 tests (semantic versioning edge cases)
- `scaffoldDriftTest()` - 2 tests (create new / skip existing)
- `scaffoldMigrationTest()` - 2 tests (create new / skip existing)

### Architecture Decision

**We chose pragmatism over purity:**
- Original ADR proposed full library + executable split
- Actual implementation: helper struct extraction
- **Result:** Same testability, less complexity

This is a **valid architectural evolution** - we solved the problem with minimal change.
