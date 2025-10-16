# Sprint: v0.5.0 - Repository Separation

**Goal:** Split FreezeRay into two repositories to eliminate CLI dependency pollution for package users

**Status:** ✅ COMPLETE
**Start Date:** 2025-10-15
**Completion Date:** 2025-10-15
**Actual Effort:** ~4 hours
**ADR Reference:** ADR-008-repository-separation.md

---

## Context

### Problem Statement

When users add FreezeRay as a package dependency, they get all CLI dependencies resolved in their project:
- XcodeProj + its 3 transitive dependencies (AEXML, PathKit, Spectre)
- ArgumentParser
- SwiftSyntax (needed, but...)

**Total:** 7 packages when users only need 2 (FreezeRay + swift-syntax)

### User Impact

**Before (Current State):**
```swift
// User adds FreezeRay
dependencies: [.package(url: "github.com/Trinsic/FreezeRay", from: "0.4.0")]

// Their Package.resolved gets:
- FreezeRay ✓
- swift-syntax ✓
- ArgumentParser ✗ (CLI only)
- XcodeProj ✗ (CLI only)
- AEXML ✗ (transitive)
- PathKit ✗ (transitive)
- Spectre ✗ (transitive)
```

**After (Target State):**
```swift
// User adds FreezeRay
dependencies: [.package(url: "github.com/Trinsic/FreezeRay", from: "0.5.0")]

// Their Package.resolved gets:
- FreezeRay ✓
- swift-syntax ✓
```

### Success Criteria

- [ ] Users adding FreezeRay package only get FreezeRay + swift-syntax
- [ ] CLI users can still install via Homebrew/npm
- [ ] CLI tests pass against FreezeRay main branch
- [ ] All documentation updated
- [ ] Smooth migration path for existing users

---

## Architecture

### Current State (v0.4.2)

```
FreezeRay/ (Single Monorepo)
├── Sources/
│   ├── FreezeRay/              # Package (macro + runtime)
│   ├── FreezeRayMacros/        # Macro implementation
│   ├── freezeray-cli/          # CLI library
│   └── freezeray-bin/          # CLI executable
├── Tests/
│   ├── FreezeRayTests/         # Package tests
│   └── FreezeRayCLITests/      # CLI tests (22 tests)
└── Package.swift                # All dependencies together
```

### Target State (v0.5.0)

**Repository 1: FreezeRay (Package)**
```
github.com/TrinsicVentures/FreezeRay
├── Sources/
│   ├── FreezeRay/              # Macro declarations + runtime
│   └── FreezeRayMacros/        # Macro implementation
├── Tests/
│   └── FreezeRayTests/         # Unit tests
├── FreezeRayTestApp/           # E2E test bed
└── Package.swift                # Clean dependencies
```

**Repository 2: FreezeRayCLI (Tool)**
```
github.com/TrinsicVentures/FreezeRayCLI
├── Sources/
│   ├── freezeray-cli/          # CLI library (moved)
│   └── freezeray-bin/          # CLI executable (moved)
├── Tests/
│   └── FreezeRayCLITests/      # CLI tests (moved)
├── scripts/
│   └── install.sh              # Installation script
└── Package.swift                # CLI dependencies + FreezeRay dependency
```

---

## Implementation Plan

### Phase 0: Pre-Separation Cleanup ✅ COMPLETE

**Status:** Complete (v0.4.2 released 2025-10-14)
**Effort:** 3 hours
**Reference:** project/sprints/v0.4.2-bug-fixes.md

Before separating repositories, we fixed critical init command bugs that were blocking adoption:

#### Completed Tasks

1. **Fixed Folder Reference Bug** ✅
   - Changed FreezeRay folder from PBXGroup (blue) to PBXFileReference (yellow)
   - Now syncs automatically with filesystem - no manual "Add Files" needed
   - Location: InitCommand.swift:218-235

2. **Fixed Package Dependency Bug** ✅
   - Switched from manual XCRemoteSwiftPackageReference creation to `project.addSwiftPackage()`
   - Package now properly appears in Xcode Package Dependencies
   - Framework automatically linked to targets
   - Reduced code from 45 lines to 26 lines (more reliable)
   - Location: InitCommand.swift:172-197

3. **Documented Products Group Visibility** ✅
   - Investigated Products group appearing after `freezeray init`
   - Confirmed as expected behavior with XcodeProj library (not a bug)
   - Documented as cosmetic issue - users can hide manually if desired

4. **Deferred Swift Concurrency Warnings** ⏸️
   - Attempted async conversion of SimulatorManager.shell()
   - AsyncParsableCommand broke command execution (commands showed help instead of running)
   - Reverted all changes after debugging revealed ArgumentParser incompatibility
   - Current DispatchQueue implementation works correctly (compiler warnings only, no runtime issues)
   - Will revisit in future sprint with dedicated investigation time

#### Impact

Init command now works reliably for real-world projects:
- FreezeRay folder syncs with filesystem ✅
- Package dependency properly configured ✅
- All critical bugs resolved ✅
- Ready for repository separation ✅

**E2E Validation:** Tested on throwX project - all init functionality working

**For full details:** See project/sprints/v0.4.2-bug-fixes.md (383 lines with implementation details, debugging notes, and design decisions)

---

### Phase 1: Prepare Codebase (1-2 hours)

#### Task 1.1: Audit Dependencies
**Owner:** Dev
**Effort:** 15 min

- [x] List all dependencies in current Package.swift
- [x] Classify: Package-only vs CLI-only vs Shared
- [x] Identify which targets use which dependencies

**Result:**
```
Package-only: swift-syntax (macros)
CLI-only: ArgumentParser, XcodeProj, AEXML, PathKit, Spectre
Shared: swift-syntax (CLI uses for parsing)
```

#### Task 1.2: Create Clean FreezeRay Package.swift
**Owner:** Dev
**Effort:** 30 min

- [ ] Create feature branch: `feature/v0.5.0-package-only`
- [ ] Remove CLI targets from Package.swift
- [ ] Remove CLI dependencies (ArgumentParser, XcodeProj)
- [ ] Keep only FreezeRay + FreezeRayMacros targets
- [ ] Update FreezeRayTests to not reference CLI
- [ ] Verify tests pass: `swift test`

**Acceptance Criteria:**
```bash
swift build               # Succeeds
swift test                # All package tests pass
Package.swift             # No CLI dependencies
ls Sources/               # Only FreezeRay/ and FreezeRayMacros/
```

#### Task 1.3: Update FreezeRayTestApp
**Owner:** Dev
**Effort:** 30 min

- [ ] Update FreezeRayTestApp to use local FreezeRay package
- [ ] Remove references to CLI tests
- [ ] Verify E2E tests still work with package-only

**Note:** FreezeRayTestApp will use external freezeray CLI for E2E testing (installed via Homebrew/npm)

### Phase 2: Create FreezeRayCLI Repository (2-3 hours)

#### Task 2.1: Set Up New Repository
**Owner:** DevOps / Dev
**Effort:** 15 min

- [ ] Create GitHub repository: `TrinsicVentures/FreezeRayCLI`
- [ ] Initialize with README, LICENSE, .gitignore
- [ ] Set up repository settings (branch protection, etc.)
- [ ] Add repository description and topics

#### Task 2.2: Migrate CLI Code
**Owner:** Dev
**Effort:** 1 hour

- [ ] Copy CLI code from FreezeRay repo:
  - `Sources/freezeray-cli/` → `Sources/freezeray-cli/`
  - `Sources/freezeray-bin/` → `Sources/freezeray-bin/`
  - `Tests/FreezeRayCLITests/` → `Tests/FreezeRayCLITests/`
- [ ] Create Package.swift for CLI
- [ ] Add FreezeRay as package dependency: `from: "0.5.0"`
- [ ] Verify builds: `swift build`
- [ ] Verify tests pass: `swift test`

**Package.swift template:**
```swift
let package = Package(
    name: "freezeray",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "freezeray", targets: ["freezeray-bin"])
    ],
    dependencies: [
        .package(url: "https://github.com/TrinsicVentures/FreezeRay", from: "0.5.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
        .package(url: "https://github.com/apple/swift-syntax", from: "600.0.0"),
        .package(url: "https://github.com/tuist/XcodeProj", from: "8.0.0"),
    ],
    targets: [
        .target(
            name: "freezeray-cli",
            dependencies: [
                .product(name: "FreezeRay", package: "FreezeRay"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "XcodeProj", package: "XcodeProj"),
            ]
        ),
        .executableTarget(
            name: "freezeray-bin",
            dependencies: ["freezeray-cli"]
        ),
        .testTarget(
            name: "FreezeRayCLITests",
            dependencies: ["freezeray-cli"]
        )
    ]
)
```

#### Task 2.3: Update CLI Code Imports
**Owner:** Dev
**Effort:** 30 min

- [ ] Update imports from `@testable import FreezeRay` to just `import FreezeRay`
- [ ] Fix any access control issues (public vs internal)
- [ ] Verify CLI compiles against FreezeRay v0.5.0
- [ ] Run all 22 CLI tests

#### Task 2.4: Set Up CI/CD
**Owner:** DevOps / Dev
**Effort:** 1 hour

- [ ] Create `.github/workflows/ci.yml` for FreezeRayCLI
- [ ] Configure build + test workflow
- [ ] Add cross-repo testing (test against FreezeRay main)
- [ ] Set up binary release workflow
- [ ] Configure npm publishing workflow

**CI Workflow:**
```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build
        run: swift build
      - name: Test
        run: swift test

  test-against-freezeray-main:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - name: Update FreezeRay to main branch
        run: |
          # Update Package.swift to use main branch
          sed -i '' 's/from: "0.5.0"/branch: "main"/g' Package.swift
      - name: Test compatibility
        run: swift test
```

### Phase 3: Update Distribution (2-3 hours)

#### Task 3.1: Update Homebrew Formula
**Owner:** DevOps / Dev
**Effort:** 30 min

- [ ] Create/update Homebrew formula to point to FreezeRayCLI repo
- [ ] Test formula locally: `brew install --build-from-source`
- [ ] Verify installation works
- [ ] Submit PR to homebrew-tap (if external tap)

**Formula template:**
```ruby
class Freezeray < Formula
  desc "SwiftData schema freezing and migration testing"
  homepage "https://github.com/TrinsicVentures/FreezeRayCLI"
  url "https://github.com/TrinsicVentures/FreezeRayCLI/archive/v1.0.0.tar.gz"
  sha256 "..." # Will be generated

  depends_on :xcode => ["16.0", :build]

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox"
    bin.install ".build/release/freezeray"
  end

  test do
    system bin/"freezeray", "--version"
  end
end
```

#### Task 3.2: Update npm Package
**Owner:** DevOps / Dev
**Effort:** 1 hour

**Reference:** ADR-007-npm-binary-distribution.md

- [ ] Update package.json to fetch from FreezeRayCLI releases
- [ ] Update binary download scripts
- [ ] Test npm installation locally
- [ ] Publish to npm registry
- [ ] Verify: `npm install -g @trinsic/freezeray`

#### Task 3.3: Create Installation Documentation
**Owner:** Dev / Docs
**Effort:** 1 hour

- [ ] Write FreezeRayCLI README with installation options
- [ ] Document Homebrew installation
- [ ] Document npm installation
- [ ] Document direct binary download
- [ ] Add quick start guide
- [ ] Add troubleshooting section

### Phase 4: Documentation & Migration (2-3 hours)

#### Task 4.1: Update FreezeRay README
**Owner:** Dev / Docs
**Effort:** 30 min

- [ ] Remove CLI installation instructions
- [ ] Add link to FreezeRayCLI repository
- [ ] Update quick start to show package-only usage
- [ ] Add section: "CLI Tool"
- [ ] Update architecture diagram

**Key change:**
```markdown
## Installation

### Package (for app developers)
Add FreezeRay to your Package.swift:
```swift
dependencies: [
    .package(url: "https://github.com/TrinsicVentures/FreezeRay", from: "0.5.0")
]
```

### CLI Tool (for freezing schemas)
The freezeray CLI is distributed separately.
See https://github.com/TrinsicVentures/FreezeRayCLI for installation.
```

#### Task 4.2: Create Migration Guide
**Owner:** Dev / Docs
**Effort:** 1 hour

Create `MIGRATION.md` in FreezeRay repo:

- [ ] Document what changed
- [ ] Explain why (dependency pollution)
- [ ] Show before/after Package.resolved
- [ ] Provide upgrade steps for existing users
- [ ] Note: No code changes needed for package users

**Migration guide structure:**
```markdown
# Migration Guide: v0.4.x → v0.5.0

## What Changed?

The CLI has been moved to a separate repository.

## Impact

### Package Users (Most users)
No action required! Just update your dependency:
```swift
.package(url: "...FreezeRay", from: "0.5.0")
```

### CLI Users
Reinstall the CLI:
```bash
brew uninstall freezeray    # Old
brew install trinsic/tap/freezeray  # New
```

## Why?

Before: Adding FreezeRay pulled in 7 packages
After: Adding FreezeRay pulls in 2 packages

Your Package.resolved is now cleaner!
```

#### Task 4.3: Update CLAUDE.md
**Owner:** Dev
**Effort:** 30 min

- [ ] Update project structure section
- [ ] Update repository information
- [ ] Add notes about FreezeRayCLI repository
- [ ] Update development workflow
- [ ] Update release process for both repos

#### Task 4.4: Update Examples
**Owner:** Dev
**Effort:** 30 min

- [ ] Update example projects to use FreezeRay v0.5.0
- [ ] Ensure examples show CLI installation separately
- [ ] Test examples end-to-end

### Phase 5: Release & Announce (1 hour)

#### Task 5.1: Release FreezeRay v0.5.0
**Owner:** Dev
**Effort:** 15 min

- [ ] Merge `feature/v0.5.0-package-only` to main
- [ ] Tag release: `v0.5.0`
- [ ] Push tag: `git push origin v0.5.0`
- [ ] Create GitHub release with changelog
- [ ] Verify SPM can resolve the package

**Changelog:**
```markdown
## v0.5.0 - Repository Separation

### Breaking Changes
- **CLI moved to separate repository**: https://github.com/TrinsicVentures/FreezeRayCLI
- Users must reinstall CLI (Homebrew/npm) - see migration guide

### Improvements
- **Clean dependencies**: Package users no longer get CLI dependencies
- **Faster resolution**: 5 fewer packages to resolve
- **Smaller package**: FreezeRay package is now lightweight

### Migration
See MIGRATION.md for upgrade instructions.
```

#### Task 5.2: Release FreezeRayCLI v1.0.0
**Owner:** Dev
**Effort:** 15 min

- [ ] Tag release: `v1.0.0`
- [ ] Create GitHub release with binaries
- [ ] Update Homebrew formula with new version
- [ ] Publish to npm: `npm publish`
- [ ] Verify installations work

**Changelog:**
```markdown
## v1.0.0 - Initial Release

FreezeRayCLI is now a separate tool!

### Installation
- Homebrew: `brew install trinsic/tap/freezeray`
- npm: `npm install -g @trinsic/freezeray`

### Requirements
- Requires FreezeRay package v0.5.0+
```

#### Task 5.3: Announce Changes
**Owner:** Dev / Product
**Effort:** 30 min

- [ ] Post to GitHub Discussions
- [ ] Update project website (if exists)
- [ ] Tweet/blog post (if applicable)
- [ ] Email existing users (if list exists)
- [ ] Update README badges to point to new repos

**Announcement template:**
```markdown
# FreezeRay v0.5.0: CLI Separation

We've split FreezeRay into two repositories for a cleaner experience!

**Package users**: Your dependencies are now cleaner (5 fewer packages!)
**CLI users**: Reinstall via Homebrew or npm (one-time)

Details: [link to migration guide]
```

---

## Testing Plan

### Pre-Release Testing

#### Test 1: Package-Only User
**Scenario:** User adds FreezeRay v0.5.0 to their project

1. Create fresh Xcode project
2. Add FreezeRay package dependency: `from: "0.5.0"`
3. Resolve packages
4. Verify Package.resolved only has:
   - FreezeRay
   - swift-syntax
5. Add @FreezeSchema macro to schema
6. Build and verify macro expansion works

**Expected:** No CLI dependencies in Package.resolved

#### Test 2: CLI Installation (Homebrew)
**Scenario:** User installs CLI via Homebrew

1. `brew uninstall freezeray` (if old version)
2. `brew install trinsic/tap/freezeray`
3. `freezeray --version`
4. Create test project with schemas
5. `freezeray freeze 1.0.0`
6. Verify fixtures created
7. Verify tests scaffolded

**Expected:** CLI works independently

#### Test 3: CLI Installation (npm)
**Scenario:** User installs CLI via npm

1. `npm uninstall -g @trinsic/freezeray` (if old version)
2. `npm install -g @trinsic/freezeray`
3. `freezeray --version`
4. Run same workflow as Test 2

**Expected:** npm installation works

#### Test 4: E2E Workflow
**Scenario:** User uses both package and CLI together

1. Add FreezeRay v0.5.0 package
2. Install freezeray CLI (Homebrew)
3. Add @FreezeSchema to schemas
4. Run `freezeray init`
5. Run `freezeray freeze 1.0.0`
6. Build and run drift tests
7. Verify tests pass

**Expected:** Complete workflow works end-to-end

#### Test 5: Cross-Repo Compatibility
**Scenario:** Verify CLI works with FreezeRay main branch

1. Clone FreezeRayCLI
2. Update Package.swift to use FreezeRay main branch
3. `swift build`
4. `swift test`

**Expected:** CLI tests pass against latest FreezeRay

### Post-Release Validation

- [ ] Monitor GitHub issues for migration problems
- [ ] Check Package.resolved in sample projects
- [ ] Verify Homebrew installs work
- [ ] Verify npm installs work
- [ ] Test on fresh machines

---

## Rollback Plan

If critical issues arise:

### Option 1: Hotfix (Preferred)
- Release FreezeRay v0.5.1 with fix
- Release FreezeRayCLI v1.0.1 with fix
- Update announcements

### Option 2: Revert (Nuclear)
- Revert FreezeRay to v0.4.2
- Deprecate FreezeRayCLI v1.0.0
- Restore CLI in monorepo
- Announce revert and reason

**Triggers for rollback:**
- SPM cannot resolve FreezeRay v0.5.0
- CLI completely broken
- Critical bugs affecting >50% of users

---

## Dependencies & Blockers

### Dependencies
- [x] ADR-008 approved
- [ ] Sprint plan approved
- [ ] Resources allocated

### Potential Blockers
- GitHub repository creation permissions
- Homebrew tap access
- npm package publishing access
- Time for documentation updates

---

## Success Metrics

### Quantitative
- [ ] FreezeRay Package.resolved: 2 packages (was 7)
- [ ] FreezeRay package size: <200KB source
- [ ] CI passes on both repositories
- [ ] 22 CLI tests still pass in new repo
- [ ] E2E tests pass with separated repos

### Qualitative
- [ ] User feedback positive on cleaner dependencies
- [ ] No critical bugs reported in first week
- [ ] Documentation is clear and helpful
- [ ] Migration is smooth for existing users

---

## Timeline

### Estimated Effort
- **Phase 0 (Pre-Separation Cleanup):** 3 hours ✅ COMPLETE
- **Phase 1 (Prepare):** 1-2 hours
- **Phase 2 (Create CLI Repo):** 2-3 hours
- **Phase 3 (Distribution):** 2-3 hours
- **Phase 4 (Documentation):** 2-3 hours
- **Phase 5 (Release):** 1 hour

**Total:** 11-15 hours (Phase 0 complete, 8-12 hours remaining)

### Proposed Schedule
- **Pre-work:** Phase 0 complete (v0.4.2 released 2025-10-14) ✅
- **Day 1:** Phases 1-2 (Prepare + Create)
- **Day 2:** Phases 3-5 (Distribution + Docs + Release)

---

## Post-Sprint

### Follow-Up Tasks
- [ ] Monitor GitHub issues for 1 week
- [ ] Collect user feedback
- [ ] Update getting-started documentation
- [ ] Create video tutorial showing installation
- [ ] Write blog post about architectural decision

### Future Improvements
- [ ] Automated compatibility testing between repos
- [ ] Shared CI workflow templates
- [ ] Improved cross-repo changelog coordination

---

## References

- **ADR-008:** Repository Separation
- **ADR-007:** npm Binary Distribution
- **ADR-006:** Separate CLI Library Target (monorepo - superseded)
- **User Feedback:** "polluting packages is an absolute nonstarter"

---

## Sprint Completion

**Status:** ✅ COMPLETE (2025-10-15)

### What We Accomplished

1. ✅ Created FreezeRayCLI repository: https://github.com/TrinsicVentures/FreezeRayCLI
2. ✅ Moved CLI code (`freezeray-cli/`, `freezeray-bin/`)
3. ✅ Moved CLI tests (22 tests - all passing)
4. ✅ Moved Mintlify docs to FreezeRayCLI
5. ✅ Cleaned FreezeRay Package.swift (removed CLI targets and dependencies)
6. ✅ FreezeRayCLI is fully independent (doesn't need FreezeRay package dependency!)
7. ✅ Both repositories build successfully
8. ✅ All tests pass (2 macro tests in FreezeRay, 22 CLI tests in FreezeRayCLI)
9. ✅ Updated documentation in both repositories (README.md, CLAUDE.md)
10. ✅ Updated ADR-008 status to "Implemented"

### Impact

**Before:**
- Users adding FreezeRay package: 7 dependencies (FreezeRay, swift-syntax, ArgumentParser, XcodeProj, AEXML, PathKit, Spectre)

**After:**
- Users adding FreezeRay package: 2 dependencies (FreezeRay, swift-syntax)

**Result:** 5 fewer packages! ✨ Clean dependencies for package users.

### Deviations from Plan

1. **CLI Independence:** Discovered CLI doesn't actually need FreezeRay package dependency (it only generates code that imports it). Removed the dependency for even cleaner separation.

2. **No distribution updates yet:** Phases 3-5 (Homebrew, npm, releases) deferred to future work. Current focus was on technical separation.

### Next Steps

- [ ] Update Homebrew formula (when ready to distribute)
- [ ] Update npm package (when ready to distribute)
- [ ] Tag releases (v0.5.0 for FreezeRay, v1.0.0 for FreezeRayCLI)
- [ ] Create migration guide
- [ ] Announce changes

### Lessons Learned

- CLI independence is valuable - doesn't need to import the package it scaffolds code for
- Repository separation was smoother than expected (~4 hours vs estimated 8-12 hours)
- Clean dependencies have significant user experience impact

---

## Approval

**Completed by:** Claude Code
**Reviewed by:** Geordie Kaytes
**Date:** 2025-10-15
