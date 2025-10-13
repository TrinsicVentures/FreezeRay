# FreezeRay

**CLI tool + Swift macro package for freezing SwiftData schemas and validating migration paths.**

Prevent accidental schema changes from reaching production by creating immutable fixtures that are committed to git.

---

## Status

**Phase 2 (v0.4.0): ✅ COMPLETE AND VALIDATED**

Core workflow is fully functional:
- ✅ `freezeray freeze <version>` command
- ✅ Auto-detection (project, scheme, schemas)
- ✅ Simulator orchestration
- ✅ Fixture extraction via `/tmp`
- ✅ Test scaffolding (drift + migration)
- ✅ E2E validated with 3 critical bugs fixed

---

## Quick Start

### 1. Add FreezeRay to your project

```swift
// In Package.swift
dependencies: [
    .package(url: "https://github.com/trinsic-ventures/FreezeRay", from: "0.4.0")
]
```

### 2. Annotate your schemas

```swift
import FreezeRay

@FreezeSchema(version: "1.0.0")
enum AppSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [User.self]
    }
}
```

### 3. Freeze the schema

```bash
freezeray freeze 1.0.0
```

**Output:**
```
✅ Schema v1.0.0 frozen successfully!

Artifacts created:
- FreezeRay/Fixtures/1.0.0/App-1_0_0.sqlite
- FreezeRay/Fixtures/1.0.0/schema-1_0_0.json
- FreezeRay/Tests/AppSchemaV1_DriftTests.swift
```

### 4. Commit to git

```bash
git add FreezeRay/
git commit -m "Freeze schema v1.0.0"
```

### 5. Run tests with ⌘U

Scaffolded tests automatically validate:
- **Drift detection**: Schema hasn't changed since frozen
- **Migration testing**: Migrations work from previous versions

---

## How It Works

### The Problem

SwiftData schemas can change accidentally:
- Add a property → breaks existing databases
- Change a relationship → silent data loss
- Rename a model → migration fails

### The Solution

**FreezeRay creates immutable snapshots** of your schemas:

1. **Freeze**: CLI runs tests in simulator, extracts fixtures
2. **Validate**: Tests verify current schema matches frozen fixture
3. **Migrate**: Tests verify migrations work from all frozen versions

If schema changes, tests fail → prevents accidental production breaks.

---

## Architecture

**Hybrid CLI + Macro approach** (see [ADR-001](project/adr/ADR-001-cli-macro-hybrid-architecture.md)):

```
┌─────────────────────────────────────┐
│ freezeray CLI                       │
│ - Auto-detects project              │
│ - Runs tests in simulator           │
│ - Extracts fixtures via /tmp        │
│ - Scaffolds validation tests        │
└─────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────┐
│ @FreezeSchema macro                 │
│ - Generates __freezeray_freeze_*()  │
│ - Generates __freezeray_check_*()   │
│ - Type-safe schema validation       │
└─────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────┐
│ Your Xcode Project                  │
│ - Schemas with @FreezeSchema        │
│ - Scaffolded tests (user-owned)    │
│ - Frozen fixtures (committed)       │
└─────────────────────────────────────┘
```

**Why this approach?**
- Macros alone can't write to iOS simulator sandbox
- CLI orchestrates complex workflow
- Scaffolded tests allow user customization
- Works with standard Xcode project structure

---

## Demo Project

See [FreezeRayTestApp/](FreezeRayTestApp/) for a complete working example:
- 3 schema versions (v1, v2, v3)
- 2 versions frozen (v1, v2)
- Ready to freeze v3 as demo

**Try it:**
```bash
cd FreezeRayTestApp
../.build/debug/freezeray freeze 3.0.0
```

---

## Project Structure

```
FreezeRay/
├── Sources/
│   ├── FreezeRay/              # Swift package (macros + runtime)
│   ├── FreezeRayMacros/        # Macro implementation
│   ├── freezeray-cli/          # CLI library (testable)
│   └── freezeray-bin/          # CLI executable (thin wrapper)
├── Tests/
│   ├── FreezeRayTests/         # Unit tests (macros)
│   └── FreezeRayCLITests/      # Unit tests (CLI)
├── FreezeRayTestApp/           # E2E demo/validation project
├── project/
│   ├── adr/                    # Architecture Decision Records
│   ├── sprints/                # Sprint documentation
│   └── ROADMAP.md              # Product roadmap
├── CLAUDE.md                   # Development guide
└── test-e2e.sh                 # E2E validation script
```

---

## Documentation

| Document | Purpose |
|----------|---------|
| [CLAUDE.md](CLAUDE.md) | Development guide, testing strategy, CI/CD |
| [ROADMAP.md](project/ROADMAP.md) | Product roadmap, phases, features |
| [project/adr/](project/adr/) | Architecture Decision Records (all technical decisions) |
| [project/sprints/](project/sprints/) | Sprint documentation with E2E validation results |
| [FreezeRayTestApp/README.md](FreezeRayTestApp/README.md) | Demo walkthrough |

---

## Key Concepts

### Convention Over Configuration
No config file needed - CLI auto-detects:
- Xcode project/workspace
- App scheme (prioritizes schemes ending with "App")
- Test target (infers from scheme)
- Schemas (parses `@FreezeSchema` annotations)

### User-Owned Tests
Tests are **scaffolded once**, not regenerated:
- Generated with TODO markers
- User adds custom validation
- Becomes part of project's test suite
- Never overwritten

### Immutable Fixtures
Fixtures are **committed to git**:
- Provides full history
- Enables code review
- Critical for migration testing
- Small size (<1MB typically)

---

## Requirements

- **macOS**: 13+ (for CLI)
- **iOS**: 17+ (for SwiftData)
- **Xcode**: 15+
- **Swift**: 6.0+
- **Simulator**: iPhone 17 (standardized for consistency)

---

## Development

### Build & Test
```bash
swift build                  # Build library + CLI
swift test                   # Run unit tests (12 tests)
./test-e2e.sh               # Run E2E validation
```

### Integration Tests
```bash
cd FreezeRayTestApp
xcodebuild test \
  -project FreezeRayTestApp.xcodeproj \
  -scheme FreezeRayTestApp \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

---

## Roadmap

- ✅ **Phase 1**: Foundation (v0.1.0 - v0.3.0)
- ✅ **Phase 2**: CLI Architecture (v0.4.0) ← **WE ARE HERE**
- 📋 **Phase 3**: Production Readiness (v1.0.0)
  - Pre-built binaries
  - Homebrew distribution
  - Comprehensive documentation
  - CI/CD integration

See [ROADMAP.md](project/ROADMAP.md) for full details.

---

## Contributing

This project follows a strict architectural discipline:
1. All architectural decisions documented in [project/adr/](project/adr/)
2. All changes must align with ADRs
3. Full test coverage required
4. E2E validation before merge

See [CLAUDE.md](CLAUDE.md) § Development Workflow

---

## License

MIT License - see [LICENSE](LICENSE)

---

## Acknowledgments

Built with:
- [SwiftSyntax](https://github.com/apple/swift-syntax) for AST parsing
- [ArgumentParser](https://github.com/apple/swift-argument-parser) for CLI
- [Swift Testing](https://github.com/apple/swift-testing) for test scaffolding

---

**Maintained by:** Geordie Kaytes ([@geordiekaytes](https://github.com/geordiekaytes))
**Organization:** Trinsic Ventures
