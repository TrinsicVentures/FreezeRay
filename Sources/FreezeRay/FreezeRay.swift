// FreezeRay - Freeze SwiftData schemas for safe production releases
//
// Usage:
//
//   @FreezeRay.FreezeSchema(version: "1.4.0")
//   enum AppSchemaV1: VersionedSchema { ... }

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
