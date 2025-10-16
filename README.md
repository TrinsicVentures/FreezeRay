# FreezeRay

**SwiftData schema freezing and migration testing for production iOS apps.**

Stop accidental schema changes from reaching production. FreezeRay creates immutable fixtures that force schema validation in your test suite.

**[📖 Documentation](https://docs.freezeray.dev)** | **[🚀 Quick Start](#quick-start)** | **[💬 Discussions](https://github.com/TrinsicVentures/FreezeRay/discussions)**

---

## The Problems FreezeRay Solves

### 1. Inscrutable Error Messages

SwiftData crashes with cryptic errors that are impossible to diagnose:

```
Cannot use staged migration with an unknown model version
```

```
Persistent store migration failed, missing source managed object model
```

**Root causes:** Accidentally modifying shipped schemas, not including all models from previous versions, changing schemas between builds.

**FreezeRay solution:** Checksum-based drift detection catches schema changes BEFORE they cause SwiftData crashes, with clear, actionable error messages.

### 2. Production Crashes (Not Caught in Testing)

**The silent killer:** Fresh installs work perfectly in your tests. Existing users crash on app launch.

When you modify a shipped `VersionedSchema`, SwiftData's internal hash no longer matches. Fresh simulator tests don't catch this—they skip migration entirely and install the current schema from scratch. But real users with existing databases crash immediately.

**FreezeRay solution:** Frozen fixtures are real SQLite databases from shipped versions. Migration tests load these databases and attempt migration, forcing any crashes to happen in your test suite instead of production.

### 3. Silent Data Loss

**The worst kind of bug:** Migration succeeds without errors or crashes, but data is corrupted or lost.

- Non-optional properties added without defaults → undefined behavior
- Transformable properties that change shape → old data fails to decode, becomes nil
- Properties removed → user data silently dropped
- Type conversions fail silently

**FreezeRay solution:** Scaffolded migration tests include TODO markers guiding you to add custom data integrity checks. Test against actual databases from shipped versions, not fresh installs.

## Layered Defense

FreezeRay provides three layers of protection:

1. **Checksums** (fast, clear errors) - Catches drift before SwiftData crashes
2. **Real migration tests** (forces crashes in tests) - Better to crash in CI than production
3. **Custom validation** (user-defined) - Ensures data integrity after migration

---

## Quick Start

### Install CLI

The FreezeRay CLI is distributed separately from the Swift package.

See **[FreezeRayCLI](https://github.com/TrinsicVentures/FreezeRayCLI)** for installation instructions.

```bash
# npm (when available)
npm install -g @trinsicventures/freezeray

# Or build from source
git clone https://github.com/TrinsicVentures/FreezeRayCLI.git
cd FreezeRayCLI
swift build -c release
```

### Initialize Your Project

```bash
cd YourProject
freezeray init
```

This adds the FreezeRay Swift package and creates the `FreezeRay/` directory structure.

### Annotate Your Schema

```swift
import FreezeRay

@FreezeSchema(version: "1.0.0")
enum AppSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [User.self]
    }
}
```

### Freeze the Schema

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

### Commit to Git

```bash
git add FreezeRay/
git commit -m "Freeze schema v1.0.0"
```

### Run Tests (⌘U in Xcode)

Scaffolded tests automatically validate:
- ✅ **Drift detection** - Schema hasn't changed since frozen
- ✅ **Migration testing** - Migrations work from all previous versions

If the schema changes, tests fail → prevents accidental production breaks.

---

## How It Works

### CLI + Macro Hybrid Architecture

```
┌─────────────────────────────────────┐
│ FreezeRayCLI (separate repo)        │
│ github.com/TrinsicVentures/         │
│           FreezeRayCLI              │
│ • Auto-detects project structure    │
│ • Runs tests in iOS Simulator       │
│ • Extracts fixtures via /tmp        │
│ • Scaffolds validation tests        │
└─────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────┐
│ FreezeRay Package (this repo)       │
│ • @FreezeSchema macro               │
│ • Freeze/validation runtime         │
│ • Type-safe schema operations       │
│ • Added via Swift Package Manager   │
└─────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────┐
│ Your Xcode Project                  │
│ • Schemas with @FreezeSchema        │
│ • Scaffolded tests (user-owned)    │
│ • Frozen fixtures (committed)       │
└─────────────────────────────────────┘
```

**Why separate repositories?** (v0.5.0+)
- Package users get clean dependencies (2 packages instead of 7)
- No CLI-specific dependencies polluting user projects
- CLI and package can evolve independently
- Clearer separation of concerns

**See:** [ADR-008](project/adr/ADR-008-repository-separation.md) for full rationale

---

## Documentation

📖 **[docs.freezeray.dev](https://docs.freezeray.dev)** - Complete documentation

**Key Resources:**
- [Architecture Decision Records](project/adr/) - All technical decisions
- [Sprint Documentation](project/sprints/) - Implementation details
- [Roadmap](project/ROADMAP.md) - Product vision and phases
- [Development Guide](CLAUDE.md) - Testing strategy, CI/CD, workflows

---

## Features

### Convention Over Configuration

No config file needed - CLI auto-detects:
- Xcode project/workspace
- App scheme (prioritizes schemes ending with "App")
- Test target (infers from scheme)
- Schemas (parses `@FreezeSchema` annotations)
- Migration plans (discovers `SchemaMigrationPlan` conformances)

### User-Owned Tests

Tests are **scaffolded once**, not regenerated:
- Generated with TODO markers for custom validation
- User adds data integrity checks
- Becomes part of project's test suite
- Never overwritten by CLI

### Immutable Fixtures

Fixtures are **committed to git**:
- Provides full history and traceability
- Enables code review of schema changes
- Critical for migration testing
- Small size (<1MB typically)

---

## Requirements

- **macOS**: 14+ (for CLI)
- **iOS**: 17+ (for SwiftData)
- **Xcode**: 15+
- **Swift**: 6.0+
- **npm**: For CLI installation (or build from source)

---

## Development

### Build & Test

```bash
swift build                  # Build FreezeRay package
swift test                   # Run unit tests (2 macro tests)
```

### Integration Tests

The FreezeRayTestApp provides end-to-end validation with real schemas:

```bash
cd FreezeRayTestApp
xcodebuild test \
  -project FreezeRayTestApp.xcodeproj \
  -scheme FreezeRayTestApp \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

### CLI Development

For CLI development, see **[FreezeRayCLI](https://github.com/TrinsicVentures/FreezeRayCLI)**

---

## Project Status

**Current Version:** v0.5.0
**Status:** ✅ Repository separation complete

### Completed Phases

- ✅ **Phase 1** (v0.1.0 - v0.3.0): Macro-based foundation
- ✅ **Phase 2** (v0.4.0 - v0.4.2): CLI architecture + public release
  - ✅ `freezeray freeze` command
  - ✅ `freezeray init` command
  - ✅ Auto-detection (project, scheme, schemas, migration plans)
  - ✅ Simulator orchestration
  - ✅ Fixture extraction via `/tmp`
  - ✅ Test scaffolding (drift + migration)
  - ✅ npm distribution
  - ✅ Documentation site (docs.freezeray.dev)
- ✅ **Phase 2.5** (v0.5.0): Repository separation
  - ✅ Split CLI into [FreezeRayCLI](https://github.com/TrinsicVentures/FreezeRayCLI)
  - ✅ Clean package dependencies (2 packages instead of 7)
  - ✅ Independent evolution of CLI and package

### Next Phase

**Phase 3** (v1.0.0): Production Readiness
- Comprehensive documentation (fill placeholder pages)
- Custom branding for docs site
- Homebrew distribution
- CI/CD automation
- Performance optimization

See [ROADMAP.md](project/ROADMAP.md) for complete vision including GUI app (Phase 6).

---

## Contributing

This project follows strict architectural discipline:

1. All architectural decisions documented in [ADRs](project/adr/)
2. All changes must align with documented design decisions
3. Full test coverage required (2 macro tests in this repo, 22 CLI tests in FreezeRayCLI)
4. E2E validation before merge (FreezeRayTestApp)

See [CLAUDE.md](CLAUDE.md) for complete development workflow.

---

## License

MIT License - see [LICENSE](LICENSE)

Copyright © 2025 Trinsic Ventures

---

## Built With

**FreezeRay Package:**
- [SwiftSyntax](https://github.com/apple/swift-syntax) - Macro implementation

**FreezeRayCLI** (separate repo):
- [ArgumentParser](https://github.com/apple/swift-argument-parser) - CLI framework
- [SwiftSyntax](https://github.com/apple/swift-syntax) - AST parsing for schema discovery
- [XcodeProj](https://github.com/tuist/xcodeproj) - Xcode project modification
- [Mintlify](https://mintlify.com) - Documentation platform

---

**Maintained by:** Geordie Kaytes ([@didgeoridoo](https://github.com/didgeoridoo))
**Organization:** [Trinsic Ventures](https://github.com/TrinsicVentures)
**Website:** https://freezeray.dev
**Documentation:** https://docs.freezeray.dev
