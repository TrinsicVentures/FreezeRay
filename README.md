# FreezeRay ❄️

> Freeze SwiftData schemas for safe production releases

FreezeRay is a command-line tool that automatically detects, validates, and freezes SwiftData schema versions in your iOS/macOS projects. It prevents accidental schema changes from reaching production by creating immutable SQL snapshots during your release process.

## Features

- 🔍 **Auto-detects schema versions** by parsing your Swift code (no manual configuration)
- ❄️ **Freezes schemas** by generating SQL snapshots before release
- ✅ **Validates frozen schemas** to prevent breaking changes
- 🔄 **Integrates with CI/CD** (fails builds if schemas change after freeze)
- 🎯 **Zero-config** for standard SwiftData project structures
- 🚀 **Fast** - uses SwiftSyntax for proper AST parsing (no brittle regex)

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

### 1. Check Schema Status

```bash
freezeray
```

Output:
```
📋 Schema Status:
   ✅ v1 (frozen)
   ✅ v2 (frozen)
   ⚠️  v3 (not frozen)
```

### 2. Freeze Unfrozen Schemas

```bash
freezeray --freeze
```

This generates SQL snapshots for any unfrozen schema versions.

### 3. Freeze and Commit (for CI)

```bash
freezeray --freeze --commit
```

Automatically commits frozen schemas with a descriptive message.

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

## Project Structure Requirements

FreezeRay expects this structure (customizable):

```
YourProject/
  app/                              ← Xcode project root
    YourApp/
      Data/SwiftData/Schemas/       ← Schema versions here
        SchemaV1.swift
        SchemaV2.swift
    YourAppTests/
      Fixtures/SwiftData/           ← Frozen schemas saved here
        v1-schema.sql
        v2-schema.sql
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

FreezeRay auto-detects your project structure. For custom layouts, create `.freezeray.yml`:

```yaml
schema_dir: "app/MyApp/Models/Schemas"
fixture_dir: "app/MyAppTests/SchemaSnapshots"
test_file: "app/MyAppTests/SchemaValidationTests.swift"
```

## Commands

```bash
freezeray              # Check status (exit 0 if all frozen, 1 if unfrozen)
freezeray --freeze     # Freeze unfrozen schemas
freezeray --commit     # Freeze and commit with message
freezeray --help       # Show all options
```

## Use Cases

### Before Release

```bash
# In your release script
freezeray --freeze --commit
git push
```

### CI/CD Gate

```bash
# Fail build if schemas aren't frozen
freezeray || exit 1
```

### Manual Verification

```bash
# Check what would change
freezeray --freeze --dry-run
git diff
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
