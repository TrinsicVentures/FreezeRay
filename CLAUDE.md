# FreezeRay Development Guide

This document is the **definitive source of truth** for FreezeRay development, testing, CI/CD, and project organization.

**Note:** All architectural decisions are documented in ADRs (project/adr/). This document provides practical guidance for development.

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Architecture](#architecture)
3. [Project Structure](#project-structure)
4. [Development Workflow](#development-workflow)
5. [Testing Strategy](#testing-strategy)
6. [CI/CD](#cicd)
7. [Release Process](#release-process)
8. [TestApp Guidelines](#testapp-guidelines)
9. [Design Decisions](#design-decisions)

---

## Project Overview

### What is FreezeRay?

FreezeRay is a **CLI tool + Swift macro package** for freezing SwiftData schemas and validating migration paths. It prevents accidental schema changes from reaching production by creating immutable fixtures.

### Current Architecture (v0.4.0)

**Key Insight (see ADR-001):** The v0.3.0 macro-only approach has a critical limitation - it requires filesystem write access to the source tree, which doesn't work in iOS simulator tests.

**Solution:** Split operations into two phases:
1. **Freeze operation** (explicit, write-heavy) - CLI tool runs tests in simulator, extracts fixtures via /tmp (see ADR-002)
2. **Validation** (automatic, read-only) - Generated tests load fixtures from bundle

### Components

```
┌─────────────────────────────────────────────────────────┐
│ FreezeRay Package (Swift Package)                       │
│ - Macros: @FreezeSchema                                │
│ - Runtime: FreezeRayRuntime (SQLite operations)        │
│ - Platform: macOS 14+, iOS 17+                         │
└─────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│ freezeray CLI (v0.4.0+)                                 │
│ - Commands: freeze, scaffold, check, migrate, list     │
│ - Simulator orchestration                               │
│ - AST parsing with SwiftSyntax                         │
│ - Test scaffolding                                      │
└─────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│ User's Xcode Project                                    │
│ - Schemas with @FreezeSchema(version: "X.Y.Z")         │
│ - SchemaMigrationPlan (no annotation needed)           │
│ - Scaffolded tests in FreezeRay/Tests/                 │
│ - Frozen fixtures in FreezeRay/Fixtures/               │
└─────────────────────────────────────────────────────────┘
```

---

## Architecture

### Current State (v0.3.0)

**What works:**
- ✅ Swift macros generate freeze/check/test methods
- ✅ iOS-native SQLite operations (no shell commands)
- ✅ Tests run on both macOS and iOS Simulator
- ✅ Macro-based schema freezing and validation

**Limitations:**
- ❌ Requires write access to source tree (doesn't work in iOS simulator sandbox)
- ❌ No CLI tool yet
- ❌ No convention-over-configuration
- ❌ Tests are auto-generated, not customizable scaffolds

### Target State (v0.4.0 - CLI-based)

**See:** Architecture documented in project/adr/ and project/sprints/

**Key Changes:**
1. **CLI-driven freezing:** `freezeray freeze 1.0.0` runs in simulator, extracts fixtures
2. **Scaffolded tests:** Tests are generated once, user customizes them (see ADR-005)
3. **Convention over configuration:** Auto-detect project, schemes, schemas
4. **Read-only validation:** Tests load fixtures from bundle, no writes needed

**Implementation Status:** See project/sprints/ for current progress and next steps

---

## Project Structure

**Note:** CLI is structured as library + executable for testability (see ADR-006).

```
FreezeRay/                            # Monorepo - Single repository
├── .github/
│   └── workflows/
│       └── ci.yml                    # GitHub Actions CI
│
│
├── project/
│   ├── adr/                          # Architecture Decision Records
│   │   ├── ADR-001-cli-macro-hybrid-architecture.md
│   │   ├── ADR-002-tmp-export-for-fixture-extraction.md
│   │   ├── ADR-003-dynamic-test-generation.md
│   │   ├── ADR-004-versioned-filenames.md
│   │   ├── ADR-005-test-scaffolding-not-generation.md
│   │   └── ADR-006-separate-cli-library.md
│   ├── sprints/                      # Sprint documentation
│   └── ROADMAP.md                    # Product roadmap
│
├── Sources/
│   ├── FreezeRay/                    # Public API (macros + runtime) - SPM distribution
│   │   ├── Macros.swift              # @FreezeSchema declaration
│   │   ├── FreezeRayRuntime.swift    # SQLite operations, freeze/check logic
│   │   └── FreezeRay.swift           # Module exports
│   │
│   ├── FreezeRayMacros/              # Macro implementation
│   │   ├── FreezeMacro.swift         # @FreezeSchema expansion
│   │   └── FreezeRayPlugin.swift     # Compiler plugin entry point
│   │
│   ├── freezeray-cli/                # CLI library (testable target)
│   │   ├── Commands/
│   │   │   ├── FreezeCommand.swift   # freeze command implementation
│   │   │   └── TestScaffolding.swift # Test scaffolding helpers
│   │   ├── Parser/
│   │   │   └── MacroDiscovery.swift  # SwiftSyntax AST parsing
│   │   ├── Simulator/
│   │   │   └── SimulatorManager.swift # Simulator orchestration
│   │   └── CLI.swift                 # Main CLI entry point
│   │
│   └── freezeray-bin/                # CLI executable (thin wrapper)
│       └── main.swift                # Thin wrapper calling freezeray-cli
│
├── Tests/
│   ├── FreezeRayTests/               # Unit tests for macros
│   │   ├── FreezeMacroTests.swift
│   │   └── TestMigrationsMacroTests.swift
│   │
│   └── FreezeRayCLITests/            # ✨ NEW: Unit tests for CLI
│       ├── FreezeCommandTests.swift  # Test scaffolding functions
│       ├── MacroDiscoveryTests.swift # Test AST parsing
│       └── SimulatorManagerTests.swift
│
├── FreezeRayTestApp/                 # ⚠️ E2E Integration test bed (real Xcode project)
│   ├── FreezeRayTestApp/             # App target
│   │   ├── Models.swift              # DataV1.User, DataV2.User, etc.
│   │   ├── Schemas.swift             # AppSchemaV1/V2/V3, AppMigrations
│   │   └── ContentView.swift
│   ├── FreezeRayTestAppTests/        # Test target
│   │   └── FreezeRayTests.swift      # E2E tests
│   ├── FreezeRay/                    # Generated artifacts
│   │   ├── Fixtures/
│   │   │   ├── 1.0.0/                # Versioned fixture directories
│   │   │   │   ├── App.sqlite
│   │   │   │   ├── schema.json
│   │   │   │   ├── schema.sql
│   │   │   │   └── schema.sha256
│   │   │   ├── 2.0.0/
│   │   │   └── 3.0.0/
│   │   └── Tests/                    # Scaffolded tests (user-owned)
│   │       ├── AppSchemaV1_DriftTests.swift
│   │       ├── AppSchemaV2_DriftTests.swift
│   │       ├── AppSchemaV3_DriftTests.swift
│   │       ├── MigrateV1_0_0toV2_0_0_Tests.swift
│   │       ├── MigrateV1_0_0toV3_0_0_Tests.swift
│   │       └── MigrateV2_0_0toV3_0_0_Tests.swift
│   └── FreezeRayTestApp.xcodeproj    # Real Xcode project
│
├── FreezeRay/                        # (Future) Fixture storage for main package tests
│
├── Package.swift                     # Main package definition (monorepo)
├── CLAUDE.md                         # ⚠️ THIS FILE - Dev guide
├── PLAN.md                           # (Legacy) Original roadmap
└── LICENSE                           # MIT License
```

### File Ownership

| Path | Owner | Committed? | Notes |
|------|-------|------------|-------|
| `Sources/` | Developers | ✅ Yes | Core library code |
| `Tests/` | Developers | ✅ Yes | Unit tests |
| `TestApp/Sources/` | Developers | ✅ Yes | Test schemas |
| `TestApp/FreezeRay/Fixtures/` | **FreezeRay CLI** | ✅ Yes | Immutable artifacts |
| `TestApp/FreezeRay/Tests/` | **User + CLI scaffold** | ✅ Yes | Scaffolded once, user customizes |
| `TestApp/.build/` | Build system | ❌ No | Gitignored |
| `project/adr/` | **Architecture decisions** | ✅ Yes | Source of truth |

---

## Development Workflow

### Daily Development

1. **Start work:**
   ```bash
   cd /Users/gk/Projects/Trinsic/FreezeRay
   swift build
   ```

2. **Make changes to macros or runtime:**
   ```bash
   # Edit Sources/FreezeRay/*.swift or Sources/FreezeRayMacros/*.swift
   swift build
   swift test
   ```

3. **Test with TestApp:**
   ```bash
   cd TestApp
   swift test  # Runs integration tests
   ```

4. **Check conformance to architecture:**
   - Review project/adr/ before making architectural changes
   - Ensure changes align with documented design decisions

### Adding New Features

**Process:**
1. Check if feature is in project/adr/ Phase 1-4 roadmap
2. If yes: implement according to documented design
3. If no: create ADR to document new design decision
5. Add tests (unit + integration)
6. Document user-facing features in CLAUDE.md

### Code Review Checklist

- [ ] Does this align with documented architecture (see project/adr/)?
- [ ] Are there unit tests?
- [ ] Does TestApp demonstrate the feature?
- [ ] Does it work on both macOS and iOS Simulator?

---

## Testing Strategy

### Test Pyramid

```
                    ┌─────────────────┐
                    │  TestApp        │  ← Integration tests
                    │  (End-to-End)   │
                    └─────────────────┘
                           ▲
                           │
              ┌─────────────────────────┐
              │  FreezeRayTests         │  ← Unit tests
              │  (Macro expansion)      │
              └─────────────────────────┘
```

### 1. Unit Tests (FreezeRayTests)

**Location:** `Tests/FreezeRayTests/`

**What to test:**
- Macro expansion (does `@Freeze` generate correct code?)
- AST parsing correctness
- Edge cases (missing version, invalid syntax)

**Run:**
```bash
swift test --filter FreezeRayTests
```

**Example:**
```swift
@Test func testFreezeMacroExpansion() throws {
    assertMacroExpansion(
        """
        @Freeze(version: "1.0.0")
        enum SchemaV1: VersionedSchema { }
        """,
        expandedSource: """
        enum SchemaV1: VersionedSchema {
            #if DEBUG
            static func __freezeray_freeze_1_0_0() throws { ... }
            #endif
        }
        """,
        macros: ["Freeze": FreezeMacro.self]
    )
}
```

### 2. Integration Tests (TestApp)

**Location:** `TestApp/Tests/TestAppTests/`

**Purpose:** Validate the **entire workflow** with real SwiftData schemas.

**What to test:**
- Schema freezing (first run creates fixtures)
- Drift detection (subsequent runs verify)
- Migration testing (all frozen versions → HEAD)
- Fixture integrity (checksums match)

**Run:**
```bash
cd FreezeRayTestApp
xcodebuild test -project FreezeRayTestApp.xcodeproj -scheme FreezeRayTestApp -destination 'platform=iOS Simulator,name=iPhone 17'
```

**FreezeRayTestApp Structure:**
- **Models.swift:** DataV1.User, DataV2.User, DataV3.User+Post
- **Schemas.swift:** AppSchemaV1/V2/V3 with `@FreezeSchema`, AppMigrations SchemaMigrationPlan
- **FreezeRayTests.swift:** Calls `__freezeray_freeze_*()`, `__freezeray_check_*()`, etc.

**Preferred Simulator:**
- **iPhone 17** - Always use this simulator to avoid wasting time with non-existent simulator names

### 3. Manual Testing

**Scenarios to test manually:**
1. **Fresh freeze:** Delete `FreezeRayTestApp/FreezeRay/`, run tests → fixtures created
2. **Drift detection:** Modify `AppSchemaV1` models, run tests → should fail
3. **Migration paths:** Verify V1→V3 and V2→V3 migrations work
4. **Platform compatibility:** Run on iOS Simulator (iPhone 17)

### 4. Test Coverage Goals

- **Unit tests:** 80%+ coverage of macro logic
- **Integration tests:** 100% coverage of user workflows
- **Cross-platform:** All tests pass on macOS and iOS

---

## CI/CD

### GitHub Actions

**File:** `.github/workflows/ci.yml`

**Triggers:**
- Push to `master`
- Pull requests

**Jobs:**

1. **Build & Test (macOS):**
   ```yaml
   - name: Build
     run: swift build
   - name: Unit Tests
     run: swift test --filter FreezeRayTests
   - name: Integration Tests
     run: cd TestApp && swift test
   ```

2. **Build & Test (iOS Simulator):**
   ```yaml
   - name: Test on iOS
     run: |
       cd FreezeRayTestApp
       xcodebuild test \
         -project FreezeRayTestApp.xcodeproj \
         -scheme FreezeRayTestApp \
         -destination 'platform=iOS Simulator,name=iPhone 17'
   ```

3. **Verify Fixtures (Drift Detection):**
   ```yaml
   - name: Check for uncommitted fixtures
     run: |
       if [[ -n $(git status --porcelain FreezeRayTestApp/FreezeRay/Fixtures/) ]]; then
         echo "❌ Uncommitted fixtures detected"
         exit 1
       fi
   ```

### Test Execution Order

1. Build main package
2. Run unit tests (fast, no dependencies)
3. Run integration tests (FreezeRayTestApp)
4. Verify no uncommitted changes to fixtures

### CI Failures

**Common causes:**
- Schema drift (frozen schema changed)
- Missing fixtures (not committed)
- Platform-specific issues (macOS vs iOS)
- SwiftData API changes (Xcode updates)

**How to fix:**
1. Check CI logs for specific error
2. Reproduce locally: `cd FreezeRayTestApp && xcodebuild test -project FreezeRayTestApp.xcodeproj -scheme FreezeRayTestApp -destination 'platform=iOS Simulator,name=iPhone 17'`
3. If drift: create new schema version (don't modify frozen)
4. If platform issue: check `#if os(iOS)` guards

**Preferred Simulator:**
- **iPhone 17** - Always use this simulator for all testing to avoid wasting time with non-existent simulator names

---

## Release Process

### Semantic Versioning

**Format:** `MAJOR.MINOR.PATCH`

**When to bump:**
- **MAJOR:** Breaking changes (API changes, CLI incompatibility)
- **MINOR:** New features (new commands, new macros)
- **PATCH:** Bug fixes, documentation updates

### Released Versions

| Version | Description |
|---------|-------------|
| v0.1.0 | Initial macro-based implementation |
| v0.2.0 | (skipped) |
| v0.3.0 | iOS-native SQLite operations |

**For planned versions, see:** project/ROADMAP.md and project/sprints/

### Release Checklist

**Before release:**
- [ ] All tests pass (macOS + iOS)
- [ ] Version bumped in `Package.swift` (if needed)
- [ ] Git tag created (`git tag vX.Y.Z`)
- [ ] TestApp demonstrates all features

**Release steps:**
   ```markdown
   ## [X.Y.Z] - YYYY-MM-DD
   ### Added
   - New feature X
   ### Fixed
   - Bug Y
   ```

2. Commit changes:
   ```bash
   git add .
   git commit -m "Release vX.Y.Z"
   git tag vX.Y.Z
   git push origin master --tags
   ```

3. (Future) Publish CLI binary:
   ```bash
   # Build universal binary
   swift build -c release --arch arm64 --arch x86_64
   # Upload to GitHub Releases
   ```

### Post-Release

- [ ] Announce on GitHub Discussions
- [ ] Close milestone issues
- [ ] Create next milestone

---

## TestApp Guidelines

### Purpose

TestApp is the **source of truth test bed** for FreezeRay. It simulates a real user's Xcode project.

### Requirements

**Current State (v0.3.0):**
- Swift Package (`Package.swift`)
- Can run tests with `swift test`
- Works on macOS and iOS Simulator

**Target State (v0.4.0+):**
- **MUST** be a real Xcode project (`.xcodeproj` or `.xcworkspace`)
- **MUST** have an iOS app target (not just library)
- **MUST** run in iOS Simulator (not macOS)
- **SHOULD** mimic real-world project structure

### Why Xcode Project?

See ADR-001:
> "The TestApp should be our source of truth testbed for all local testing, but should ideally be a REAL Xcode project-based app, not just a Swift package, to ensure everything is as realistic as possible."

**Reasons:**
1. CLI tool needs to test `xcodebuild` integration
2. Simulator orchestration requires real app bundle
3. Bundle resource loading (fixtures) works differently in apps vs SPM
4. Real users have Xcode projects, not just SPM

### Migration TODO: SPM → Xcode Project

**Steps to convert TestApp:**
1. Create new Xcode iOS App project (`TestApp.xcodeproj`)
2. Move `Sources/TestApp/` → `TestApp/` (app target)
3. Move `Tests/TestAppTests/` → `TestAppTests/` (test target)
4. Update `FreezeRay/` artifact location (should be in Xcode project root)
5. Update CI to use `xcodebuild` instead of `swift test`
6. Verify tests run in iOS Simulator

**Acceptance Criteria:**
- [ ] TestApp has `.xcodeproj` file
- [ ] App target compiles and runs in iOS Simulator
- [ ] Test target can run with ⌘U in Xcode
- [ ] Fixtures load from bundle correctly
- [ ] CI uses `xcodebuild test -scheme TestApp -destination 'platform=iOS Simulator'`

### Test Scenarios in TestApp

1. **Fresh freeze:** No fixtures exist → tests create them
2. **Drift detection:** Fixtures exist, schema unchanged → tests pass
3. **Drift detected:** Fixtures exist, schema changed → tests fail
4. **Multi-version migration:** V1→V3 migration works
5. **Fixture integrity:** SHA256 checksums match
6. **Custom test assertions:** User can add validation logic (future)

---

## Design Decisions

### Why CLI + Macros?

**Decision:** Hybrid approach (CLI for freezing, macros for validation)

**Rationale:**
- Macros alone can't write to source tree in iOS simulator
- CLI tool can orchestrate simulator, extract fixtures
- Scaffolded tests (generated once) allow user customization
- Macros still provide type safety and compile-time validation

**See:** ADR-001 for full rationale

### Why Scaffolds Instead of Generated Tests?

**Decision:** Generate tests **once** (scaffolding), user customizes

**Rationale:**
- Tests are part of user's codebase, not FreezeRay's
- Users need to add custom assertions (data integrity checks)
- Regenerating tests would overwrite user changes
- Clear TODO markers guide customization

**See:** ADR-005 for full rationale

### Why Convention Over Configuration?

**Decision:** Auto-detect project structure, minimal/optional config

**Rationale:**
- Most projects follow standard conventions
- `.freezeray.yml` only needed for non-standard setups
- Reduces friction for new users
- Less to maintain and document

**See:** ADR-001 for full rationale

### Why Commit Fixtures to Git?

**Decision:** Always commit fixtures to source control

**Rationale:**
- Provides full history and traceability
- Enables code review of schema changes
- Fixtures are small (<1MB typically)
- Critical for migration testing

**See:** ADR-001 for full rationale

### Why iOS Simulator for Freezing?

**Decision:** Freeze operations run in iOS Simulator (via CLI)

**Rationale:**
- Most users target iOS apps
- Tests need to run in same environment as app
- SwiftData behavior can differ between macOS and iOS
- Validation tests must run in iOS (read-only from bundle)

**See:** ADR-002 and ADR-003 for implementation details

### Why Monorepo + Library/Executable Split for CLI?

**Decision:** Use monorepo with FreezeRayCLI (library) + freezeray (executable) structure

**Rationale:**

**Monorepo benefits:**
- Version coordination (CLI and macros must stay in sync)
- Shared CI/CD (single workflow tests both)
- Easier development (changes to library immediately testable with CLI)
- Industry standard (SwiftLint, SwiftFormat, Mint)
- Distribution compatible (SPM for library, Homebrew for CLI)

**Library + Executable benefits:**
- Testability: Library targets can be imported by test targets
- Separation of concerns: Logic (library) vs entry point (executable)
- Future `freezeray init` command can be unit tested
- Homebrew formula points to thin executable

**Alternative rejected:** Separate repositories would create version coordination nightmare and go against Swift tooling best practices.

**See:** [project/adr/ADR-006-separate-cli-library.md](project/adr/ADR-006-separate-cli-library.md)

---

## Additional Resources

### Key Documents

1. **project/adr/** - Architecture Decision Records document all technical decisions
2. **PLAN.md** - (Legacy) Original roadmap, may be outdated

### External References

- [SwiftSyntax Documentation](https://github.com/apple/swift-syntax)
- [Swift Testing Framework](https://github.com/apple/swift-testing)
- [SwiftData Documentation](https://developer.apple.com/documentation/swiftdata)

### Decision Log

All major architectural decisions should be documented in:
1. This file (CLAUDE.md § Design Decisions)
2. ADRs in project/adr/ (for all architectural decisions)
3. Git commit messages (with rationale)

---

## Appendix: Common Commands

### Development
```bash
# Build library
swift build

# Run unit tests
swift test --filter FreezeRayTests

# Run integration tests on FreezeRayTestApp (real Xcode project)
cd FreezeRayTestApp && xcodebuild test -project FreezeRayTestApp.xcodeproj -scheme FreezeRayTestApp -destination 'platform=iOS Simulator,name=iPhone 17'

# Clean build artifacts
swift package clean
```

### CI Debugging
```bash
# Reproduce CI locally (macOS)
swift build && swift test

# Reproduce CI locally (iOS Simulator) - use iPhone 17!
cd FreezeRayTestApp
xcodebuild test -project FreezeRayTestApp.xcodeproj -scheme FreezeRayTestApp -destination 'platform=iOS Simulator,name=iPhone 17'
```

### Git Workflow
```bash
# Create feature branch
git checkout -b feature/my-feature

# Commit with descriptive message
git commit -m "Add X functionality for CLI integration"

# Check for uncommitted fixtures
git status FreezeRayTestApp/FreezeRay/Fixtures/

# Tag release
git tag v0.4.0
git push origin master --tags
```

---

**Maintained by:** Geordie Kaytes (@geordiekaytes)
**Organization:** Trinsic Ventures
**License:** MIT
