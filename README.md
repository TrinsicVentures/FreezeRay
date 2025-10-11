# FreezeRay ❄️

**Freeze SwiftData schemas for safe production releases**

FreezeRay is a **CLI tool + Swift macro package** that freezes SwiftData schema versions and validates migration paths. It prevents accidental schema changes from reaching production by creating immutable fixtures.

---

## Quick Start

### 1. Install FreezeRay CLI

```bash
# Build from source
git clone https://github.com/didgeoridoo/FreezeRay.git
cd FreezeRay
swift build -c release
cp .build/release/freezeray /usr/local/bin/
```

### 2. Add Package Dependency

Add to your Xcode project via File → Add Package Dependencies:
```
https://github.com/didgeoridoo/FreezeRay.git
```

Or via `Package.swift`:
```swift
dependencies: [
    .package(url: "https://github.com/didgeoridoo/FreezeRay.git", from: "0.4.0")
]
```

### 3. Annotate Your Schemas

```swift
import SwiftData
import FreezeRay

@FreezeRay.FreezeSchema(version: "1.0.0")
enum AppSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [User.self]
    }
}

@FreezeRay.FreezeSchema(version: "2.0.0")
enum AppSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] {
        [User.self, Post.self]
    }
}
```

### 4. Freeze Your Schema

```bash
cd YourProject
freezeray freeze 1.0.0
```

**Output:**
```
✅ Schema v1.0.0 frozen successfully!

📝 Next steps:
   1. Review fixtures: FreezeRay/Fixtures/1.0.0/
   2. Commit to git: git add FreezeRay/
   3. Add validation tests (optional)
```

**Generated artifacts:**
```
YourProject/
└── FreezeRay/
    └── Fixtures/
        └── 1.0.0/
            ├── App-1_0_0.sqlite       # Frozen schema database
            ├── App-1_0_0.sqlite-shm   # SQLite shared memory
            ├── schema-1_0_0.json      # Schema metadata
            ├── schema-1_0_0.sql       # SQL DDL export
            ├── schema-1_0_0.sha256    # Checksum for drift detection
            └── export_metadata.txt    # Export info
```

---

## How It Works

### The Problem

SwiftData migrations are fragile. A tiny schema change can:
- Crash your app on launch
- Delete user data silently
- Break CloudKit sync
- Corrupt existing databases

**You won't know until users complain.**

### The Solution

FreezeRay makes schemas immutable once shipped:

1. **Freeze on release** - Run `freezeray freeze 1.0.0` before shipping
2. **Commit fixtures** - Schema artifacts go in version control
3. **Prevent drift** - Build fails if frozen schema changes
4. **Test migrations** - Validate migrations from all frozen versions

### Real-World Example

**Without FreezeRay:**
```swift
// Shipped v1.0.0 with this schema
enum AppSchemaV1: VersionedSchema {
    static var models: [any PersistentModel.Type] {
        [User.self]
    }
}

// Later, during v1.1.0 development...
enum AppSchemaV1: VersionedSchema {  // ⚠️ Accidentally modified V1!
    static var models: [any PersistentModel.Type] {
        [User.self, Post.self]  // Added Post - BREAKING!
    }
}
```

**Result:** v1.1.0 ships, users' databases fail to migrate, app crashes.

**With FreezeRay:**
```
❌ Schema drift detected in frozen version 1.0.0

Expected checksum: 0cc298858e409d8beaac66dbea3154d51271bad7...
Actual checksum:   26d70c10e9febf7f2da4657816cb936b5d0b4460...

Frozen schemas are immutable - create a new schema version instead.
```

Build fails before you even commit. Crisis averted.

---

## The Three Problems FreezeRay Solves

### 1. Inscrutable SwiftData Error Messages

**The Problem:** SwiftData crashes are cryptic and hard to diagnose.

Common errors from Apple Developer Forums:
- `Cannot use staged migration with an unknown coordinator model version` ([thread](https://developer.apple.com/forums/thread/778615))
- `Cannot use staged migration with an unknown model version` ([Stack Overflow](https://stackoverflow.com/questions/78958039/swiftdata-migration-crash-cannot-use-staged-migration-with-an-unknown-model-ver))
- `Attempting to retrieve an NSManagedObjectModel version checksum while the model is still editable` ([thread](https://developer.apple.com/forums/thread/761735))
- `Persistent store migration failed, missing source managed object model` (NSError 134130)

**Root cause sources:**
- Not including all models from previous schemas in new schema versions ([Apple Forums](https://developer.apple.com/forums/thread/738812))
- Changing schema files between builds ([Stack Overflow](https://stackoverflow.com/questions/78756798))
- Migrating from unversioned to versioned in one release ([Mert Bulan](https://mertbulan.com/programming/never-use-swiftdata-without-versionedschema))

**How FreezeRay helps:** Clear diff detection with actionable messages. Instead of "unknown model version", you get:
```
❌ Schema drift detected in frozen version 1.0.0
Expected checksum: 0cc298858e409d8b...
Actual checksum:   26d70c10e9febf7f...
→ Frozen schemas are immutable - create a new schema version instead.
```

### 2. Schema Drift Crashes in Production (Not Caught in Testing)

**The Problem:** Fresh installs work fine in testing, but existing users crash on app launch.

When you modify a shipped `VersionedSchema` (adding models, changing properties), SwiftData's internal hash no longer matches the version identifier. Fresh simulator installs don't hit this - they skip migration entirely. But real users with existing databases crash immediately with errors like `Cannot use staged migration with an unknown model version`.

**Why testing misses it:** Your tests use fresh simulators that install the current schema from scratch. Migration paths are never exercised unless you explicitly test against old database files.

**How FreezeRay prevents it:** Frozen fixtures are canonical snapshots of what shipped. Drift detection fails your build if a frozen schema changes, forcing you to create a new schema version instead of accidentally modifying an existing one.

### 3. Migration Data Integrity Issues

**The Problem:** Migrations complete without crashing but silently lose or corrupt data.

Migration can succeed (no crashes, no errors) but:
- Non-optional properties added without defaults → undefined behavior, possible data loss
- Transformable properties (custom structs/enums) that change shape → old data fails to decode, fields become nil
- Properties removed from schemas → user data silently dropped
- Type conversions (String → Int) → conversion failures lost silently

**Real reports:**
- "Custom migration always fails" ([Stack Overflow](https://stackoverflow.com/questions/79536880))
- Custom `MigrationStage` implementations that don't preserve all data relationships

**How FreezeRay helps:** Migration test scaffolding makes integrity checks first-class. Tests load frozen fixtures, apply your migration plan, and let you validate:
```swift
@Test func testMigrateV1toV2() throws {
    try AppMigrations.__freezeray_test_migrate_1_0_0_to_2_0_0()
    // TODO: Verify record counts match
    // TODO: Check required fields preserved
    // TODO: Validate data relationships intact
}
```

You test migrations against actual databases from shipped versions, not fresh installs.

---

## Architecture

FreezeRay uses a **hybrid CLI + macro approach**:

### Freeze Operation (Explicit, CLI-driven)
```bash
freezeray freeze 1.0.0
```

1. **AST parsing** - Discovers `@FreezeSchema(version: "1.0.0")` annotations via SwiftSyntax
2. **Test generation** - Creates temporary XCTest that calls freeze function
3. **Simulator execution** - Runs test in iOS Simulator via `xcodebuild test`
4. **Fixture creation** - FreezeRayRuntime creates SQLite DB, exports schema, calculates checksums
5. **Extraction** - CLI extracts fixtures from `/tmp` (where runtime exports them)
6. **Project integration** - Copies fixtures to `FreezeRay/Fixtures/{version}/`

### Validation (Automatic, Test-driven)

**Coming in v0.5.0:** Generated validation tests that run in your normal test suite:

```swift
import Testing
import FreezeRay

@Test("Schema v1.0.0 drift detection")
func testSchemaV1Drift() throws {
    try AppSchemaV1.__freezeray_check_1_0_0()
}

@Test("Migration v1.0.0 → HEAD")
func testMigrationV1toHEAD() throws {
    // Load frozen fixtures from bundle
    // Apply migration plan
    // Validate data integrity
}
```

---

## CLI Commands

### `freezeray freeze <version>`

Freezes a schema version by running tests in iOS Simulator and extracting fixtures.

**Options:**
- `--project <path>` - Path to `.xcodeproj` (auto-detected if omitted)
- `--scheme <name>` - Xcode scheme to use (auto-detected if omitted)
- `--simulator <name>` - Simulator name (default: "iPhone 16")

**Example:**
```bash
freezeray freeze 2.1.0 --scheme MyApp --simulator "iPhone 15 Pro"
```

**Auto-detection:** For standard projects, just `freezeray freeze 2.1.0` works!

**Workflow:**
1. Discovers `@FreezeSchema(version: "2.1.0")` annotation in your code
2. Generates temporary test file
3. Builds and runs test in simulator
4. Extracts fixtures from simulator sandbox
5. Copies to `FreezeRay/Fixtures/2.1.0/`

---

## Design Principles

### 1. Convention Over Configuration

Zero config for standard Xcode projects:
- **Project:** Auto-discovered (`.xcodeproj` or `.xcworkspace`)
- **Scheme:** Auto-detected via `xcodebuild -list`
- **Test Target:** `{Scheme}Tests`

### 2. Fixtures Committed to Git

Schema artifacts are first-class citizens:
- Full history and traceability
- Enable code review of schema changes
- Critical for migration testing
- Typically small (<1MB per version)

### 3. iOS Simulator as Source of Truth

Freeze operations run in real iOS Simulator environment:
- Same SwiftData behavior as production app
- Reliable SQLite database generation
- No platform discrepancies

### 4. /tmp Export for Fixture Extraction

**Key insight:** XCTest runs in ephemeral `XCTestDevices/` directories that are cleaned up immediately.

**Solution:** FreezeRayRuntime automatically exports fixtures to `/tmp/FreezeRay/Fixtures/{version}/` during iOS simulator test execution using conditional compilation:

```swift
#if targetEnvironment(simulator) && os(iOS)
// Copy fixtures to /tmp for CLI extraction
let tmpExportDir = URL(fileURLWithPath: "/tmp/FreezeRay/Fixtures/\(version)")
// ... copy all files ...
#endif
```

This allows the CLI to extract fixtures after test completes, even though the test sandbox is destroyed.

### 5. Dynamic Test Generation

CLI generates test files on-the-fly instead of maintaining scaffolds:
- Works with any version number format
- No pre-made test files to maintain
- Xcode folder references auto-discover new files
- Automatic cleanup after execution

---

## File Structure

```
YourProject/
├── FreezeRay/                       # Created by CLI
│   └── Fixtures/
│       ├── 1.0.0/
│       │   ├── App-1_0_0.sqlite
│       │   ├── schema-1_0_0.json
│       │   ├── schema-1_0_0.sql
│       │   ├── schema-1_0_0.sha256
│       │   └── export_metadata.txt
│       └── 2.0.0/
│           └── ...
│
├── YourApp/
│   ├── Models/
│   │   ├── User.swift
│   │   └── Post.swift
│   └── Schemas.swift                # @Freeze annotations here
│
└── YourAppTests/
    └── ...
```

**Commit everything in `FreezeRay/` to git!**

---

## Versioning Best Practices

### When to Freeze a Schema

Freeze schemas at **release milestones**:
- ✅ Before submitting to App Store
- ✅ After QA approval
- ✅ When creating release branch
- ❌ NOT on every commit during development

### Version Numbering

Use semantic versioning that matches your app version:
```swift
@FreezeRay.Freeze(version: "1.0.0")   // Initial release
@FreezeRay.Freeze(version: "1.1.0")   // Minor update
@FreezeRay.Freeze(version: "2.0.0")   // Major update
```

### Schema Evolution Workflow

```
1. Development (v1.0.0 shipped)
   └── AppSchemaV1 (frozen, immutable)
   └── AppSchemaV2 (work in progress, mutable)

2. Ready to ship v1.1.0
   └── freezeray freeze 1.1.0
   └── AppSchemaV1 (frozen)
   └── AppSchemaV2 (frozen as "1.1.0")
   └── git commit -m "Freeze schema v1.1.0"

3. Start next version
   └── AppSchemaV1 (frozen)
   └── AppSchemaV2 (frozen as "1.1.0")
   └── AppSchemaV3 (new, work in progress)
```

---

## Migration Testing

**Coming in v0.5.0:** Automatic migration smoke tests.

```swift
@FreezeRay.TestMigrations
enum AppMigrations: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [AppSchemaV1.self, AppSchemaV2.self, AppSchemaV3.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2, migrateV2toV3]
    }
}
```

**Generated tests will:**
1. Load each frozen fixture
2. Apply migration plan to current HEAD schema
3. Verify migrations complete without errors
4. Validate basic data integrity

---

## Requirements

- **macOS:** 14.0+
- **iOS:** 17.0+
- **Xcode:** 16.0+
- **Swift:** 6.0+
- **SwiftData:** Required

---

## Current Status: v0.4.0

| Feature | Status |
|---------|--------|
| CLI tool | ✅ Complete |
| AST parsing | ✅ Complete |
| Simulator orchestration | ✅ Complete |
| Fixture generation | ✅ Complete |
| Fixture extraction | ✅ Complete |
| Auto-detection | ✅ Complete |
| Dynamic test generation | ✅ Complete |
| Validation test scaffolding | 🚧 Planned (v0.5.0) |
| Migration testing | 🚧 Planned (v0.5.0) |
| Drift detection tests | 🚧 Planned (v0.5.0) |

### Roadmap

**v0.5.0 (Next):**
- `freezeray check` - Drift detection command
- `freezeray migrate` - Migration testing command
- Validation test scaffolding
- Migration smoke tests

**v1.0.0 (Target):**
- Homebrew installation
- Public release
- Comprehensive documentation
- Example projects

---

## Documentation

- **[CLI-DESIGN.md](docs/CLI-DESIGN.md)** - Architecture and design decisions
- **[CLI-IMPLEMENTATION-NOTES.md](docs/CLI-IMPLEMENTATION-NOTES.md)** - Implementation details and learnings
- **[CLAUDE.md](CLAUDE.md)** - Developer guide (testing, CI, releases)
- **[CHANGELOG.md](CHANGELOG.md)** - Version history

---

## Contributing

See [CLAUDE.md](CLAUDE.md) for development workflow and testing guidelines.

**Key areas for contribution:**
1. Validation test scaffolding
2. Migration testing implementation
3. Configuration file support
4. Platform support (visionOS, watchOS)
5. Documentation and examples

---

## Troubleshooting

### CLI can't find project

**Solution:** Specify explicitly:
```bash
freezeray freeze 1.0.0 --project MyApp.xcodeproj --scheme MyApp
```

### Test fails to compile

**Issue:** Test target might be empty or misconfigured.

**Solution:** Ensure test target has at least one Swift file:
```swift
// MyAppTests/EmptyTests.swift
import XCTest
final class EmptyTests: XCTestCase { }
```

### Fixtures not extracted

**Issue:** Runtime might not be exporting to `/tmp`.

**Debug:**
1. Check `/tmp/FreezeRay/Fixtures/{version}/` exists after test
2. Verify `@Freeze` annotation is correct
3. Check xcodebuild output for test errors
4. Run test manually in Xcode (⌘U) to see errors

### Simulator not found

**List available simulators:**
```bash
xcrun simctl list devices available | grep iPhone
```

**Use exact name:**
```bash
freezeray freeze 1.0.0 --simulator "iPhone 16"
```

---

## License

MIT License - see [LICENSE](LICENSE)

---

## Credits

Built by [Trinsic Ventures](https://trinsic.ventures) for the [Clearly](https://github.com/trinsic/clearly-app) journaling app.

**Powered by:**
- [SwiftSyntax](https://github.com/apple/swift-syntax) - AST parsing and macro implementation
- [SwiftData](https://developer.apple.com/documentation/swiftdata) - Schema and migration framework
- [ArgumentParser](https://github.com/apple/swift-argument-parser) - CLI interface

---

## Star History

⭐ If FreezeRay helps your project, consider starring the repo!

**Share your experience:**
- Twitter: [@trinsicventures](https://twitter.com/trinsicventures)
- Issues: [GitHub Issues](https://github.com/didgeoridoo/FreezeRay/issues)
- Discussions: [GitHub Discussions](https://github.com/didgeoridoo/FreezeRay/discussions)
