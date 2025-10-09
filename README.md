# FreezeRay ❄️

> Freeze SwiftData schemas for safe production releases

FreezeRay is a **Swift macro package** that generates test methods to freeze SwiftData schema versions and validate migration paths. It prevents accidental schema changes from reaching production by creating immutable SQL snapshots during your test runs.

## Features

- ❄️ **Macro-based** - Tight integration with your codebase via Swift macros
- 🧪 **Auto-generates tests** - Freeze tests and migration smoke tests from annotations
- ✅ **Compile-time validation** - Errors if config missing or malformed
- 🔄 **Zero orchestration** - Just run tests normally with `⌘U`
- 📝 **Minimal config** - Single `.freezeray.yml` with just `fixture_dir`
- 🚀 **Type-safe** - Compiler validates everything

## Installation

### Swift Package Manager

Add FreezeRay to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/trinsic/FreezeRay.git", from: "1.0.0")
]
```

### Homebrew (Coming Soon)

```bash
brew install trinsic/tap/freezeray
```

### Manual

```bash
git clone https://github.com/trinsic/FreezeRay.git
cd FreezeRay
swift build -c release
cp .build/release/freezeray /usr/local/bin/
```

## Quick Start

### 1. Add FreezeRay Package

Add to your test target's dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/trinsic/FreezeRay.git", from: "1.0.0")
]
```

### 2. Create Configuration

Create `.freezeray.yml` in your project root:

```yaml
fixture_dir: app/MyAppTests/Fixtures/SwiftData
```

### 3. Annotate Schemas

Add `@FreezeSchema` to your schema versions:

```swift
import FreezeRay

@FreezeSchema(version: 1)
enum SchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [User.self]
    }
}

@FreezeSchema(version: 2)
enum SchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] {
        [User.self, Post.self]
    }
}
```

### 4. Annotate Migration Plan

Add `@GenerateMigrationTests` to your migration plan:

```swift
import FreezeRay

@GenerateMigrationTests
enum MigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self]
    }
    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }
}
```

### 5. Run Tests

Press `⌘U` or run tests from CLI:

```bash
xcodebuild test -scheme MyApp
```

The macros generate:
- `test_freezeV1()` - Exports v1-schema.sql
- `test_freezeV2()` - Exports v2-schema.sql
- `test_migrationV1toV2()` - Validates V1→V2 works
- `test_migrationV1toV2()` - Validates full path works

## How It Works

### Macro Expansion

The `@FreezeSchema` macro expands to:

```swift
@FreezeSchema(version: 1)
enum SchemaV1: VersionedSchema { ... }

// Expands to:
func test_freezeV1() throws {
    try FreezeRayClient.freezeSchema(
        version: 1,
        schemaType: SchemaV1.self,
        fixtureDir: "app/MyAppTests/Fixtures/SwiftData"
    )
}
```

The `@GenerateMigrationTests` macro expands to:

```swift
@GenerateMigrationTests
enum MigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self, SchemaV3.self]
    }
}

// Expands to:
func test_migrationV1toV3() throws { ... }  // Full path
func test_migrationV1toV2() throws { ... }  // Step 1
func test_migrationV2toV3() throws { ... }  // Step 2
```

### Freezing Process

When you run the generated tests:

1. Creates temporary SwiftData container with the schema
2. Exports SQLite schema using `sqlite3 .schema`
3. Saves to `{fixture_dir}/v{N}-schema.sql`
4. Future runs can compare against this frozen snapshot

### Example Frozen Schema

```sql
-- v2-schema.sql
CREATE TABLE ZEntry (
    Z_PK INTEGER PRIMARY KEY,
    ZDATECODEID VARCHAR,
    ZCREATEDAT TIMESTAMP
);
```

## Project Structure

FreezeRay works with any project structure - just configure paths in `.freezeray.yml`:

```
YourProject/
  .freezeray.yml                    ← Configuration file
  app/
    YourApp/
      Data/SwiftData/Schemas/       ← Schema version files
        SchemaV1.swift
        SchemaV2.swift
    YourAppTests/
      Fixtures/SwiftData/           ← Generated frozen schemas
        v1-schema.sql
        v2-schema.sql
      Generated/                    ← Generated smoke tests
        MigrationSmokeTests.swift
```

## Integration

### Xcode Build Phase

Add a "Freeze Schemas" build phase:

```bash
if [ "${CONFIGURATION}" = "Release" ]; then
    freezeray || (echo "⚠️ Unfrozen schemas detected"; exit 1)
fi
```

### GitHub Actions

```yaml
- name: Validate Schemas
  run: freezeray
```

### Fastlane

```ruby
before_all do
  sh("freezeray")
end
```

## Configuration

FreezeRay requires explicit configuration via `.freezeray.yml`:

```yaml
# Schema versions in migration order
schemas:
  - version: 1
    identifier: SchemaV1
    path: app/MyApp/Data/SwiftData/Schemas/SchemaV1.swift
  - version: 2
    identifier: SchemaV2
    path: app/MyApp/Data/SwiftData/Schemas/SchemaV2.swift

# Output paths
fixture_dir: app/MyAppTests/Fixtures/SwiftData
test_output: app/MyAppTests/Generated/MigrationSmokeTests.swift

# Xcode configuration
project: app/MyApp.xcodeproj
scheme: MyApp
test_target: MyAppTests
migration_plan: MigrationPlan

# Optional: Data namespace prefix (e.g., DataV1, DataV2)
data_namespace_prefix: Data
```

See `.freezeray.yml.example` for a complete template.

## Commands

```bash
freezeray                    # Check status (exit 0 if all frozen, 1 if unfrozen)
freezeray --freeze           # Freeze unfrozen schemas
freezeray --generate-tests   # Generate migration smoke tests
freezeray --config PATH      # Use custom config file path
freezeray --help             # Show all options
```

## Use Cases

### Before Release

```bash
# In your release script
freezeray --freeze
git add app/MyAppTests/Fixtures/SwiftData/*.sql
git commit -m "Freeze schema v3"
git push
```

### CI/CD Gate

```bash
# Fail build if schemas aren't frozen
freezeray || exit 1
```

### Generate Tests

```bash
# Generate migration smoke tests
freezeray --generate-tests

# Run tests to validate migration path
xcodebuild test -scheme MyApp -only-testing:MigrationSmokeTests
```

### Writing Custom Migration Tests

The generated smoke tests only validate that migrations run without crashing. For correctness testing:

```swift
// app/MyAppTests/CustomMigrationTests.swift
func testV1toV2_PreservesUserData() throws {
    // Create V1 container with test data
    let v1Container = try createV1Container(with: testData)

    // Migrate to V2
    let v2Container = try migrateToV2(from: v1Container)

    // Assert data was preserved correctly
    let users = try v2Context.fetch(FetchDescriptor<User>())
    XCTAssertEqual(users.count, 5)
    XCTAssertEqual(users.first?.name, "Alice")
}
```

## Why Freeze Schemas?

### The Problem

SwiftData migrations are fragile. A tiny schema change can:
- Crash your app on launch
- Delete user data silently
- Break CloudKit sync
- Cause migration deadlocks

### The Solution

Freeze schemas before release:
1. ✅ Know exactly what schema ships
2. ✅ Catch accidental changes in code review
3. ✅ Force explicit migration planning
4. ✅ Test migrations with production data

## Requirements

- macOS 13.0+
- Xcode 16.0+
- Swift 6.0+
- SwiftData project structure

## Contributing

See [PLAN.md](PLAN.md) for the public release roadmap.

## License

MIT License - see [LICENSE](LICENSE)

## Credits

Built by [Trinsic Ventures](https://trinsic.ventures) for the [Clearly](https://github.com/trinsic/clearly) journaling app.

Powered by [SwiftSyntax](https://github.com/apple/swift-syntax) for robust Swift parsing.
