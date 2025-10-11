// FreezeRay - Freeze SwiftData schemas for safe production releases
//
// Usage:
//
//   @FreezeRay.FreezeSchema(version: "1.4.0")
//   enum AppSchemaV1: VersionedSchema { ... }
//
//   @FreezeRay.TestMigrations
//   struct AppMigrations: SchemaMigrationPlan { ... }

/// Freeze a shipped VersionedSchema by generating an immutable fixture.
///
/// Generates:
/// - `FreezeRay/Fixtures/{version}/App.sqlite` - Canonical SQLite database
/// - `FreezeRay/Fixtures/{version}/schema.json` - Structured schema metadata
/// - `FreezeRay/Fixtures/{version}/schema.sha256` - Checksum for drift detection
///
/// **The frozen schema becomes immutable.** Future changes to the schema will fail the build.
///
/// Example:
/// ```swift
/// @FreezeRay.FreezeSchema(version: "1.4.0")
/// enum AppSchemaV1: VersionedSchema {
///     static var versionIdentifier = Schema.Version(1, 4, 0)
///     static var models: [any PersistentModel.Type] { [User.self] }
/// }
/// ```
///
/// - Parameter version: Version identifier (e.g., "1.4.0")
@attached(member, names: arbitrary)
public macro FreezeSchema(version: String) = #externalMacro(
    module: "FreezeRayMacros",
    type: "FreezeMacro"
)

/// Automatically generate migration smoke tests for all frozen fixtures.
///
/// Apply this macro to your SchemaMigrationPlan to scaffold migration tests.
/// Tests are generated once and can be customized by the user.
///
/// Each migration test:
/// 1. Loads a frozen fixture from the previous version
/// 2. Runs your real MigrationPlan code
/// 3. Verifies the migration completes without crashing
/// 4. Provides TODO markers for custom data validation
///
/// Any crash or error → test fails (you catch it before customers do).
///
/// Example:
/// ```swift
/// @FreezeRay.TestMigrations
/// struct AppMigrations: SchemaMigrationPlan {
///     static var schemas: [any VersionedSchema.Type] {
///         [AppSchemaV1.self, AppSchemaV2.self]
///     }
///     static var stages: [MigrationStage] {
///         [.lightweight(from: AppSchemaV1.self, to: AppSchemaV2.self)]
///     }
/// }
/// ```
@attached(member, names: arbitrary)
public macro TestMigrations() = #externalMacro(
    module: "FreezeRayMacros",
    type: "AutoTestsMacro"
)
