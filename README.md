# FreezeRay ❄️

> **Note:** This documentation reflects v0.3.0 (current). For v0.4.0 (CLI-based architecture), see [docs/CLI-DESIGN.md](docs/CLI-DESIGN.md).

**Freeze SwiftData schemas for safe production releases**

FreezeRay is a **Swift macro package** (evolving to CLI tool) that freezes SwiftData schema versions and validates migration paths. It prevents accidental schema changes from reaching production by creating immutable fixtures.

---

## Current Status: v0.3.0

### What Works Today

- ✅ **Macro-based** - Add `@Freeze(version:)` and `@AutoTests` annotations
- ✅ **iOS-native** - SQLite operations using C API (no shell commands)
- ✅ **Cross-platform** - Tests run on both macOS and iOS Simulator
- ✅ **Drift detection** - SHA256-based validation catches schema changes
- ✅ **Migration testing** - Validates migrations from all frozen versions to HEAD

### Known Limitations (v0.3.0)

⚠️ **Critical:** Schema freezing requires write access to source tree, which doesn't work reliably in iOS simulator test sandboxes.

**This is being addressed in v0.4.0** - See [CLI Design Document](docs/CLI-DESIGN.md) for the solution.

---

## Installation

### Swift Package Manager

Add FreezeRay to your test target's dependencies in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/didgeoridoo/FreezeRay.git", from: "0.3.0")
],
targets: [
    .testTarget(
        name: "MyAppTests",
        dependencies: ["FreezeRay"]
    )
]
```

Or add via Xcode: File → Add Package Dependencies → `https://github.com/didgeoridoo/FreezeRay.git`

---

## Quick Start (v0.3.0)

### 1. Annotate Schemas

Add `@FreezeRay.Freeze` to schema versions shipped to production:

```swift
import SwiftData
import FreezeRay

@FreezeRay.Freeze(version: "1.0.0")
enum AppSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [User.self]
    }
}

@FreezeRay.Freeze(version: "2.0.0")
enum AppSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] {
        [User.self, Post.self]
    }
}

// Current HEAD - not frozen yet
enum AppSchemaV3: VersionedSchema {
    static let versionIdentifier = Schema.Version(3, 0, 0)
    static var models: [any PersistentModel.Type] {
        [User.self, Post.self, Comment.self]
    }
}
```

### 2. Annotate Migration Plan

Add `@FreezeRay.AutoTests` to your migration plan:

```swift
@FreezeRay.AutoTests
enum AppMigrations: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [AppSchemaV1.self, AppSchemaV2.self, AppSchemaV3.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2, migrateV2toV3]
    }

    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: AppSchemaV1.self,
        toVersion: AppSchemaV2.self
    )

    static let migrateV2toV3 = MigrationStage.lightweight(
        fromVersion: AppSchemaV2.self,
        toVersion: AppSchemaV3.self
    )
}
```

### 3. Call Generated Methods in Tests

```swift
import Testing
import FreezeRay

@Suite("Schema Tests")
struct SchemaTests {
    @Test("Freeze and validate schemas")
    func testSchemas() throws {
        // Freeze schemas (first run creates fixtures, subsequent runs verify)
        try AppSchemaV1.__freezeray_freeze_1_0_0()
        try AppSchemaV2.__freezeray_freeze_2_0_0()

        // Check for drift (fails if frozen schemas changed)
        try AppSchemaV1.__freezeray_check_1_0_0()
        try AppSchemaV2.__freezeray_check_2_0_0()

        // Test all migrations to HEAD
        try AppMigrations.__freezeray_test_migrations()
    }
}
```

### 4. Run Tests

Press `⌘U` in Xcode or run from CLI:

```bash
swift test
# or
xcodebuild test -scheme MyApp -destination 'platform=iOS Simulator,name=iPhone 16'
```

**First run** generates fixtures:
```
✅ Frozen schema 1.0.0 → FreezeRay/Fixtures/v1/
✅ Frozen schema 2.0.0 → FreezeRay/Fixtures/v2/
✅ Drift detection passed
🧪 Testing migrations for 2 frozen fixture(s)...
   ✅ Migration 1.0.0 → HEAD succeeded
   ✅ Migration 2.0.0 → HEAD succeeded
```

**Subsequent runs** validate against frozen fixtures:
- Schema unchanged: ✅ Tests pass
- Schema changed: ❌ Build fails with drift error

---

## How It Works

### Macro Expansion

The `@FreezeRay.Freeze` macro generates two methods:

```swift
@FreezeRay.Freeze(version: "1.0.0")
enum AppSchemaV1: VersionedSchema { ... }

// Expands to:
#if DEBUG
static func __freezeray_freeze_1_0_0() throws {
    try FreezeRayRuntime.freeze(
        schema: AppSchemaV1.self,
        version: "1.0.0"
    )
}

static func __freezeray_check_1_0_0() throws {
    try FreezeRayRuntime.checkDrift(
        schema: AppSchemaV1.self,
        version: "1.0.0"
    )
}
#endif
```

### Generated Artifacts

Each frozen schema version generates artifacts in `FreezeRay/Fixtures/v{version}/`:

1. **App.sqlite** - SQLite database with the schema
2. **schema.json** - Metadata (entity count, timestamp)
3. **schema.sql** - SQL DDL for the schema
4. **schema.sha256** - SHA256 checksum for drift detection

**Commit these to git!** They represent your production schema contract.

### Drift Detection

When you run `__freezeray_check_X_X_X()`:

1. Creates temporary SQLite database with current schema
2. Exports SQL schema and calculates SHA256 checksum
3. Compares with stored `schema.sha256`
4. **Fails test if checksums don't match** (schema drift detected)

This catches accidental changes like:
- Adding/removing fields
- Changing field types
- Modifying relationships
- Altering indexes

### Migration Testing

When you run `__freezeray_test_migrations()`:

1. Scans `FreezeRay/Fixtures/` for all frozen versions
2. For each version:
   - Copies `App.sqlite` to temp directory
   - Creates `ModelContainer` with HEAD schema + migration plan
   - SwiftData runs migrations automatically
   - Performs basic integrity checks
3. **Fails test if any migration crashes**

---

## Coming Soon: v0.4.0 (CLI-based Architecture)

### The Problem

Current macro-based approach requires filesystem write access to the source tree, which doesn't work in iOS simulator test sandboxes. This limits where and how tests can run.

### The Solution

**Hybrid CLI + Macro approach:**

1. **Explicit freeze operation** (CLI-driven, simulator orchestration):
   ```bash
   freezeray freeze 1.0.0
   ```
   - Runs tests in iOS Simulator
   - Extracts fixtures to project directory
   - Scaffolds validation tests (once, user customizes)

2. **Automatic validation** (macro-based, read-only):
   - Generated tests load fixtures from bundle
   - No filesystem writes needed
   - Runs in normal test suite (⌘U)
   - Works reliably in iOS simulator

### Key Benefits of v0.4.0

- ✅ **iOS-native testing** - Works perfectly in simulator sandbox
- ✅ **Convention over configuration** - Auto-detects project structure
- ✅ **Customizable tests** - Scaffolded once, add your own assertions
- ✅ **Real migration testing** - Exercises actual MigrationPlan code
- ✅ **Great DX** - Simple CLI: `freezeray freeze 1.0.0` does everything

**Read the full design:** [docs/CLI-DESIGN.md](docs/CLI-DESIGN.md)

---

## Why Freeze Schemas?

### The Problem

SwiftData migrations are fragile. A tiny schema change can:
- Crash your app on launch
- Delete user data silently
- Break CloudKit sync
- Cause migration deadlocks
- Corrupt existing databases

**You won't know until users complain.**

### The Solution

FreezeRay makes schemas immutable once shipped:

1. ✅ **Catch drift early** - Build fails if frozen schema changes
2. ✅ **Explicit versioning** - Forces you to create new schema versions
3. ✅ **Migration validation** - Tests prove migrations work
4. ✅ **Code review safety** - Reviewers see fixture diffs
5. ✅ **Production confidence** - Know exactly what schema ships

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

## Requirements

- macOS 14.0+ / iOS 17.0+
- Xcode 16.0+
- Swift 6.0+
- SwiftData

---

## Project Status

| Version | Status | Description |
|---------|--------|-------------|
| v0.1.0 | ✅ Released | Initial macro implementation |
| v0.3.0 | ✅ Released | iOS-native SQLite operations |
| v0.4.0 | 🚧 In Progress | CLI-based architecture |
| v1.0.0 | 🎯 Target | Public release |

---

## Documentation

- **[CLI-DESIGN.md](docs/CLI-DESIGN.md)** - v0.4.0 architecture (source of truth)
- **[CLAUDE.md](CLAUDE.md)** - Developer guide (testing, CI, releases)
- **[CHANGELOG.md](CHANGELOG.md)** - Version history
- **[PLAN.md](PLAN.md)** - (Legacy) Original roadmap

---

## Contributing

See [CLAUDE.md](CLAUDE.md) for development workflow and testing guidelines.

**Key documents:**
1. [docs/CLI-DESIGN.md](docs/CLI-DESIGN.md) - Architectural decisions for v0.4.0
2. [CLAUDE.md](CLAUDE.md) - Development guide
3. [TestApp/](TestApp/) - Integration test bed

---

## License

MIT License - see [LICENSE](LICENSE)

---

## Credits

Built by [Trinsic Ventures](https://trinsic.ventures) for the [Clearly](https://github.com/trinsic/clearly-app) journaling app.

Powered by [SwiftSyntax](https://github.com/apple/swift-syntax) and [SwiftData](https://developer.apple.com/documentation/swiftdata).
