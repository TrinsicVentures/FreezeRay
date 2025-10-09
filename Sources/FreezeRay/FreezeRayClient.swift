// Runtime helpers for FreezeRay macros
//
// These functions are called by the generated test methods.

import Foundation
import SwiftData

/// Runtime client for freezing schemas and testing migrations.
@available(macOS 14, iOS 17, *)
public enum FreezeRayClient {
    /// Freeze a schema version by exporting its SQL structure.
    ///
    /// Creates a temporary SwiftData container with the schema, exports the SQL
    /// schema using sqlite3, and saves it to the fixture directory.
    ///
    /// - Parameters:
    ///   - version: Schema version number
    ///   - schemaType: VersionedSchema type to freeze
    ///   - fixtureDir: Directory to save frozen schema SQL
    public static func freezeSchema<S: VersionedSchema>(
        version: Int,
        schemaType: S.Type,
        fixtureDir: String
    ) throws {
        // Create schema
        let schema = Schema(versionedSchema: schemaType)

        // Create temporary store
        let storeURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")

        defer {
            try? FileManager.default.removeItem(at: storeURL)
        }

        // Create container
        let config = ModelConfiguration(
            schema: schema,
            url: storeURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )

        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        try context.save()

        // Export SQL schema
        let outputPath = URL(fileURLWithPath: fixtureDir)
            .appendingPathComponent("v\(version)-schema.sql")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = [storeURL.path, ".schema"]

        let pipe = Pipe()
        process.standardOutput = pipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw FreezeError.sqliteExportFailed(version: version)
        }

        let sqlData = pipe.fileHandleForReading.readDataToEndOfFile()

        // Create fixture directory if needed
        let fixtureURL = URL(fileURLWithPath: fixtureDir)
        try FileManager.default.createDirectory(
            at: fixtureURL,
            withIntermediateDirectories: true,
            attributes: nil
        )

        try sqlData.write(to: outputPath)

        print("✅ Froze schema v\(version) → \(outputPath.path)")
    }

    /// Test migration path between two schema versions.
    ///
    /// Creates a container with the source schema, then migrates to the target schema
    /// using the provided migration plan. Validates that migration completes without crashing.
    ///
    /// - Parameters:
    ///   - fromSchema: Source schema version
    ///   - toSchema: Target schema version
    ///   - migrationPlan: Migration plan to use
    public static func testMigrationPath<From: VersionedSchema, To: VersionedSchema, Plan: SchemaMigrationPlan>(
        from fromSchema: From.Type,
        to toSchema: To.Type,
        migrationPlan: Plan.Type
    ) throws {
        let storeURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")

        defer {
            try? FileManager.default.removeItem(at: storeURL)
        }

        // Create source schema container
        let sourceSchema = Schema(versionedSchema: fromSchema)
        let sourceConfig = ModelConfiguration(
            schema: sourceSchema,
            url: storeURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )

        let sourceContainer = try ModelContainer(
            for: sourceSchema,
            configurations: [sourceConfig]
        )

        let sourceContext = ModelContext(sourceContainer)
        try sourceContext.save()

        // Migrate to target schema
        let targetSchema = Schema(versionedSchema: toSchema)
        let targetConfig = ModelConfiguration(
            schema: targetSchema,
            url: storeURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )

        let targetContainer = try ModelContainer(
            for: targetSchema,
            migrationPlan: migrationPlan,
            configurations: [targetConfig]
        )

        _ = ModelContext(targetContainer)

        // If we got here without crashing, migration succeeded
        print("✅ Migration succeeded: \(fromSchema) → \(toSchema)")
    }

    /// Load FreezeRay configuration from `.freezeray.yml`
    ///
    /// - Parameter projectRoot: Project root directory (defaults to current directory)
    /// - Returns: Configuration dictionary
    public static func loadConfig(projectRoot: String = FileManager.default.currentDirectoryPath) throws -> [String: String] {
        let configURL = URL(fileURLWithPath: projectRoot)
            .appendingPathComponent(".freezeray.yml")

        guard FileManager.default.fileExists(atPath: configURL.path) else {
            throw FreezeError.configNotFound(path: configURL.path)
        }

        let content = try String(contentsOf: configURL)
        return try parseYAML(content)
    }

    /// Simple YAML parser for basic key-value pairs
    private static func parseYAML(_ content: String) throws -> [String: String] {
        var result: [String: String] = [:]

        for line in content.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip comments and empty lines
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }

            // Parse "key: value" format
            let parts = trimmed.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }

            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts[1].trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))

            result[key] = value
        }

        return result
    }
}

// MARK: - Errors

public enum FreezeError: Error, CustomStringConvertible {
    case configNotFound(path: String)
    case fixtureDirectoryNotConfigured
    case sqliteExportFailed(version: Int)

    public var description: String {
        switch self {
        case .configNotFound(let path):
            return """
                ❌ .freezeray.yml not found at \(path)

                Create .freezeray.yml with:
                    fixture_dir: app/MyAppTests/Fixtures/SwiftData
                """
        case .fixtureDirectoryNotConfigured:
            return """
                ❌ fixture_dir not defined in .freezeray.yml

                Add to .freezeray.yml:
                    fixture_dir: app/MyAppTests/Fixtures/SwiftData
                """
        case .sqliteExportFailed(let version):
            return "❌ Failed to export SQL schema for v\(version)"
        }
    }
}
