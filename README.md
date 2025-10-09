# FreezeRay ❄️

> Freeze SwiftData schemas for safe production releases

FreezeRay is a command-line tool that generates immutable SQL snapshots of SwiftData schema versions and creates migration smoke tests. It prevents accidental schema changes from reaching production by freezing schemas before release.

## Features

- ❄️ **Freezes schemas** by generating SQL snapshots directly from SwiftData models
- 🧪 **Generates migration smoke tests** to validate migration paths work without crashing
- ✅ **Validates frozen schemas** to prevent breaking changes
- 🔄 **Integrates with CI/CD** (fails builds if schemas change after freeze)
- 📝 **YAML configuration** for explicit control over schema paths
- 🚀 **Fast** - uses SwiftSyntax for AST parsing and direct SQL generation

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

### 1. Create Configuration

Copy the example config and customize for your project:

```bash
cp .freezeray.yml.example .freezeray.yml
```

Edit `.freezeray.yml` to specify your schema files in migration order:

```yaml
schemas:
  - version: 1
    identifier: SchemaV1
    path: app/MyApp/Data/SwiftData/Schemas/SchemaV1.swift
  - version: 2
    identifier: SchemaV2
    path: app/MyApp/Data/SwiftData/Schemas/SchemaV2.swift

fixture_dir: app/MyAppTests/Fixtures/SwiftData
test_output: app/MyAppTests/Generated/MigrationSmokeTests.swift
project: app/MyApp.xcodeproj
scheme: MyApp
test_target: MyAppTests
migration_plan: MigrationPlan
```

### 2. Check Schema Status

```bash
freezeray
```

Output:
```
📋 Schema Status:
   ✅ v1 (frozen)
   ⚠️  v2 (not frozen)
```

### 3. Freeze Unfrozen Schemas

```bash
freezeray --freeze
```

This generates SQL snapshots for any unfrozen schema versions in `fixture_dir`.

### 4. Generate Migration Smoke Tests

```bash
freezeray --generate-tests
```

Creates a test file that validates your migration path works without crashing.

## How It Works

### Schema Detection

FreezeRay scans your project for schema version files:

```
YourApp/
  Data/
    SwiftData/
      Schemas/
        SchemaV1.swift  ← Detected as v1
        SchemaV2.swift  ← Detected as v2
        SchemaV3.swift  ← Detected as v3
```

### Freezing Process

1. Generates an empty SwiftData store with the schema
2. Exports the SQLite schema as SQL
3. Saves to `YourAppTests/Fixtures/SwiftData/vN-schema.sql`
4. Future test runs compare against this snapshot

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
