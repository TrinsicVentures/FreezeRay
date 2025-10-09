# SampleApp - FreezeRay Demo

Minimal SwiftData app demonstrating FreezeRay macros.

## Schema Versions

- **V1**: User (name, createdAt)
- **V2**: User (name, email, createdAt) - Added email field
- **V3**: User + Post with relationship - Added Post model and relationship

## Usage

```bash
# Build
swift build

# Run tests (generates frozen schemas)
swift test

# View generated frozen schemas
ls Tests/Fixtures/SwiftData/
# v1-schema.sql
# v2-schema.sql
# v3-schema.sql
```

## Generated Tests

The `@FreezeSchema` and `@GenerateMigrationTests` macros generate:

- `test_freezeV1()` - Freeze V1 schema
- `test_freezeV2()` - Freeze V2 schema
- `test_freezeV3()` - Freeze V3 schema
- `test_migrationV1toV3()` - Test full migration path
- `test_migrationV1toV2()` - Test V1→V2 migration
- `test_migrationV2toV3()` - Test V2→V3 migration
