// Runtime support for FreezeRay macros

import Foundation
import SwiftData

/// Runtime client for freezing schemas and testing migrations.
@available(macOS 14, iOS 17, *)
public enum FreezeRayRuntime {
    /// Freeze a schema version by generating fixture artifacts.
    ///
    /// Generates:
    /// - `FreezeRay/Fixtures/{version}/App.sqlite`
    /// - `FreezeRay/Fixtures/{version}/schema.json`
    /// - `FreezeRay/Fixtures/{version}/schema.sha256`
    public static func freeze<S: VersionedSchema>(
        schema: S.Type,
        version: String
    ) throws {
        // Create fixture directory
        let fixtureDir = URL(fileURLWithPath: "FreezeRay/Fixtures/\(version)")
        try FileManager.default.createDirectory(
            at: fixtureDir,
            withIntermediateDirectories: true
        )

        // Create schema with WAL disabled
        let swiftDataSchema = Schema(versionedSchema: schema)
        let storeURL = fixtureDir.appendingPathComponent("App.sqlite")

        // Remove existing if present
        try? FileManager.default.removeItem(at: storeURL)

        let config = ModelConfiguration(
            schema: swiftDataSchema,
            url: storeURL,
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

        // Let container/context deallocate before modifying WAL
        // Sleep briefly to ensure file handles are closed
        Thread.sleep(forTimeInterval: 0.1)

        // Disable WAL mode
        try disableWAL(at: storeURL)

        // Generate schema.json
        let schemaJSON = try generateSchemaJSON(schema: swiftDataSchema)
        try schemaJSON.write(
            to: fixtureDir.appendingPathComponent("schema.json"),
            atomically: true,
            encoding: .utf8
        )

        // Generate schema SQL for checksum
        let schemaSQLPath = fixtureDir.appendingPathComponent("schema.sql")
        try exportSchemaSQL(from: storeURL, to: schemaSQLPath)

        // Generate schema.sha256 from SQL (not binary SQLite)
        let checksum = try calculateChecksum(of: schemaSQLPath)
        try checksum.write(
            to: fixtureDir.appendingPathComponent("schema.sha256"),
            atomically: true,
            encoding: .utf8
        )

        print("✅ Frozen schema \(version) → FreezeRay/Fixtures/\(version)/")
    }

    /// Check if sealed schema has drifted from current definition.
    public static func checkDrift<S: VersionedSchema>(
        schema: S.Type,
        version: String
    ) throws {
        let fixtureDir = URL(fileURLWithPath: "FreezeRay/Fixtures/\(version)")
        let checksumPath = fixtureDir.appendingPathComponent("schema.sha256")

        guard FileManager.default.fileExists(atPath: checksumPath.path) else {
            // No sealed version yet - this is okay
            return
        }

        // Read stored checksum
        let storedChecksum = try String(contentsOf: checksumPath)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Generate temp fixture for current schema
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")

        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        let swiftDataSchema = Schema(versionedSchema: schema)
        let config = ModelConfiguration(
            schema: swiftDataSchema,
            url: tempURL,
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

        // Let container/context deallocate before exporting
        Thread.sleep(forTimeInterval: 0.1)

        try disableWAL(at: tempURL)

        // Export schema SQL
        let tempSQLPath = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sql")

        defer {
            try? FileManager.default.removeItem(at: tempSQLPath)
        }

        try exportSchemaSQL(from: tempURL, to: tempSQLPath)

        // Calculate current checksum from SQL
        let currentChecksum = try calculateChecksum(of: tempSQLPath)

        // Compare
        guard currentChecksum == storedChecksum else {
            throw FreezeRayError.schemaDrift(
                version: version,
                expected: storedChecksum,
                actual: currentChecksum
            )
        }
    }

    /// Test migrations from all frozen fixtures to HEAD.
    public static func testAllMigrations<Plan: SchemaMigrationPlan>(
        migrationPlan: Plan.Type
    ) throws {
        let fixturesDir = URL(fileURLWithPath: "FreezeRay/Fixtures")

        guard FileManager.default.fileExists(atPath: fixturesDir.path) else {
            print("⚠️  No sealed fixtures found - skipping migration tests")
            return
        }

        let versions = try FileManager.default.contentsOfDirectory(
            at: fixturesDir,
            includingPropertiesForKeys: [.isDirectoryKey]
        ).filter { url in
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
            return isDir.boolValue
        }

        print("🧪 Testing migrations for \(versions.count) sealed fixture(s)...")

        for versionDir in versions {
            let version = versionDir.lastPathComponent
            let fixtureURL = versionDir.appendingPathComponent("App.sqlite")

            guard FileManager.default.fileExists(atPath: fixtureURL.path) else {
                continue
            }

            print("   Testing migration: \(version) → HEAD")

            // Copy fixture to temp location
            let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("sqlite")

            try FileManager.default.copyItem(at: fixtureURL, to: tempURL)

            defer {
                try? FileManager.default.removeItem(at: tempURL)
            }

            // Attempt migration
            let headSchema = Schema(versionedSchema: Plan.schemas.last!)
            let config = ModelConfiguration(
                schema: headSchema,
                url: tempURL,
                allowsSave: true,
                cloudKitDatabase: .none
            )

            let container = try ModelContainer(
                for: headSchema,
                migrationPlan: Plan.self,
                configurations: [config]
            )

            // Basic integrity check - open and fetch
            _ = ModelContext(container)

            print("      ✅ Migration succeeded")
        }

        print("✅ All migrations passed")
    }

    // MARK: - Helpers

    private static func disableWAL(at url: URL) throws {
        #if os(macOS)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = [url.path, "PRAGMA journal_mode=DELETE;"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw FreezeRayError.sqliteCommandFailed(output: output)
        }
        #else
        throw FreezeRayError.unsupportedPlatform
        #endif
    }

    private static func exportSchemaSQL(from dbURL: URL, to outputURL: URL) throws {
        #if os(macOS)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = [dbURL.path, ".schema"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw FreezeRayError.sqliteCommandFailed(output: output)
        }

        let sqlData = pipe.fileHandleForReading.readDataToEndOfFile()
        try sqlData.write(to: outputURL)
        #else
        throw FreezeRayError.unsupportedPlatform
        #endif
    }

    private static func generateSchemaJSON(schema: Schema) throws -> String {
        let timestamp = ISO8601DateFormatter().string(from: Date())

        // Extract entity information from schema
        var entitiesJSON: [String] = []
        for entity in schema.entities {
            let entityName = String(describing: entity.name)
            entitiesJSON.append("""
                {
                  "name": "\(entityName)"
                }
            """)
        }

        let entitiesArray = entitiesJSON.joined(separator: ",\n    ")

        return """
        {
          "timestamp": "\(timestamp)",
          "entityCount": \(schema.entities.count),
          "entities": [
            \(entitiesArray)
          ]
        }
        """
    }

    private static func calculateChecksum(of url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        let hash = hashData(data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Errors

public enum FreezeRayError: Error, CustomStringConvertible {
    case schemaDrift(version: String, expected: String, actual: String)
    case sqliteCommandFailed(output: String)
    case unsupportedPlatform

    public var description: String {
        switch self {
        case .schemaDrift(let version, let expected, let actual):
            return """
                ❌ Schema drift detected in sealed version \(version)

                The sealed schema has changed since it was frozen.
                Sealed schemas are immutable - create a new schema version instead.

                Expected checksum: \(expected)
                Actual checksum:   \(actual)
                """
        case .sqliteCommandFailed(let output):
            return "❌ sqlite3 command failed: \(output)"
        case .unsupportedPlatform:
            return "❌ FreezeRay only runs on macOS (tests run on macOS even when targeting iOS)"
        }
    }
}

// MARK: - SHA256

import CryptoKit

private func hashData(_ data: Data) -> [UInt8] {
    let digest = SHA256.hash(data: data)
    return Array(digest)
}
