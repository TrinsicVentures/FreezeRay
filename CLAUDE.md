# FreezeRay Development Guide

**Version:** v0.4.0 (CLI-based architecture)
**Status:** Active Development
**Last Updated:** 2025-10-10

This document is the **definitive source of truth** for FreezeRay development, testing, CI/CD, and project organization.

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

**Key Insight from CLI-DESIGN.md:** The v0.3.0 macro-only approach has a critical limitation - it requires filesystem write access to the source tree, which doesn't work in iOS simulator tests.

**Solution:** Split operations into two phases:
1. **Freeze operation** (explicit, write-heavy) - CLI tool runs tests in simulator, extracts fixtures
2. **Validation** (automatic, read-only) - Generated tests load fixtures from bundle

### Components

```
┌─────────────────────────────────────────────────────────┐
│ FreezeRay Package (Swift Package)                       │
│ - Macros: @Freeze, @AutoTests                          │
│ - Runtime: FreezeRayRuntime (SQLite operations)        │
│ - Platform: macOS 14+, iOS 17+                         │
└─────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│ freezeray CLI (Future - v0.4.0+)                        │
│ - Commands: freeze, scaffold, check, migrate, list     │
│ - Simulator orchestration                               │
│ - AST parsing with SwiftSyntax                         │
│ - Test generation                                       │
└─────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│ User's Xcode Project                                    │
│ - Schemas with @Freeze(version: "X.Y.Z")               │
│ - MigrationPlan with @AutoTests                         │
│ - Generated/scaffolded tests in FreezeRay/Tests/       │
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

**See:** [docs/CLI-DESIGN.md](/Users/gk/Projects/Trinsic/FreezeRay/docs/CLI-DESIGN.md) (central source of truth)

**Key Changes:**
1. **CLI-driven freezing:** `freezeray freeze 1.0.0` runs in simulator, extracts fixtures
2. **Scaffolded tests:** Tests are generated once, user customizes them
3. **Convention over configuration:** Auto-detect project, schemes, schemas
4. **Read-only validation:** Tests load fixtures from bundle, no writes needed

### Migration Path: v0.3.0 → v0.4.0

**Phase 1: CLI Implementation**
- [ ] Implement AST parser (SwiftSyntax) to find `@Freeze` and `@AutoTests`
- [ ] Implement test generator (scaffolds, not regenerates)
- [ ] Implement `freezeray freeze` command with simulator orchestration
- [ ] Update `FreezeRayRuntime` to support custom output directories

**Phase 2: Update Macros**
- [ ] Change macro behavior: scaffolds tests instead of generating
- [ ] Update runtime to work in iOS simulator sandbox
- [ ] Remove auto-regeneration, make tests user-owned

**Phase 3: Documentation & Testing**
- [ ] Update README for CLI workflow
- [ ] Convert TestApp to real Xcode project
- [ ] Add CLI integration tests
- [ ] Update examples

---

## Project Structure

```
FreezeRay/
├── .github/
│   └── workflows/
│       └── ci.yml                    # GitHub Actions CI
│
├── docs/
│   └── CLI-DESIGN.md                 # ⚠️ CENTRAL SOURCE OF TRUTH for v0.4.0
│
├── Sources/
│   ├── FreezeRay/                    # Public API (macros + runtime)
│   │   ├── Macros.swift              # @Freeze, @AutoTests declarations
│   │   ├── FreezeRayRuntime.swift    # SQLite operations, freeze/check logic
│   │   └── FreezeRay.swift           # Module exports
│   │
│   └── FreezeRayMacros/              # Macro implementation
│       ├── FreezeMacro.swift         # @Freeze expansion
│       ├── AutoTestsMacro.swift      # @AutoTests expansion
│       └── FreezeRayPlugin.swift     # Compiler plugin entry point
│
├── Tests/
│   └── FreezeRayTests/               # Unit tests for macros
│       ├── FreezeMacroTests.swift
│       └── AutoTestsMacroTests.swift
│
├── TestApp/                          # ⚠️ Integration test bed
│   ├── Sources/
│   │   └── TestApp/
│   │       ├── Models.swift          # DataV1.User, DataV2.User, etc.
│   │       └── Schemas.swift         # AppSchemaV1/V2/V3, AppMigrations
│   ├── Tests/
│   │   └── TestAppTests/
│   │       └── FreezeRayIntegrationTests.swift
│   ├── FreezeRay/                    # Generated artifacts
│   │   ├── Fixtures/
│   │   │   ├── v1/
│   │   │   │   ├── App.sqlite
│   │   │   │   ├── schema.json
│   │   │   │   ├── schema.sql
│   │   │   │   └── schema.sha256
│   │   │   └── v2/
│   │   │       └── ...
│   │   └── Tests/                    # (Future) Scaffolded tests
│   │       ├── SchemaV1_DriftTests.swift
│   │       └── MigrationPlan_Tests.swift
│   └── Package.swift
│
├── FreezeRay/                        # (Future) Fixture storage for main package tests
│
├── Package.swift                     # Main package definition
├── CLAUDE.md                         # ⚠️ THIS FILE - Dev guide
├── README.md                         # User-facing documentation
├── PLAN.md                           # (Legacy) Original roadmap
├── CHANGELOG.md                      # Version history
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
| `docs/CLI-DESIGN.md` | **Architecture decisions** | ✅ Yes | Source of truth |

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

4. **Check conformance to CLI design:**
   - Review [docs/CLI-DESIGN.md](docs/CLI-DESIGN.md) before making architectural changes
   - Ensure changes align with v0.4.0 vision

### Adding New Features

**Process:**
1. Check if feature is in [docs/CLI-DESIGN.md](docs/CLI-DESIGN.md) Phase 1-4 roadmap
2. If yes: implement according to design
3. If no: discuss design implications first
4. Update CHANGELOG.md
5. Add tests (unit + integration)
6. Update README.md if user-facing

### Code Review Checklist

- [ ] Does this align with CLI-DESIGN.md?
- [ ] Are there unit tests?
- [ ] Does TestApp demonstrate the feature?
- [ ] Is CHANGELOG.md updated?
- [ ] Is README.md updated (if user-facing)?
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
cd TestApp
swift test
# OR
xcodebuild test -scheme TestApp -destination 'platform=iOS Simulator,name=iPhone 16'
```

**TestApp Structure:**
- **Models.swift:** DataV1.User, DataV2.User, DataV3.User+Post
- **Schemas.swift:** AppSchemaV1/V2/V3 with `@Freeze`, AppMigrations with `@AutoTests`
- **FreezeRayIntegrationTests.swift:** Calls `__freezeray_freeze_*()`, `__freezeray_check_*()`, etc.

### 3. Manual Testing

**Scenarios to test manually:**
1. **Fresh freeze:** Delete `TestApp/FreezeRay/`, run tests → fixtures created
2. **Drift detection:** Modify `AppSchemaV1` models, run tests → should fail
3. **Migration paths:** Verify V1→V3 and V2→V3 migrations work
4. **Platform compatibility:** Run on both macOS and iOS Simulator

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
       cd TestApp
       xcodebuild test \
         -scheme TestApp \
         -destination 'platform=iOS Simulator,name=iPhone 16'
   ```

3. **Verify Fixtures (Drift Detection):**
   ```yaml
   - name: Check for uncommitted fixtures
     run: |
       if [[ -n $(git status --porcelain TestApp/FreezeRay/Fixtures/) ]]; then
         echo "❌ Uncommitted fixtures detected"
         exit 1
       fi
   ```

### Test Execution Order

1. Build main package
2. Run unit tests (fast, no dependencies)
3. Run integration tests (TestApp)
4. Verify no uncommitted changes to fixtures

### CI Failures

**Common causes:**
- Schema drift (frozen schema changed)
- Missing fixtures (not committed)
- Platform-specific issues (macOS vs iOS)
- SwiftData API changes (Xcode updates)

**How to fix:**
1. Check CI logs for specific error
2. Reproduce locally: `cd TestApp && swift test`
3. If drift: create new schema version (don't modify frozen)
4. If platform issue: check `#if os(macOS)` guards

---

## Release Process

### Semantic Versioning

**Format:** `MAJOR.MINOR.PATCH`

**When to bump:**
- **MAJOR:** Breaking changes (API changes, CLI incompatibility)
- **MINOR:** New features (new commands, new macros)
- **PATCH:** Bug fixes, documentation updates

### Current Version Milestones

| Version | Status | Description |
|---------|--------|-------------|
| v0.1.0 | ✅ Released | Initial macro-based implementation |
| v0.2.0 | ✅ Released | (skipped) |
| v0.3.0 | ✅ Released | iOS-native SQLite operations |
| v0.4.0 | 🚧 In Progress | CLI-based architecture (see CLI-DESIGN.md) |
| v0.5.0 | 📋 Planned | Enhanced validation (check, migrate commands) |
| v1.0.0 | 🎯 Target | Public release |

### Release Checklist

**Before release:**
- [ ] All tests pass (macOS + iOS)
- [ ] CHANGELOG.md updated
- [ ] README.md reflects current features
- [ ] Version bumped in `Package.swift` (if needed)
- [ ] Git tag created (`git tag vX.Y.Z`)
- [ ] TestApp demonstrates all features

**Release steps:**
1. Update CHANGELOG.md:
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
- [ ] Update README.md badges (if needed)
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

From CLI-DESIGN.md:
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

**See:** [docs/CLI-DESIGN.md § Problem Statement](docs/CLI-DESIGN.md#problem-statement)

### Why Scaffolds Instead of Generated Tests?

**Decision:** Generate tests **once** (scaffolding), user customizes

**Rationale:**
- Tests are part of user's codebase, not FreezeRay's
- Users need to add custom assertions (data integrity checks)
- Regenerating tests would overwrite user changes
- Clear TODO markers guide customization

**See:** [docs/CLI-DESIGN.md § Design Decisions #5](docs/CLI-DESIGN.md#5-tests-are-scaffolds-not-generated)

### Why Convention Over Configuration?

**Decision:** Auto-detect project structure, minimal/optional config

**Rationale:**
- Most projects follow standard conventions
- `.freezeray.yml` only needed for non-standard setups
- Reduces friction for new users
- Less to maintain and document

**See:** [docs/CLI-DESIGN.md § Design Decisions #3](docs/CLI-DESIGN.md#3-convention-over-configuration)

### Why Commit Fixtures to Git?

**Decision:** Always commit fixtures to source control

**Rationale:**
- Provides full history and traceability
- Enables code review of schema changes
- Fixtures are small (<1MB typically)
- Critical for migration testing

**See:** [docs/CLI-DESIGN.md § Design Decisions #1](docs/CLI-DESIGN.md#1-fixtures-committed-to-git)

### Why iOS Simulator for Freezing?

**Decision:** Freeze operations run in iOS Simulator (via CLI)

**Rationale:**
- Most users target iOS apps
- Tests need to run in same environment as app
- SwiftData behavior can differ between macOS and iOS
- Validation tests must run in iOS (read-only from bundle)

**See:** [docs/CLI-DESIGN.md § Implementation Details § Simulator Orchestration](docs/CLI-DESIGN.md#simulator-orchestration)

---

## Additional Resources

### Key Documents

1. **docs/CLI-DESIGN.md** - Central source of truth for v0.4.0 architecture
2. **README.md** - User-facing documentation
3. **CHANGELOG.md** - Version history
4. **PLAN.md** - (Legacy) Original roadmap, may be outdated

### External References

- [SwiftSyntax Documentation](https://github.com/apple/swift-syntax)
- [Swift Testing Framework](https://github.com/apple/swift-testing)
- [SwiftData Documentation](https://developer.apple.com/documentation/swiftdata)

### Decision Log

All major architectural decisions should be documented in:
1. This file (CLAUDE.md § Design Decisions)
2. CLI-DESIGN.md (for CLI-specific decisions)
3. Git commit messages (with rationale)

---

## Appendix: Common Commands

### Development
```bash
# Build library
swift build

# Run unit tests
swift test --filter FreezeRayTests

# Run integration tests
cd TestApp && swift test

# Clean build artifacts
swift package clean
```

### CI Debugging
```bash
# Reproduce CI locally (macOS)
swift build && swift test && cd TestApp && swift test

# Reproduce CI locally (iOS Simulator)
cd TestApp
xcodebuild test -scheme TestApp -destination 'platform=iOS Simulator,name=iPhone 16'
```

### Git Workflow
```bash
# Create feature branch
git checkout -b feature/my-feature

# Commit with descriptive message
git commit -m "Add X functionality for CLI integration"

# Check for uncommitted fixtures
git status TestApp/FreezeRay/Fixtures/

# Tag release
git tag v0.4.0
git push origin master --tags
```

---

**Maintained by:** Geordie Kaytes (@geordiekaytes)
**Organization:** Trinsic Ventures
**License:** MIT
