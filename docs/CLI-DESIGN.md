# FreezeRay CLI Design

**Status:** Proposed
**Created:** 2025-10-10
**Authors:** Core Team

---

## Problem Statement

The current FreezeRay macro-based approach has a critical limitation: **schema freezing requires filesystem write access to the source tree**, which doesn't work in iOS simulator tests.

**Current workflow issues:**
- `@Freeze(version: "1.0.0")` generates `__freezeray_freeze_1_0_0()` function
- Calling this in tests tries to write to `FreezeRay/Fixtures/{version}/` (relative path)
- iOS simulator tests run in sandboxed directories with no write access to source tree
- Tests fail instantly with no clear error message
- Workaround would require macOS test target (poor DX)

**Key insights:**
1. Separate **freeze operations** (explicit, write-heavy) from **validation** (automatic, read-only)
2. Generated tests are **scaffolds** users customize, not untouchable generated code
3. **@AutoTests should exercise the actual MigrationPlan**, not bypass it
4. **Convention over configuration** - no .freezeray.yml needed if you follow defaults

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│ Developer Workflow                                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. Shipping v1.0.0 to production:                         │
│     $ freezeray freeze 1.0.0                               │
│                                                             │
│  2. Generate validation tests:                             │
│     $ freezeray generate tests                             │
│                                                             │
│  3. Normal development:                                     │
│     $ xcodebuild test  (⌘U)                                │
│     → Generated tests validate schema drift automatically  │
│                                                             │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ File Structure (Convention-Based, No Config Required)      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Sources/                                                   │
│    Schemas/                                                 │
│      SchemaV1.swift    ← @Freeze(version: "1.0.0")        │
│      SchemaV2.swift    ← @Freeze(version: "2.0.0")        │
│      Migrations.swift  ← @AutoTests                        │
│                                                             │
│  FreezeRay/            ← Default location (customizable)   │
│    Fixtures/           ← Created by `freezeray freeze`     │
│      v1/                                                    │
│        App.sqlite                                           │
│        schema.json                                          │
│        schema.sha256                                        │
│      v2/                                                    │
│        App.sqlite                                           │
│        schema.json                                          │
│        schema.sha256                                        │
│    Tests/              ← Scaffolded by `freezeray freeze`  │
│      SchemaV1_DriftTests.swift      ← Customizable         │
│      SchemaV2_DriftTests.swift      ← Customizable         │
│      MigrationPlan_Tests.swift      ← Customizable         │
│                                                             │
│  .freezeray.yml        ← OPTIONAL (only for custom setup)  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Complete Workflow

### 1. Initial Setup (Convention-Based)

**No configuration needed if you follow conventions!**

FreezeRay automatically discovers:
- ✅ Project type (`.xcodeproj`, `.xcworkspace`, or `Package.swift`)
- ✅ Schemes (via `xcodebuild -list`)
- ✅ Test target (assumes `{ProjectName}Tests`)
- ✅ Schemas with `@Freeze` macros (scans all Swift files)
- ✅ Migration plans with `@AutoTests` (scans all Swift files)

**Optional `.freezeray.yml` for custom setups:**

```yaml
# Only needed if you don't follow conventions

# Project (auto-detected if omitted)
project: app/Clearly.xcodeproj  # or Package.swift
scheme: Clearly                 # or auto-detected from -list

# Output paths (defaults shown)
freezeray_dir: FreezeRay        # Can customize location
# fixtures_subdir: Fixtures     # Relative to freezeray_dir
# tests_subdir: Tests           # Relative to freezeray_dir

# Advanced: Custom source paths (only if schemas not in standard locations)
# source_paths:
#   - app/Clearly/Data/SwiftData/Schemas
#   - app/Clearly/Models
```

**When you need .freezeray.yml:**
- Non-standard project structure
- Multiple schemes
- Custom output paths
- Schemas in unusual locations

### 2. Developer Workflow: Shipping a Schema Version

**Scenario:** Developer is shipping SchemaV1 to production and needs to freeze it.

```bash
# Step 1: Freeze the schema (automatically scaffolds tests!)
$ freezeray freeze 1.0.0

🔹 Auto-detecting project configuration...
   Found: Clearly.xcodeproj
   Scheme: Clearly (auto-detected)
   Test target: ClearlyTests (auto-detected)

🔹 Parsing source files for @Freeze(version: "1.0.0")...
   Found: SchemaV1 in app/Clearly/Data/SwiftData/Schemas/SchemaV1.swift

🔹 Building test target...
   Building for iOS Simulator (x86_64)...

🔹 Running freeze operation in simulator...
   Starting simulator: iPhone 16
   Running test: SchemaV1.__freezeray_freeze_1_0_0()
   Schema frozen to simulator Documents directory

🔹 Extracting fixtures from simulator...
   Simulator container: ~/Library/Developer/CoreSimulator/Devices/{UUID}/...
   Copying: App.sqlite → FreezeRay/Fixtures/v1/
   Copying: schema.json → FreezeRay/Fixtures/v1/
   Copying: schema.sha256 → FreezeRay/Fixtures/v1/

🔹 Scaffolding validation test (one-time)...
   Created: FreezeRay/Tests/SchemaV1_DriftTests.swift
   ⚠️  This is a SCAFFOLD - customize it with your own assertions!

✅ Schema v1.0.0 frozen successfully!

📝 Next steps:
   1. Review fixtures: FreezeRay/Fixtures/v1/
   2. Customize test: FreezeRay/Tests/SchemaV1_DriftTests.swift
   3. Add FreezeRay/ folder to Xcode project if not already included
   4. Run tests: xcodebuild test -scheme Clearly
   5. Commit to git: git add FreezeRay/
   6. Ship to production

# Tests are now part of your test suite - just run ⌘U!

# Step 3: Run tests to verify
$ xcodebuild test -scheme Clearly

Test Suite 'SchemaV1_ValidationTests' started
Test Case 'validateFrozenSchema' passed (0.023 seconds)
Test Suite 'SchemaV2_ValidationTests' started
Test Case 'validateFrozenSchema' passed (0.019 seconds)
Test Suite 'MigrationPlan_Tests' started
Test Case 'testMigrationV1ToHead' passed (0.145 seconds)
Test Case 'testMigrationV2ToHead' passed (0.132 seconds)

✅ All tests passed

# Step 4: Commit
$ git add ClearlyTests/Fixtures/SwiftData/v1/ ClearlyTests/Generated/
$ git commit -m "Freeze SchemaV1 for v1.0.0 release"
```

**Error handling:**

```bash
# Trying to freeze when fixtures already exist
$ freezeray freeze 1.0.0

❌ Fixtures for v1.0.0 already exist at ClearlyTests/Fixtures/SwiftData/v1/

Frozen schemas are immutable. If you need to update the schema:
  1. Create a new schema version (SchemaV2 with version "2.0.0")
  2. Add a migration from v1.0.0 → v2.0.0
  3. Freeze the new version: freezeray freeze 2.0.0

To overwrite existing fixtures (⚠️  DANGEROUS):
  freezeray freeze 1.0.0 --force

# Using --force flag
$ freezeray freeze 1.0.0 --force

⚠️  WARNING: This will overwrite frozen fixtures for v1.0.0
⚠️  Frozen schemas should be immutable once shipped to production
⚠️  This may break production migrations!

Continue? [y/N]: y

🔹 Removing existing fixtures...
🔹 Freezing schema v1.0.0...
✅ Schema v1.0.0 frozen (fixtures overwritten)
```

### 3. Continuous Integration

```bash
# CI workflow (e.g., GitHub Actions)
- name: Validate schemas
  run: |
    # Generated tests run automatically in test suite
    xcodebuild test -scheme Clearly -destination 'platform=iOS Simulator,name=iPhone 16'

    # If drift detected, tests fail with clear error:
    # ❌ Schema drift detected in v1.0.0
    # Expected checksum: abc123...
    # Actual checksum:   def456...
    # Frozen schemas are immutable. Create a new schema version instead.
```

---

## CLI Commands

### `freezeray freeze <version>`

Freeze a schema version by generating immutable fixture artifacts.

**Usage:**
```bash
freezeray freeze <version> [OPTIONS]

Arguments:
  <version>    Schema version to freeze (e.g., "1.0.0")

Options:
  --force           Overwrite existing frozen fixtures (dangerous!)
  --config PATH     Path to .freezeray.yml (default: .freezeray.yml)
  --simulator NAME  Simulator to use (default: iPhone 16)
  --output DIR      Override fixtures output directory

Examples:
  freezeray freeze 1.0.0
  freezeray freeze 2.0.0 --simulator "iPhone 15 Pro"
  freezeray freeze 1.0.0 --force  # Overwrite existing
```

**What it does:**
1. Parses source files to find `@Freeze(version: "<version>")`
2. Extracts schema type name (e.g., `SchemaV1`)
3. Builds test target for iOS Simulator
4. Launches simulator and runs `SchemaV1.__freezeray_freeze_1_0_0()`
5. Test writes fixtures to simulator's Documents directory
6. CLI finds simulator container and copies fixtures to project
7. Verifies fixtures: `App.sqlite`, `schema.json`, `schema.sha256`
8. Fails if fixtures already exist (unless `--force`)

### `freezeray scaffold <version>`

Scaffold a test file for a frozen schema (rarely needed - `freeze` does this automatically).

**Usage:**
```bash
freezeray scaffold <version> [OPTIONS]

Arguments:
  <version>    Schema version to scaffold test for

Options:
  --force          Overwrite existing test file
  --config PATH    Path to .freezeray.yml

Examples:
  freezeray scaffold 1.0.0
  freezeray scaffold 2.0.0 --force
```

**What it does:**
1. Finds `@Freeze(version: "<version>")` in source files
2. Creates test scaffold in `FreezeRay/Tests/SchemaVX_DriftTests.swift`
3. Test includes TODO markers for custom assertions
4. Skips if test file already exists (unless `--force`)

**Note:** `freezeray freeze` automatically scaffolds tests, so you rarely need this command directly. Use it if you accidentally deleted a test file or want to regenerate the scaffold.

### `freezeray check <version>`

Manually check for schema drift (usually automated via generated tests).

**Usage:**
```bash
freezeray check <version> [OPTIONS]

Arguments:
  <version>    Schema version to check

Options:
  --config PATH     Path to .freezeray.yml
  --verbose         Show detailed diff if drift detected

Examples:
  freezeray check 1.0.0
  freezeray check 2.0.0 --verbose
```

**What it does:**
1. Loads frozen fixtures for specified version
2. Generates current schema in temp directory
3. Compares checksums
4. Reports drift or success

### `freezeray migrate <from> <to>`

Test a specific migration path.

**Usage:**
```bash
freezeray migrate <from> <to> [OPTIONS]

Arguments:
  <from>    Source schema version
  <to>      Target schema version (or "HEAD")

Options:
  --config PATH     Path to .freezeray.yml
  --verbose         Show detailed migration steps

Examples:
  freezeray migrate 1.0.0 HEAD
  freezeray migrate 1.0.0 2.0.0
  freezeray migrate 2.0.0 HEAD --verbose
```

**What it does:**
1. Loads frozen fixture for `<from>` version
2. Copies to temp directory
3. Runs SwiftData migration to `<to>` version
4. Verifies migration succeeds
5. Reports any errors

### `freezeray list`

List all discovered schemas and their freeze status.

**Usage:**
```bash
freezeray list [OPTIONS]

Options:
  --config PATH     Path to .freezeray.yml
  --verbose         Show file paths and checksums

Example output:
  📦 Schemas:
    ✅ v1.0.0  SchemaV1   (frozen: 2025-09-15)
    ✅ v2.0.0  SchemaV2   (frozen: 2025-10-01)
    ❌ v3.0.0  SchemaV3   (not frozen)

  🔄 Migration Plan:
    MigrationPlan
      v1.0.0 → v2.0.0 (lightweight)
      v2.0.0 → v3.0.0 (lightweight)
```

### `freezeray init`

Initialize FreezeRay configuration for a project.

**Usage:**
```bash
freezeray init [OPTIONS]

Options:
  --xcode           Initialize for Xcode project (default if .xcodeproj found)
  --spm             Initialize for Swift Package Manager project
  --interactive     Interactive setup wizard

Examples:
  freezeray init                  # Auto-detect project type
  freezeray init --interactive    # Wizard-based setup
```

**What it does:**
1. Detects project type (Xcode or SPM)
2. Scans for existing schema files
3. Generates `.freezeray.yml` with sensible defaults
4. Creates `Tests/Fixtures/` and `Tests/Generated/` directories
5. Adds `.gitignore` entries if needed

---

## Generated Test Examples

### Drift Detection Test (Scaffolded Once, User Customizes)

**Input:** `SchemaV1.swift` with `@Freeze(version: "1.0.0")`

**Scaffolded:** `FreezeRay/Tests/SchemaV1_DriftTests.swift`

```swift
// 🏗️ SCAFFOLDED by FreezeRay - CUSTOMIZE THIS FILE
// Generated from: Sources/Schemas/SchemaV1.swift
// Annotation: @FreezeRay.Freeze(version: "1.0.0")
// Created: 2025-10-10
//
// This test validates that SchemaV1 has not drifted from its frozen snapshot.
// Add custom assertions below to verify data integrity after loading.

import Testing
import Foundation
import SwiftData
import SQLite3
@testable import Clearly

@Suite("SchemaV1 Drift Detection")
struct SchemaV1_DriftTests {

    @Test("Schema v1.0.0 loads from frozen fixture without crash")
    func loadFrozenFixture() throws {
        // Load frozen fixture from bundle
        let bundle = Bundle(for: type(of: self))
        guard let fixtureURL = bundle.url(
            forResource: "App",
            withExtension: "sqlite",
            subdirectory: "FreezeRay/Fixtures/v1"
        ) else {
            Issue.record("Missing frozen fixture: FreezeRay/Fixtures/v1/App.sqlite")
            return
        }

        // Copy to temp location (ModelContainer needs writable URL)
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        try FileManager.default.copyItem(at: fixtureURL, to: tempURL)

        // Try to open with current SchemaV1 definition
        // THIS WILL CRASH if schema definition incompatible with frozen sqlite
        let config = ModelConfiguration(
            schema: Schema(versionedSchema: SchemaV1.self),
            url: tempURL,
            allowsSave: false,
            cloudKitDatabase: .none
        )

        let container = try ModelContainer(
            for: Schema(versionedSchema: SchemaV1.self),
            configurations: [config]
        )

        let context = ModelContext(container)

        // ✅ If we got here, frozen fixture is compatible with current schema!

        // TODO: Add custom validation below
        // Example: Verify expected entities exist
        // let descriptor = FetchDescriptor<DataV1.User>()
        // let users = try context.fetch(descriptor)
        // #expect(users.count >= 0, "Should be able to query users")
    }

    @Test("Drift detection hint (SQL comparison)", .tags(.hint))
    func checkSQLDrift() throws {
        // This is a HINT, not definitive proof
        // The real validation is whether ModelContainer can load the frozen fixture

        let bundle = Bundle(for: type(of: self))
        guard let checksumURL = bundle.url(
            forResource: "schema",
            withExtension: "sha256",
            subdirectory: "FreezeRay/Fixtures/v1"
        ) else {
            Issue.record("Missing schema.sha256")
            return
        }

        let frozenChecksum = try String(contentsOf: checksumURL)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Generate current schema SQL and compare
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let currentChecksum = try FreezeRayRuntime.calculateSchemaChecksum(
            schema: SchemaV1.self,
            outputURL: tempURL
        )

        #expect(currentChecksum == frozenChecksum, """
            ⚠️  SQL Drift detected in v1.0.0 (HINT - check loadFrozenFixture test for definitive proof)

            Expected checksum: \(frozenChecksum)
            Actual checksum:   \(currentChecksum)

            This suggests the schema definition has changed.
            Run the main test (loadFrozenFixture) to see if it actually breaks compatibility.
            """)
    }
}
```

### Migration Test (Scaffolded Once, User Customizes)

**Input:** `Migrations.swift` with `@AutoTests`

**Scaffolded:** `FreezeRay/Tests/MigrationPlan_Tests.swift`

```swift
// 🏗️ SCAFFOLDED by FreezeRay - CUSTOMIZE THIS FILE
// Generated from: Sources/Schemas/Migrations.swift
// Annotation: @FreezeRay.AutoTests
// Created: 2025-10-10
//
// These tests exercise the REAL MigrationPlan with frozen fixtures.
// Add custom assertions to verify data integrity after migration.

import Testing
import Foundation
import SwiftData
@testable import Clearly

@Suite("MigrationPlan Smoke Tests")
struct MigrationPlan_Tests {

    @Test("Migration v1.0.0 → v2.0.0 (using real MigrationPlan)")
    func migrateV1ToV2() throws {
        let bundle = Bundle(for: type(of: self))
        guard let fixtureURL = bundle.url(
            forResource: "App",
            withExtension: "sqlite",
            subdirectory: "FreezeRay/Fixtures/v1"
        ) else {
            Issue.record("Missing frozen fixture for v1.0.0")
            return
        }

        // Copy fixture to temp location
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        try FileManager.default.copyItem(at: fixtureURL, to: tempURL)

        // Load with V2 schema - this RUNS your MigrationPlan
        // Will CRASH at test-time if migration incompatible
        let config = ModelConfiguration(
            schema: Schema(versionedSchema: SchemaV2.self),
            url: tempURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )

        let container = try ModelContainer(
            for: Schema(versionedSchema: SchemaV2.self),
            migrationPlan: MigrationPlan.self,  // Uses YOUR migration code!
            configurations: [config]
        )

        let context = ModelContext(container)

        // ✅ Migration succeeded!

        // TODO: Add custom validation below
        // Example: Verify data integrity after migration
        // let descriptor = FetchDescriptor<DataV2.User>()
        // let users = try context.fetch(descriptor)
        // #expect(users.count > 0, "Should have migrated users")
        // #expect(users.allSatisfy { $0.email != nil }, "All users should have email after migration")
    }

    @Test("Migration v2.0.0 → HEAD (using real MigrationPlan)")
    func migrateV2ToHead() throws {
        let bundle = Bundle(for: type(of: self))
        guard let fixtureURL = bundle.url(
            forResource: "App",
            withExtension: "sqlite",
            subdirectory: "FreezeRay/Fixtures/v2"
        ) else {
            Issue.record("Missing frozen fixture for v2.0.0")
            return
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        try FileManager.default.copyItem(at: fixtureURL, to: tempURL)

        // Load with HEAD schema - runs migrations v2 → v3
        let headSchema = Schema(versionedSchema: SchemaV3.self)
        let config = ModelConfiguration(
            schema: headSchema,
            url: tempURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )

        let container = try ModelContainer(
            for: headSchema,
            migrationPlan: MigrationPlan.self,  // Uses YOUR migration code!
            configurations: [config]
        )

        let context = ModelContext(container)

        // ✅ Migration succeeded!

        // TODO: Add custom validation below
        // Example: Verify new entities exist
        // let postDescriptor = FetchDescriptor<DataV3.Post>()
        // let posts = try context.fetch(postDescriptor)
        // #expect(posts.count >= 0, "Should be able to query posts table")
    }

    @Test("Migration v1.0.0 → HEAD (multi-step migration)")
    func migrateV1ToHead() throws {
        // This tests the full migration path: v1 → v2 → v3
        let bundle = Bundle(for: type(of: self))
        guard let fixtureURL = bundle.url(
            forResource: "App",
            withExtension: "sqlite",
            subdirectory: "FreezeRay/Fixtures/v1"
        ) else {
            Issue.record("Missing frozen fixture for v1.0.0")
            return
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        try FileManager.default.copyItem(at: fixtureURL, to: tempURL)

        // Load with HEAD - SwiftData runs full migration chain
        let headSchema = Schema(versionedSchema: SchemaV3.self)
        let config = ModelConfiguration(
            schema: headSchema,
            url: tempURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )

        let container = try ModelContainer(
            for: headSchema,
            migrationPlan: MigrationPlan.self,
            configurations: [config]
        )

        let context = ModelContext(container)

        // ✅ Full migration chain succeeded!

        // TODO: Verify end-to-end data integrity
    }
}
```

---

## Implementation Details

### AST Parsing with SwiftSyntax

```swift
// Sources/freezeray-cli/Parser/MacroDiscovery.swift

import SwiftSyntax
import SwiftParser

struct FreezeAnnotation {
    let version: String
    let typeName: String
    let filePath: String
    let lineNumber: Int
}

struct AutoTestsAnnotation {
    let typeName: String
    let filePath: String
    let lineNumber: Int
}

class MacroDiscoveryVisitor: SyntaxVisitor {
    var freezeAnnotations: [FreezeAnnotation] = []
    var autoTestsAnnotations: [AutoTestsAnnotation] = []

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        // Look for @Freeze(version: "X.Y.Z") or @FreezeRay.Freeze(version: "X.Y.Z")
        for attribute in node.attributes {
            if let attr = attribute.as(AttributeSyntax.self) {
                let attrName = attr.attributeName.trimmedDescription

                // Handle both @Freeze and @FreezeRay.Freeze
                if attrName == "Freeze" || attrName.hasSuffix(".Freeze") {
                    if let version = extractVersion(from: attr) {
                        freezeAnnotations.append(FreezeAnnotation(
                            version: version,
                            typeName: node.name.text,
                            filePath: currentFile,
                            lineNumber: node.position.line
                        ))
                    }
                }
            }
        }
        return .visitChildren
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        // Look for @AutoTests
        for attribute in node.attributes {
            if let attr = attribute.as(AttributeSyntax.self) {
                let attrName = attr.attributeName.trimmedDescription

                if attrName == "AutoTests" || attrName.hasSuffix(".AutoTests") {
                    autoTestsAnnotations.append(AutoTestsAnnotation(
                        typeName: node.name.text,
                        filePath: currentFile,
                        lineNumber: node.position.line
                    ))
                }
            }
        }
        return .visitChildren
    }

    private func extractVersion(from attribute: AttributeSyntax) -> String? {
        guard case .argumentList(let arguments) = attribute.arguments else {
            return nil
        }

        for arg in arguments {
            if arg.label?.text == "version" {
                if let stringExpr = arg.expression.as(StringLiteralExprSyntax.self),
                   let segment = stringExpr.segments.first?.as(StringSegmentSyntax.self) {
                    return segment.content.text
                }
            }
        }
        return nil
    }
}

func discoverMacros(in sourcePaths: [String]) throws -> (
    freezeAnnotations: [FreezeAnnotation],
    autoTestsAnnotations: [AutoTestsAnnotation]
) {
    var allFreeze: [FreezeAnnotation] = []
    var allAutoTests: [AutoTestsAnnotation] = []

    for sourcePath in sourcePaths {
        let files = try findSwiftFiles(at: sourcePath)

        for file in files {
            let source = try String(contentsOfFile: file)
            let tree = Parser.parse(source: source)

            let visitor = MacroDiscoveryVisitor()
            visitor.currentFile = file
            visitor.walk(tree)

            allFreeze.append(contentsOf: visitor.freezeAnnotations)
            allAutoTests.append(contentsOf: visitor.autoTestsAnnotations)
        }
    }

    return (allFreeze, allAutoTests)
}
```

### Test Generator

```swift
// Sources/freezeray-cli/Generator/TestGenerator.swift

struct TestGenerator {
    let config: FreezeRayConfig

    func generateDriftTest(for annotation: FreezeAnnotation) throws -> String {
        let template = """
        // ⚠️ AUTO-GENERATED by FreezeRay - DO NOT EDIT
        // Generated from: \(annotation.filePath)
        // Annotation: @FreezeRay.Freeze(version: "\(annotation.version)")
        // Run `freezeray generate tests` to regenerate

        import Testing
        import Foundation
        import SwiftData
        @testable import \(config.target)

        @Suite("\(annotation.typeName) Drift Detection")
        struct \(annotation.typeName)_ValidationTests {

            @Test("Schema v\(annotation.version) has not drifted from frozen snapshot")
            func validateFrozenSchema() throws {
                // [Full test implementation from example above]
            }

            @Test("Frozen fixture integrity")
            func validateFixtureIntegrity() throws {
                // [Full test implementation from example above]
            }
        }
        """

        return template
    }

    func generateMigrationTests(for annotation: AutoTestsAnnotation, schemas: [FreezeAnnotation]) throws -> String {
        // Generate migration tests for each frozen schema version
        var testFunctions = ""

        for schema in schemas {
            testFunctions += """

                @Test("Migration v\(schema.version) → HEAD")
                func testMigrationV\(schema.version.replacingOccurrences(of: ".", with: "_"))ToHead() throws {
                    // [Full test implementation from example above]
                }
            """
        }

        let template = """
        // ⚠️ AUTO-GENERATED by FreezeRay - DO NOT EDIT
        // Generated from: \(annotation.filePath)
        // Annotation: @FreezeRay.AutoTests
        // Run `freezeray generate tests` to regenerate

        import Testing
        import Foundation
        import SwiftData
        @testable import \(config.target)

        @Suite("Migration Smoke Tests")
        struct \(annotation.typeName)_Tests {
            \(testFunctions)
        }
        """

        return template
    }
}
```

### Simulator Orchestration

```swift
// Sources/freezeray-cli/Simulator/SimulatorManager.swift

import Foundation

struct SimulatorManager {
    func runFreezeInSimulator(
        scheme: String,
        testTarget: String,
        schemaType: String,
        version: String,
        simulator: String
    ) throws -> URL {
        // 1. Build test target
        print("🔹 Building test target...")
        try shell("xcodebuild",
            "-scheme", scheme,
            "-destination", "platform=iOS Simulator,name=\(simulator)",
            "build-for-testing"
        )

        // 2. Run freeze test
        print("🔹 Running freeze operation in simulator...")
        let testName = "\(testTarget)/FreezeRay_\(version.replacingOccurrences(of: ".", with: "_"))"
        try shell("xcodebuild",
            "-scheme", scheme,
            "-destination", "platform=iOS Simulator,name=\(simulator)",
            "test-without-building",
            "-only-testing:\(testName)"
        )

        // 3. Find simulator container
        print("🔹 Locating simulator container...")
        let containerPath = try findSimulatorContainer(
            appBundleID: extractBundleID(from: scheme)
        )

        // 4. Return path to FreezeRay fixtures in simulator
        return containerPath
            .appendingPathComponent("Documents")
            .appendingPathComponent("FreezeRay")
            .appendingPathComponent("Fixtures")
            .appendingPathComponent(version)
    }

    private func findSimulatorContainer(appBundleID: String) throws -> URL {
        // Query xcrun simctl to find app container
        let output = try shell("xcrun", "simctl", "get_app_container", "booted", appBundleID, "data")
        let path = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return URL(fileURLWithPath: path)
    }
}
```

### FreezeRayRuntime Changes

```swift
// Sources/FreezeRay/FreezeRayRuntime.swift

@available(macOS 14, iOS 17, *)
public enum FreezeRayRuntime {

    // EXISTING: Write-heavy operation (used by CLI via tests)
    public static func freeze<S: VersionedSchema>(
        schema: S.Type,
        version: String,
        outputDirectory: URL? = nil  // NEW: Allow custom output
    ) throws {
        // Use outputDirectory if provided, otherwise use relative path
        let fixtureDir = outputDirectory ?? URL(fileURLWithPath: "FreezeRay/Fixtures/\(version)")

        // If running in iOS simulator and no custom output, write to Documents
        #if targetEnvironment(simulator) && os(iOS)
        if outputDirectory == nil {
            let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            fixtureDir = documentsDir
                .appendingPathComponent("FreezeRay")
                .appendingPathComponent("Fixtures")
                .appendingPathComponent(version)
        }
        #endif

        // [Rest of existing freeze implementation]
    }

    // NEW: Read-only checksum calculation (used by generated tests)
    public static func calculateSchemaChecksum<S: VersionedSchema>(
        schema: S.Type,
        outputURL: URL
    ) throws -> String {
        // Create schema in temp location
        let swiftDataSchema = Schema(versionedSchema: schema)
        let config = ModelConfiguration(
            schema: swiftDataSchema,
            url: outputURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )

        do {
            let container = try ModelContainer(
                for: swiftDataSchema,
                configurations: [config]
            )
            let context = ModelContext(container)
            try context.save()
        }

        Thread.sleep(forTimeInterval: 0.1)
        try disableWAL(at: outputURL)

        // Export schema SQL
        let tempSQLPath = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sql")
        defer { try? FileManager.default.removeItem(at: tempSQLPath) }

        try exportSchemaSQL(from: outputURL, to: tempSQLPath)

        // Calculate checksum
        return try calculateChecksum(of: tempSQLPath)
    }

    // [Rest of existing implementation]
}
```

---

## Benefits

### ✅ Explicit Freeze Operation
- `freezeray freeze 1.0.0` is obvious and intentional
- Can't accidentally freeze schemas during normal development
- Clear signal: "this version is shipping to production"

### ✅ Automatic Validation
- Scaffolded tests run in normal test suite (⌘U)
- CI automatically catches schema incompatibilities
- No special workflow required for developers

### ✅ iOS-Native
- All tests run in iOS simulator (no macOS target needed)
- Validation tests load fixtures from bundle (read-only)
- Works with Xcode projects and Swift Package Manager

### ✅ Convention Over Configuration
- No `.freezeray.yml` needed if you follow conventions
- CLI auto-detects project, scheme, test target
- Discovers schemas via AST parsing
- Sensible defaults for everything

### ✅ Real Migration Testing
- `@AutoTests` exercises YOUR actual MigrationPlan code
- Tests use real frozen SQLite files
- Crashes at test-time if migration incompatible
- Add custom assertions for data integrity

### ✅ Customizable Scaffolds
- Generated tests are scaffolds, not untouchable code
- Add your own validation logic
- Tests generated once, not regenerated
- Clear TODO markers for customization

### ✅ Fail-Safe
- Won't overwrite frozen fixtures without `--force`
- Won't overwrite test scaffolds without `--force`
- Clear error messages guide developers
- Immutability enforced by tooling

### ✅ Git-Friendly
- Fixtures and tests checked in under `FreezeRay/`
- Easy to review changes in PRs
- History shows when schemas were frozen

### ✅ Great Developer Experience
- Simple CLI: `freezeray freeze 1.0.0` does everything
- Readable scaffolded tests
- Clear error messages
- Works with existing tooling (Xcode, CI)

---

## Migration Guide

### For Existing FreezeRay Users

**Before (macro-only approach):**
```swift
// SchemaV1.swift
@Freeze(version: "1.0.0")
enum SchemaV1: VersionedSchema { ... }

// In tests - ❌ DOESN'T WORK IN iOS SIMULATOR
@Test func freezeSchemas() throws {
    try SchemaV1.__freezeray_freeze_1_0_0()  // Tries to write to source tree
}
```

**After (CLI approach):**
```swift
// SchemaV1.swift (unchanged)
@Freeze(version: "1.0.0")
enum SchemaV1: VersionedSchema { ... }

// Terminal - freeze once when shipping
$ freezeray freeze 1.0.0          # Freezes + scaffolds test

// Scaffolded test in FreezeRay/Tests/ - ✅ WORKS IN iOS SIMULATOR
@Test func loadFrozenFixture() throws {
    // Loads frozen fixture from bundle (read-only)
    let container = try ModelContainer(
        for: Schema(versionedSchema: SchemaV1.self),
        configurations: [config]
    )
    // ✅ Crashes here if schema incompatible with frozen fixture

    // TODO: Add custom validation
}
```

### For New Projects

1. Install CLI: `brew install freezeray` (or `mint install freezeray`)
2. Add macros to schemas: `@Freeze(version: "1.0.0")`, `@AutoTests`
3. Freeze before shipping: `freezeray freeze 1.0.0` (auto-scaffolds tests!)
4. Customize test: Add assertions to `FreezeRay/Tests/SchemaV1_DriftTests.swift`
5. Commit: `git add FreezeRay/`
6. Normal ⌘U validates automatically

**No `.freezeray.yml` needed - conventions just work!**

---

## Future Enhancements

### Phase 1: Core CLI (v0.4.0)
- [x] Design document
- [ ] Implement AST parser with SwiftSyntax
- [ ] Implement test generator
- [ ] Implement `freezeray freeze`
- [ ] Implement `freezeray generate tests`
- [ ] Update `FreezeRayRuntime` for iOS support
- [ ] Add simulator orchestration
- [ ] Documentation and examples

### Phase 2: Enhanced Validation (v0.5.0)
- [ ] `freezeray check` command
- [ ] `freezeray migrate` command
- [ ] `freezeray list` command
- [ ] Verbose diff output for drift detection
- [ ] Migration performance benchmarks in generated tests

### Phase 3: Advanced Features (v0.6.0)
- [ ] `freezeray init` interactive wizard
- [ ] Support for Swift Package Manager projects
- [ ] Support for custom migration tests
- [ ] Pre-commit hooks integration
- [ ] GitHub Actions workflow template

### Phase 4: Ecosystem Integration (v1.0.0)
- [ ] Homebrew formula
- [ ] Mint support
- [ ] Xcode Build Phase integration
- [ ] VS Code extension for syntax highlighting
- [ ] Documentation website

---

## Design Decisions

### 1. Fixtures committed to git
**Decision:** Yes, always commit fixtures to git.
- Provides full history and traceability
- Fixtures are small (typically < 1MB per version)
- Enables code review of schema changes
- Use Git LFS if fixtures become large (>10MB)

### 2. Scaffolded tests committed to git
**Decision:** Yes, commit scaffolded tests as source code.
- Tests are user-customizable, not regenerated
- Part of project source code (like any other test)
- Makes git diffs clear when schemas change
- Users add their own assertions over time

### 3. Convention over configuration
**Decision:** Make `.freezeray.yml` optional - auto-detect everything.
- Discover project type (Xcode, SPM)
- List schemes with `xcodebuild -list`
- Assume test target is `{ProjectName}Tests`
- Scan all Swift files for `@Freeze`/`@AutoTests`
- Use `FreezeRay/` folder by default
- Only require config for non-standard setups

### 4. Drift detection is a hint, not proof
**Decision:** SQL comparison is supplementary to crash test.
- Primary validation: Does `ModelContainer` load frozen fixture?
- Drift detection (checksum) provides human-readable hint
- Crash test is definitive proof of compatibility
- Both tests scaffolded, users can customize priority

### 5. Tests are scaffolds, not generated
**Decision:** Scaffold once, never regenerate.
- Users customize tests with their own assertions
- `freezeray freeze` creates scaffold if missing
- `freezeray scaffold --force` can regenerate
- Clear TODO markers guide customization
- Tests are part of project's test suite

### 6. @AutoTests exercises real MigrationPlan
**Decision:** Use the actual annotated migration plan in tests.
- Don't bypass user's migration code
- Tests run real migrations (lightweight or heavyweight)
- Crashes indicate actual production issues
- Users add data integrity assertions

### 7. CLI distributed separately
**Decision:** CLI is separate tool, not runtime dependency.
- Distribute via Homebrew, Mint, or download
- Library (macros + runtime) is Swift Package
- CLI only needed for `freezeray freeze` operation
- Tests use library directly (no CLI dependency)

### 8. Default simulator
**Decision:** Use "iPhone 16" with override option.
- Default to latest iPhone (most common)
- Allow override via `--simulator NAME`
- Validate simulator exists before running
- Fail with clear message if not found

---

## References

- FreezeRay Macro Implementation: `Sources/FreezeRayMacros/`
- SwiftSyntax Documentation: https://github.com/apple/swift-syntax
- Swift Testing Framework: https://github.com/apple/swift-testing
- Xcode Build System: https://developer.apple.com/documentation/xcode

---

## Feedback

Please provide feedback on this design:
- GitHub Issues: https://github.com/didgeoridoo/FreezeRay/issues
- Discussions: https://github.com/didgeoridoo/FreezeRay/discussions

---

**Next Steps:**
1. Review and approve this design
2. Create issues for Phase 1 implementation
3. Prototype AST parser with SwiftSyntax
4. Implement `freezeray freeze` command
5. Update FreezeRay documentation
