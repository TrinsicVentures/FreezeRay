# ADR-004: Versioned Filenames for Fixtures

**Status:** Accepted
**Date:** 2025-10-10
**Deciders:** Core Team

## Context

When freezing multiple schema versions, we need to store fixtures for each version. Initially, we used simple filenames like `App.sqlite`, `schema.json`, etc., in versioned directories:

```
FreezeRay/Fixtures/
├── 1.0.0/
│   ├── App.sqlite
│   ├── schema.json
│   └── schema.sql
└── 2.0.0/
    ├── App.sqlite
    ├── schema.json
    └── schema.sql
```

### Problem: Xcode Filename Conflicts

Xcode requires **globally unique filenames** even when using folder references (blue folders). When adding `FreezeRay/Fixtures/` to test target, Xcode shows error:

```
Multiple files named "App.sqlite" found in project
```

This prevents building when multiple versions are present.

## Decision

**Use version suffix in filenames** following pattern: `{basename}-{version_safe}.{extension}`

### Pattern

- **Version safe:** Replace `.` with `_` (e.g., `1.0.0` → `1_0_0`)
- **Separator:** Use `-` between basename and version
- **Apply to all fixture files**

### Examples

| Version | Filename Pattern |
|---------|------------------|
| 1.0.0 | `App-1_0_0.sqlite` |
| 1.0.0 | `schema-1_0_0.json` |
| 1.0.0 | `schema-1_0_0.sql` |
| 1.0.0 | `schema-1_0_0.sha256` |
| 2.5.3 | `App-2_5_3.sqlite` |
| 2.5.3 | `schema-2_5_3.json` |

### Structure

```
FreezeRay/Fixtures/
├── 1.0.0/
│   ├── App-1_0_0.sqlite
│   ├── App-1_0_0.sqlite-shm
│   ├── schema-1_0_0.json
│   ├── schema-1_0_0.sql
│   ├── schema-1_0_0.sha256
│   └── export_metadata.txt
└── 2.0.0/
    ├── App-2_0_0.sqlite
    ├── App-2_0_0.sqlite-shm
    ├── schema-2_0_0.json
    ├── schema-2_0_0.sql
    ├── schema-2_0_0.sha256
    └── export_metadata.txt
```

## Consequences

### Positive

- ✅ Avoids Xcode filename conflicts
- ✅ Filenames are self-documenting (version is visible)
- ✅ Supports unlimited schema versions
- ✅ Works with both folder references and file references
- ✅ Easy to identify fixtures by version at a glance

### Negative

- ❌ Filenames are longer
- ❌ Requires version-aware loading in tests (can't just load "App.sqlite")

### Neutral

- Bundle resource loading requires version-specific path:
  ```swift
  Bundle.module.url(
      forResource: "App-1_0_0",
      withExtension: "sqlite",
      subdirectory: "FreezeRay/Fixtures/1.0.0"
  )
  ```

## Implementation

### Runtime (Creating Fixtures)

**File:** `Sources/FreezeRay/FreezeRayRuntime.swift`

```swift
let versionSafe = version.replacingOccurrences(of: ".", with: "_")

// SQLite database
let sqliteFileName = "App-\(versionSafe).sqlite"
let sqliteURL = fixtureDir.appendingPathComponent(sqliteFileName)

// Schema JSON
let jsonFileName = "schema-\(versionSafe).json"
let jsonURL = fixtureDir.appendingPathComponent(jsonFileName)

// Schema SQL
let sqlFileName = "schema-\(versionSafe).sql"
let sqlURL = fixtureDir.appendingPathComponent(sqlFileName)

// Checksum
let checksumFileName = "schema-\(versionSafe).sha256"
let checksumURL = fixtureDir.appendingPathComponent(checksumFileName)
```

### Tests (Loading Fixtures)

Future scaffolded drift tests will use:
```swift
let versionSafe = "1_0_0"
guard let fixtureURL = Bundle.module.url(
    forResource: "App-\(versionSafe)",
    withExtension: "sqlite",
    subdirectory: "FreezeRay/Fixtures/1.0.0"
) else {
    Issue.record("Missing fixture: App-\(versionSafe).sqlite")
    return
}
```

## Alternatives Considered

### 1. Keep Simple Names, Use Nested Directories

**Decision:** Rejected

Keep `App.sqlite` but rely on nested directories for uniqueness.

**Pros:**
- Simpler filenames

**Cons:**
- Doesn't solve Xcode conflict issue
- Xcode requires globally unique names regardless of path

### 2. Use UUID-Based Names

**Decision:** Rejected

Use UUIDs like `App-a1b2c3d4.sqlite`.

**Pros:**
- Guaranteed unique

**Cons:**
- Loses human readability
- Can't identify version from filename
- Harder to debug

### 3. Use Different Basenames Per Version

**Decision:** Rejected

Name files `AppV1.sqlite`, `AppV2.sqlite`, etc.

**Pros:**
- Unique names

**Cons:**
- Requires parsing version from filename
- Inconsistent with schema SQL (`schemaV1.sql`?)
- Less flexible for semantic versions (1.0.1, 2.5.3)

## Migration Path

For existing fixtures using old naming:
1. Rename manually: `App.sqlite` → `App-1_0_0.sqlite`
2. Or re-freeze: `freezeray freeze 1.0.0 --force`

## References

- Implementation: `Sources/FreezeRay/FreezeRayRuntime.swift`
- Xcode project structure: Folder references (blue folders)
- Sprint: project/sprints/v0.4.0-sprint_1-freeze-command.md
