# FreezeRay ❄️

> Freeze SwiftData schemas for safe production releases

FreezeRay is a **Swift macro package** that freezes SwiftData schema versions and validates migration paths. It prevents accidental schema changes from reaching production by creating immutable fixtures during your test runs.

## Features

- ❄️ **Macro-based** - Zero configuration, just add two annotations
- 🧪 **Auto-generates tests** - Schema freezing and migration validation from macros
- 🔒 **Drift detection** - Build fails if frozen schemas change
- 🔄 **Zero orchestration** - Just run tests normally with `⌘U`
- 📦 **Multiple artifacts** - SQLite database, schema JSON, and SHA256 checksum
- 🚀 **Type-safe** - Compiler validates everything

## Installation

### Swift Package Manager

Add FreezeRay to your test target's dependencies in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/didgeoridoo/FreezeRay.git", from: "0.1.0")
],
targets: [
    .testTarget(
        name: "MyAppTests",
        dependencies: ["FreezeRay"]
    )
]
```

## Quick Start

### 1. Annotate Shipped Schemas

Add `@FreezeRay.Freeze` to schema versions you've shipped to production:

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
struct AppMigrations: SchemaMigrationPlan {
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

Press `⌘U` or run tests from CLI:

```bash
swift test
# or
xcodebuild test -scheme MyApp
```

**First run** generates fixtures:
```
✅ Frozen schema 1.0.0 → FreezeRay/Fixtures/1.0.0/
✅ Frozen schema 2.0.0 → FreezeRay/Fixtures/2.0.0/
✅ Drift detection passed
🧪 Testing migrations for 2 frozen fixture(s)...
   Testing migration: 1.0.0 → HEAD
      ✅ Migration succeeded
   Testing migration: 2.0.0 → HEAD
      ✅ Migration succeeded
✅ All migrations passed
```

**Subsequent runs** validate against frozen fixtures:
- If schema unchanged: ✅ Tests pass
- If schema changed: ❌ Build fails with drift error

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

The `@FreezeRay.AutoTests` macro generates:

```swift
@FreezeRay.AutoTests
struct AppMigrations: SchemaMigrationPlan { ... }

// Expands to:
#if DEBUG
static func __freezeray_test_migrations() throws {
    try FreezeRayRuntime.testAllMigrations(
        migrationPlan: AppMigrations.self
    )
}
#endif
```

### Generated Artifacts

Each frozen schema version generates four artifacts in `FreezeRay/Fixtures/{version}/`:

1. **App.sqlite** - Canonical SQLite database with the schema
2. **schema.json** - Structured metadata (entity count, timestamp)
3. **schema.sql** - SQL DDL exported via `sqlite3 .schema`
4. **schema.sha256** - SHA256 checksum of `schema.sql` for drift detection

**Commit these to source control!** They represent your production schema contract.

### Example Artifacts

```
FreezeRay/Fixtures/1.0.0/
  ├── App.sqlite          # Empty database with V1 schema
  ├── schema.json         # {"entities": 1, "timestamp": "2025-10-09T17:10:24Z"}
  ├── schema.sql          # CREATE TABLE ZUSER (Z_PK INTEGER PRIMARY KEY, ...)
  └── schema.sha256       # 0cc298858e409d8beaac66dbea3154d51271bad7...
```

### Drift Detection

When you run `__freezeray_check_X_X_X()`:

1. Creates temporary SQLite database with current schema definition
2. Exports SQL schema and calculates SHA256 checksum
3. Compares with stored `schema.sha256`
4. **Fails test if checksums don't match** (schema drift detected)

This catches accidental changes like:
- Adding/removing fields
- Changing field types
- Adding/removing relationships
- Changing indexes

### Migration Testing

When you run `__freezeray_test_migrations()`:

1. Scans `FreezeRay/Fixtures/` for all frozen versions
2. For each version:
   - Copies `App.sqlite` to temp directory
   - Creates `ModelContainer` with HEAD schema + migration plan
   - SwiftData automatically runs migrations
   - Performs basic integrity checks
3. **Fails test if any migration crashes or errors**

This validates your migration plan works from all historical versions to HEAD.

## Workflow

### When Shipping a New Schema

**Before shipping version 2.0.0:**

```swift
// 1. Add @Freeze to the schema you're shipping
@FreezeRay.Freeze(version: "2.0.0")
enum AppSchemaV2: VersionedSchema { ... }

// 2. Run tests to generate fixtures
swift test  // Creates FreezeRay/Fixtures/2.0.0/

// 3. Commit fixtures to git
git add FreezeRay/Fixtures/2.0.0/
git commit -m "Freeze schema v2.0.0"

// 4. Ship to production
```

**After shipping**, the frozen schema is **immutable**:
- Future test runs verify the schema hasn't changed
- Any accidental changes fail the build
- Forces you to create V3 instead of modifying V2

### When Developing Next Schema

```swift
// HEAD schema - NOT frozen yet
enum AppSchemaV3: VersionedSchema {
    static let versionIdentifier = Schema.Version(3, 0, 0)
    static var models: [any PersistentModel.Type] {
        [User.self, Post.self, Comment.self]  // Keep iterating!
    }
}
```

- Don't add `@Seal` until you ship it
- Migration tests validate V1→V3 and V2→V3 paths automatically
- Schema can change freely during development

## Project Structure

```
YourProject/
  Package.swift
  Sources/
    YourApp/
      Data/
        SchemaV1.swift         ← @FreezeRay.Freeze(version: "1.0.0")
        SchemaV2.swift         ← @FreezeRay.Freeze(version: "2.0.0")
        SchemaV3.swift         ← Current HEAD (not frozen)
        Migrations.swift       ← @FreezeRay.AutoTests
  Tests/
    YourAppTests/
      SchemaTests.swift        ← Calls __freezeray_freeze/check/test methods
  FreezeRay/                   ← ⚠️ COMMIT THIS!
    Fixtures/
      1.0.0/
        App.sqlite
        schema.json
        schema.sql
        schema.sha256
      2.0.0/
        App.sqlite
        schema.json
        schema.sql
        schema.sha256
```

## Integration

### Pre-commit Hook

Ensure schemas are sealed before commits:

```bash
#!/bin/bash
# .git/hooks/pre-commit

swift test --filter SchemaTests || {
    echo "❌ Schema drift detected - create a new schema version"
    exit 1
}
```

### GitHub Actions

```yaml
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - name: Validate schemas
        run: swift test --filter SchemaTests
```

### Xcode Build Phase

Add a "Validate Schemas" build phase that runs before compilation:

```bash
if [ "${CONFIGURATION}" = "Release" ]; then
    swift test --filter SchemaTests || {
        echo "⚠️ Schema drift detected"
        exit 1
    }
fi
```

## Advanced Usage

### Custom Test Organization

You can organize the generated calls however you want:

```swift
@Suite("Schema Integrity")
struct SchemaIntegrityTests {
    @Test("V1 schema is frozen")
    func v1Frozen() throws {
        try AppSchemaV1.__freezeray_freeze_1_0_0()
        try AppSchemaV1.__freezeray_check_1_0_0()
    }

    @Test("V2 schema is frozen")
    func v2Frozen() throws {
        try AppSchemaV2.__freezeray_freeze_2_0_0()
        try AppSchemaV2.__freezeray_check_2_0_0()
    }

    @Test("All migrations work")
    func migrations() throws {
        try AppMigrations.__freezeray_test_migrations()
    }
}
```

### CI-Only Freezing

You can make freezing a no-op locally and only run in CI:

```swift
@Test func freezeSchemas() throws {
    #if CI
    try AppSchemaV1.__freezeray_freeze_1_0_0()
    try AppSchemaV2.__freezeray_freeze_2_0_0()
    #endif
}

@Test func checkDrift() throws {
    // Always check drift (fails if fixtures missing)
    try AppSchemaV1.__freezeray_check_1_0_0()
    try AppSchemaV2.__freezeray_check_2_0_0()
}
```

Then in GitHub Actions:

```yaml
- name: Run tests
  run: swift test
  env:
    CI: 1
```

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
3. ✅ **Migration validation** - Tests prove migrations work from all historical versions
4. ✅ **Code review safety** - Reviewers can see fixture diffs
5. ✅ **Production confidence** - Ship knowing exactly what schema users will get

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
        [User.self, Post.self]  // Added Post - BREAKING CHANGE!
    }
}
```

**Result:** v1.1.0 ships, existing users' databases fail to migrate, app crashes on launch.

**With FreezeRay:**
```swift
@FreezeRay.Freeze(version: "1.0.0")
enum AppSchemaV1: VersionedSchema {
    static var models: [any PersistentModel.Type] {
        [User.self, Post.self]  // Modified
    }
}
```

**Result:**
```
❌ Schema drift detected in frozen version 1.0.0

The frozen schema has changed since it was frozen.
Frozen schemas are immutable - create a new schema version instead.

Expected checksum: 0cc298858e409d8beaac66dbea3154d51271bad7...
Actual checksum:   26d70c10e9febf7f2da4657816cb936b5d0b4460...
```

Build fails before you even commit. Crisis averted.

## Requirements

- macOS 14.0+ / iOS 17.0+
- Xcode 16.0+
- Swift 6.0+
- SwiftData

## FAQ

**Q: When should I freeze a schema?**
A: When you ship it to production. Don't freeze during development.

**Q: Can I change a frozen schema?**
A: No. That's the point. Create a new schema version instead.

**Q: What if I need to fix a frozen schema?**
A: You can't. Ship a new version with the fix and a migration.

**Q: Do I commit the fixtures?**
A: Yes! They're part of your schema contract.

**Q: Can I change the fixture directory?**
A: Not currently. It's always `FreezeRay/Fixtures/{version}/`. This ensures consistency.

**Q: What if I delete a frozen schema version?**
A: The fixtures remain. You can delete old schema code but keep fixtures for migration testing.

**Q: How do I test custom migration logic?**
A: The generated tests only validate migrations don't crash. Write separate tests for data correctness.

**Q: Can I use this with CloudKit?**
A: Yes. The fixtures are local-only (CloudKit disabled). Your app's CloudKit sync is unaffected.

## Contributing

See [PLAN.md](PLAN.md) for the development roadmap.

## License

MIT License - see [LICENSE](LICENSE)

## Credits

Built by [Trinsic Ventures](https://trinsic.ventures) for the [Clearly](https://github.com/trinsic/clearly-app) journaling app.

Powered by [SwiftSyntax](https://github.com/apple/swift-syntax) and [CryptoKit](https://developer.apple.com/documentation/cryptokit).
