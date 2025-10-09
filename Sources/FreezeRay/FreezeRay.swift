// FreezeRay - Seal SwiftData schemas for safe production releases
//
// Usage:
//
//   @FreezeRay.Seal(version: "1.4.0")
//   enum AppSchemaV1: VersionedSchema { ... }
//
//   @FreezeRay.AutoTests
//   struct AppMigrations: SchemaMigrationPlan { ... }

/// Seal a shipped schema version by generating an immutable fixture.
///
/// Generates:
/// - `FreezeRay/Fixtures/{version}/App.sqlite` - Canonical SQLite database
/// - `FreezeRay/Fixtures/{version}/schema.json` - Structured schema metadata
/// - `FreezeRay/Fixtures/{version}/schema.sha256` - Checksum for drift detection
///
/// **The sealed schema becomes immutable.** Future changes to the schema will fail the build.
///
/// Example:
/// ```swift
/// @FreezeRay.Seal(version: "1.4.0")
/// enum AppSchemaV1: VersionedSchema {
///     static var versionIdentifier = Schema.Version(1, 4, 0)
///     static var models: [any PersistentModel.Type] { [User.self] }
/// }
/// ```
///
/// - Parameter version: Version identifier (e.g., "1.4.0")
@attached(peer, names: arbitrary)
public macro Seal(version: String) = #externalMacro(
    module: "FreezeRayMacros",
    type: "SealMacro"
)

/// Automatically generate migration smoke tests for all sealed fixtures.
///
/// Generates test methods that:
/// 1. Copy each sealed fixture to a temp directory
/// 2. Boot current code (with latest schema)
/// 3. Run SwiftData migration using the SchemaMigrationPlan
/// 4. Perform integrity checks (open, fetch, basic queries)
///
/// Any crash or error → test fails (you catch it before customers do).
///
/// Example:
/// ```swift
/// @FreezeRay.AutoTests
/// struct AppMigrations: SchemaMigrationPlan {
///     static var schemas: [any VersionedSchema.Type] {
///         [AppSchemaV1.self, AppSchemaV2.self]
///     }
///     static var stages: [MigrationStage] {
///         [.lightweight(from: AppSchemaV1.self, to: AppSchemaV2.self)]
///     }
/// }
/// ```
@attached(peer, names: arbitrary)
public macro AutoTests() = #externalMacro(
    module: "FreezeRayMacros",
    type: "AutoTestsMacro"
)
