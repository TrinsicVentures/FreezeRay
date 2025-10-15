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

```bash
npm install -g @trinsicventures/freezeray
```

<details>
<summary>Apple Silicon only - Intel Macs build from source</summary>

```bash
git clone https://github.com/TrinsicVentures/FreezeRay.git
cd FreezeRay
swift build -c release
cp .build/release/freezeray /usr/local/bin/
```
</details>

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
│ freezeray CLI                       │
│ • Auto-detects project structure    │
│ • Runs tests in iOS Simulator       │
│ • Extracts fixtures via /tmp        │
│ • Scaffolds validation tests        │
└─────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────┐
│ @FreezeSchema macro                 │
│ • Generates freeze methods          │
│ • Generates validation methods      │
│ • Type-safe schema operations       │
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

**Why this approach?**
- Macros alone can't write to iOS simulator sandbox
- CLI orchestrates complex simulator/fixture workflow
- Scaffolded tests allow user customization
- Works with standard Xcode project structure

**See:** [ADR-001](project/adr/ADR-001-cli-macro-hybrid-architecture.md) for full rationale

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

### mise Tasks

FreezeRay uses [mise](https://mise.jdx.dev/) for task automation:

```bash
mise run build        # Build CLI binary
mise run test         # Run unit tests
mise run test:e2e     # Run E2E tests (FreezeRayTestApp)
mise run publish:npm  # Publish to npm
mise run docs:dev     # Run docs locally
mise run clean        # Clean build artifacts
```

### Build & Test

```bash
swift build                  # Build library + CLI
swift test                   # Run unit tests (22 tests)
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

## Project Status

**Current Version:** v0.4.1
**Status:** ✅ CLI-based architecture complete, publicly released

### Completed Phases

- ✅ **Phase 1** (v0.1.0 - v0.3.0): Macro-based foundation
- ✅ **Phase 2** (v0.4.0 - v0.4.1): CLI architecture + public release
  - ✅ `freezeray freeze` command
  - ✅ `freezeray init` command
  - ✅ Auto-detection (project, scheme, schemas, migration plans)
  - ✅ Simulator orchestration
  - ✅ Fixture extraction via `/tmp`
  - ✅ Test scaffolding (drift + migration)
  - ✅ npm distribution
  - ✅ Documentation site (docs.freezeray.dev)

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
3. Full test coverage required (currently 22/22 tests passing)
4. E2E validation before merge

See [CLAUDE.md](CLAUDE.md) for complete development workflow.

---

## License

MIT License - see [LICENSE](LICENSE)

Copyright © 2025 Trinsic Ventures

---

## Built With

- [SwiftSyntax](https://github.com/apple/swift-syntax) - AST parsing for schema discovery
- [ArgumentParser](https://github.com/apple/swift-argument-parser) - CLI framework
- [Swift Testing](https://github.com/apple/swift-testing) - Test scaffolding
- [XcodeProj](https://github.com/tuist/xcodeproj) - Xcode project modification
- [Mintlify](https://mintlify.com) - Documentation platform

---

**Maintained by:** Geordie Kaytes ([@didgeoridoo](https://github.com/didgeoridoo))
**Organization:** [Trinsic Ventures](https://github.com/TrinsicVentures)
**Website:** https://freezeray.dev
**Documentation:** https://docs.freezeray.dev
