# ADR-008: Separate FreezeRayCLI into Independent Repository

**Status:** ✅ Accepted and Implemented
**Date:** 2025-10-15
**Implemented:** 2025-10-15
**Context:** Post v0.4.2 - CLI Auto-Integration Complete

---

## Context

FreezeRay currently exists as a monorepo containing both:
1. **FreezeRay package** (macro + runtime) - Used by app developers via SPM
2. **freezeray CLI** (command-line tool) - Used to freeze schemas and scaffold tests

**Critical Problem Discovered:** When users add FreezeRay as a package dependency, Swift Package Manager resolves **all** dependencies in Package.swift, including CLI-specific dependencies:

```swift
// Current Package.swift
dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
    .package(url: "https://github.com/apple/swift-syntax", from: "600.0.0"),
    .package(url: "https://github.com/tuist/XcodeProj", from: "8.0.0"),  // ← CLI only!
    // ...
]
```

**User Impact:**
- App developers only need `FreezeRay` (macro + runtime)
- But they get `XcodeProj`, `ArgumentParser`, `SwiftSyntax` resolved in their package graph
- Increases dependency resolution time
- Pollutes Package.resolved with ~7 unnecessary packages
- Goes against Swift Package Manager best practices

**Evidence:**
```
# User's Package.resolved after adding FreezeRay:
- AEXML (4.7.0)                    ← XcodeProj dependency
- PathKit (1.0.1)                  ← XcodeProj dependency
- Spectre (0.10.1)                 ← XcodeProj dependency
- XcodeProj (8.27.7)               ← CLI-only dependency
- swift-argument-parser (1.6.2)    ← CLI-only dependency
- swift-syntax (600.0.1)           ← CLI + Macro dependency (kept)
- FreezeRay (0.4.2)                ← What they actually need
```

**User Quote (from testing):**
> "in the 'testfreeze' project in the package dependencies... i think we have to split the repo. polluting packages is an absolute nonstarter for a tool that will be used by ios devs focused on safety and quality"

## Decision

**Split FreezeRay into two independent repositories:**

### Repository 1: `FreezeRay` (Package)
**Purpose:** Swift package for schema freezing and validation
**URL:** `https://github.com/TrinsicVentures/FreezeRay`
**Distribution:** Swift Package Manager

**Contents:**
```
FreezeRay/
├── Package.swift                    # Clean dependencies
├── Sources/
│   ├── FreezeRay/                  # Macro declarations + runtime
│   └── FreezeRayMacros/            # Macro implementation
├── Tests/
│   └── FreezeRayTests/             # Unit tests
└── FreezeRayTestApp/               # E2E test bed
```

**Package.swift (Clean):**
```swift
dependencies: [
    .package(url: "https://github.com/apple/swift-syntax", from: "600.0.0"),
    // That's it! No CLI dependencies.
]

products: [
    .library(name: "FreezeRay", targets: ["FreezeRay", "FreezeRayMacros"])
]
```

### Repository 2: `FreezeRayCLI` (Tool)
**Purpose:** Command-line tool for freezing and scaffolding
**URL:** `https://github.com/TrinsicVentures/FreezeRayCLI`
**Distribution:** Homebrew, npm, GitHub Releases

**Contents:**
```
FreezeRayCLI/
├── Package.swift                    # CLI dependencies
├── Sources/
│   ├── freezeray-cli/              # CLI library (testable)
│   └── freezeray-bin/              # CLI executable (thin wrapper)
├── Tests/
│   └── FreezeRayCLITests/          # CLI unit tests
└── README.md                        # CLI installation guide
```

**Package.swift:**
```swift
dependencies: [
    .package(url: "https://github.com/TrinsicVentures/FreezeRay", from: "0.5.0"),
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
    .package(url: "https://github.com/apple/swift-syntax", from: "600.0.0"),
    .package(url: "https://github.com/tuist/XcodeProj", from: "8.0.0"),
]

products: [
    .executable(name: "freezeray", targets: ["freezeray-bin"])
]
```

## Rationale

### Why Separate Repositories?

**1. Clean User Dependencies**
- Users adding FreezeRay package only get `FreezeRay` + `swift-syntax`
- No CLI pollution in their Package.resolved
- Faster dependency resolution

**2. Independent Release Cadence**
- CLI can have breaking changes without affecting package users
- Package can release bug fixes without rebuilding CLI
- Example: CLI v1.2.0 with FreezeRay v0.5.0

**3. Clear Separation of Concerns**
- Package = Runtime library (used in app code)
- CLI = Development tool (not linked into apps)
- Different audiences, different documentation needs

**4. Smaller Package Size**
- FreezeRay package is lightweight (~100KB source)
- CLI with XcodeProj dependencies is larger (~5MB+ with deps)

**5. Distribution Flexibility**
- Package: SPM only
- CLI: Homebrew, npm, GitHub Releases, direct download
- Can update CLI distribution without touching package

### Why This Differs from ADR-006

**ADR-006** (Monorepo with library/executable split):
- ✅ Enables CLI unit testing
- ✅ Keeps version coordination simple
- ❌ Still pollutes user dependencies

**ADR-008** (Separate repositories):
- ✅ Clean user dependencies
- ✅ Independent release cycles
- ✅ Clear separation of concerns
- ⚠️ Requires version coordination strategy

### Version Coordination Strategy

**Problem:** CLI depends on FreezeRay package (uses macro-generated functions).

**Solution - Semantic Versioning with Range Dependencies:**

```swift
// FreezeRayCLI Package.swift
dependencies: [
    .package(url: "https://github.com/TrinsicVentures/FreezeRay", from: "0.5.0")
]
```

**Rules:**
1. **Package breaking changes** (v0.5.0 → v0.6.0): CLI must update dependency range
2. **Package minor/patch** (v0.5.0 → v0.5.1): CLI automatically picks up (no change needed)
3. **CLI can release independently** as long as it uses compatible FreezeRay version

**Example Timeline:**
```
FreezeRay v0.5.0 released
  ↓
FreezeRayCLI v1.0.0 released (depends on FreezeRay ^0.5.0)
  ↓
FreezeRay v0.5.1 bugfix (CLI automatically compatible)
  ↓
FreezeRay v0.6.0 with new macro API
  ↓
FreezeRayCLI v1.1.0 updates to FreezeRay ^0.6.0
```

## Consequences

### Positive

1. ✅ **Clean user dependencies** - No CLI pollution in user projects
2. ✅ **Faster package resolution** - 7 fewer dependencies to resolve
3. ✅ **Independent releases** - CLI and package can evolve separately
4. ✅ **Clear ownership** - Package (library users) vs CLI (tool users)
5. ✅ **Better documentation** - Each repo has focused README
6. ✅ **Smaller package size** - FreezeRay package is lightweight

### Negative

1. ⚠️ **Version coordination required** - Must keep CLI compatible with package
2. ⚠️ **Two CI/CD workflows** - Need to maintain both repos
3. ⚠️ **Migration effort** - One-time cost to split repositories
4. ⚠️ **Documentation updates** - Update README, installation guides, examples

### Mitigation Strategies

**For version coordination:**
- Use semantic versioning strictly
- Document compatibility matrix in FreezeRayCLI README
- CI job that tests CLI against FreezeRay main branch

**For CI/CD:**
- Use shared GitHub Actions workflows (reusable workflows)
- Keep test strategies similar
- Automate releases with tags

## Alternatives Considered

### Alternative 1: Keep Monorepo, Make CLI Dependencies Optional

**Approach:** Use optional dependencies in Package.swift

```swift
.target(
    name: "freezeray-cli",
    dependencies: [
        .product(name: "XcodeProj", package: "XcodeProj", condition: .when(platforms: [.macOS]))
    ]
)
```

**Rejected because:**
- ❌ SPM still resolves all dependencies even if conditional
- ❌ Doesn't actually solve the pollution problem
- ❌ Complexity without benefit

### Alternative 2: Nested Package Structure

**Approach:** FreezeRay repo contains a nested CLI/ directory with its own Package.swift

```
FreezeRay/
├── Package.swift          # FreezeRay package
├── CLI/
│   └── Package.swift      # FreezeRayCLI package
```

**Rejected because:**
- ❌ Not a standard SPM pattern
- ❌ Confusing for users ("which Package.swift?")
- ❌ Tooling doesn't handle nested packages well

### Alternative 3: Keep Everything, Document "Don't Worry"

**Approach:** Accept that users get CLI dependencies, document it's harmless

**Rejected because:**
- ❌ Goes against Swift package best practices
- ❌ User quote: "absolute nonstarter for a tool focused on safety and quality"
- ❌ Unnecessary dependencies are a code smell
- ❌ Shows poor architectural hygiene

## Migration Path

### Phase 1: Prepare FreezeRay Package (v0.5.0)
1. Remove CLI code from Sources/
2. Remove CLI dependencies from Package.swift
3. Keep only FreezeRay + FreezeRayMacros
4. Update tests to remove CLI references
5. Tag and release v0.5.0

### Phase 2: Create FreezeRayCLI Repository
1. Create new GitHub repository: `TrinsicVentures/FreezeRayCLI`
2. Initialize with CLI code from FreezeRay
3. Update Package.swift to depend on FreezeRay v0.5.0
4. Port CLI tests (FreezeRayCLITests)
5. Set up CI/CD workflow
6. Tag and release v1.0.0

### Phase 3: Update Distribution
1. **Homebrew**: Update formula to point to FreezeRayCLI repo
2. **npm**: Update package to fetch from FreezeRayCLI repo
3. **Documentation**: Update all installation guides
4. **GitHub**: Add redirect/deprecation notice to FreezeRay CLI docs

### Phase 4: Deprecation Period
1. Keep CLI in FreezeRay repo for 1 release cycle (v0.5.x)
2. Add deprecation warnings in CLI output
3. After v0.5.x → v0.6.0, remove CLI entirely from FreezeRay

## Implementation Notes

### Dependency Graph After Split

**User's Project:**
```
MyApp
 └─ FreezeRay (package)
     └─ swift-syntax
```

**CLI Tool (separate):**
```
freezeray (CLI binary)
 └─ FreezeRayCLI (executable package)
     ├─ FreezeRay (package) ──┐
     ├─ XcodeProj             │  Different dependency trees!
     ├─ ArgumentParser        │
     └─ swift-syntax ─────────┘
```

**Key Point:** User's app never sees XcodeProj or ArgumentParser.

### CI Strategy

**FreezeRay CI** (package):
```yaml
- Build library
- Run unit tests
- Test on FreezeRayTestApp
- Release to SPM
```

**FreezeRayCLI CI** (tool):
```yaml
- Build CLI
- Run CLI unit tests
- Test E2E workflow
- Build binary releases
- Update Homebrew formula
- Publish to npm
```

**Cross-repo testing:**
- FreezeRayCLI CI runs against FreezeRay main branch
- Alerts if incompatibility detected

## Documentation Updates

### FreezeRay README
```markdown
# FreezeRay

Swift macros for freezing SwiftData schemas and detecting drift.

## Installation

Add to your Package.swift:
```swift
dependencies: [
    .package(url: "https://github.com/TrinsicVentures/FreezeRay", from: "0.5.0")
]
```

## Usage

```swift
@FreezeSchema(version: "1.0.0")
enum SchemaV1: VersionedSchema { }
```

## CLI Tool

For freezing schemas and scaffolding tests, install the CLI:
→ See https://github.com/TrinsicVentures/FreezeRayCLI
```

### FreezeRayCLI README
```markdown
# FreezeRayCLI

Command-line tool for freezing SwiftData schemas.

## Installation

### Homebrew
```bash
brew install trinsic/tap/freezeray
```

### npm
```bash
npm install -g @trinsic/freezeray
```

## Usage

```bash
freezeray init
freezeray freeze 1.0.0
```

Requires the FreezeRay package in your project.
```

## References

- **ADR-006**: Separate CLI Library Target (monorepo approach) - implemented
- **ADR-007**: npm Binary Distribution - needs update for new repo
- **User Feedback**: "polluting packages is an absolute nonstarter"
- **Industry Example**: SwiftLint (monorepo) vs SwiftFormat (monorepo) - but neither pollute user deps

## Status

**✅ Implemented** - Repository separation complete (2025-10-15)

## Implementation Results

1. ✅ Created FreezeRayCLI repository: https://github.com/TrinsicVentures/FreezeRayCLI
2. ✅ Moved CLI code, tests (22 tests), and Mintlify docs to FreezeRayCLI
3. ✅ Cleaned FreezeRay Package.swift - now only depends on swift-syntax
4. ✅ FreezeRayCLI is fully independent - doesn't even need FreezeRay package dependency
5. ✅ Both repositories build and all tests pass
6. ✅ Documentation updated in both repositories

**Impact:**
- Package users: 2 dependencies (was 7) - 5 fewer packages! ✨
- CLI users: No change in functionality
- Both repos can now evolve independently
