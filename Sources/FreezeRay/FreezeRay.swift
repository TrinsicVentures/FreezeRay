// FreezeRay - Freeze SwiftData schemas for safe production releases
//
// Usage:
//
//   @FreezeSchema(version: 1)
//   enum SchemaV1: VersionedSchema { ... }
//
//   @GenerateMigrationTests
//   enum MigrationPlan: SchemaMigrationPlan { ... }

/// Freezes a SwiftData schema version by generating a test method that exports SQL.
///
/// Example:
/// ```swift
/// @FreezeSchema(version: 1)
/// enum SchemaV1: VersionedSchema {
///     static let versionIdentifier = Schema.Version(1, 0, 0)
///     static var models: [any PersistentModel.Type] { [User.self] }
/// }
/// ```
///
/// Generates:
/// ```swift
/// func test_freezeV1() throws {
///     try FreezeRayClient.freezeSchema(
///         version: 1,
///         schemaType: SchemaV1.self,
///         fixtureDir: "Tests/Fixtures/SwiftData"
///     )
/// }
/// ```
///
/// - Parameters:
///   - version: Schema version number
///   - fixtureDir: Directory to save frozen SQL (default: "Tests/Fixtures/SwiftData")
@attached(member, names: arbitrary)
public macro FreezeSchema(version: Int, fixtureDir: String = "Tests/Fixtures/SwiftData") = #externalMacro(
    module: "FreezeRayMacros",
    type: "FreezeSchemasMacro"
)

/// Generates migration smoke tests for all schema versions.
///
/// Scans for all `@FreezeSchema` annotations and generates tests validating
/// the migration path works without crashing.
///
/// Example:
/// ```swift
/// @GenerateMigrationTests
/// enum MigrationPlan: SchemaMigrationPlan {
///     static var schemas: [any VersionedSchema.Type] {
///         [SchemaV1.self, SchemaV2.self, SchemaV3.self]
///     }
///     static var stages: [MigrationStage] {
///         [migrateV1toV2, migrateV2toV3]
///     }
/// }
/// ```
///
/// Generates:
/// ```swift
/// func test_migrationV1toV3() throws {
///     try FreezeRayClient.testMigrationPath(
///         from: SchemaV1.self,
///         to: SchemaV3.self,
///         migrationPlan: MigrationPlan.self
///     )
/// }
/// ```
@attached(member, names: arbitrary)
public macro GenerateMigrationTests() = #externalMacro(
    module: "FreezeRayMacros",
    type: "GenerateMigrationTestsMacro"
)
