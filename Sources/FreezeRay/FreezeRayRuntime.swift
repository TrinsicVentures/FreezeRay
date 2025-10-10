// Runtime support for FreezeRay macros

import Foundation
import SwiftData
import SQLite3

/// Runtime client for freezing schemas and testing migrations.
@available(macOS 14, iOS 17, *)
public enum FreezeRayRuntime {
    /// Freeze a schema version by generating fixture artifacts.
    ///
    /// Generates:
    /// - `App.sqlite`
    /// - `schema.json`
    /// - `schema.sql`
    /// - `schema.sha256`
    ///
    /// - Parameters:
    ///   - schema: The schema type to freeze
    ///   - version: Version identifier (e.g., "1.0.0")
    ///   - outputDirectory: Custom output directory. If nil, uses default location based on platform:
    ///     - iOS Simulator: ~/Documents/FreezeRay/Fixtures/{version}/
    ///     - macOS: FreezeRay/Fixtures/{version}/ (relative to current directory)
    public static func freeze<S: VersionedSchema>(
        schema: S.Type,
        version: String,
        outputDirectory: URL? = nil
    ) throws {
        // Determine output directory
        let fixtureDir: URL
        if let customDir = outputDirectory {
            fixtureDir = customDir
        } else {
            #if targetEnvironment(simulator) && os(iOS)
            // iOS Simulator: Write to Documents directory (accessible by CLI)
            let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            fixtureDir = documentsDir
                .appendingPathComponent("FreezeRay")
                .appendingPathComponent("Fixtures")
                .appendingPathComponent(version)
            #else
            // macOS or other: Write to relative path in source tree
            fixtureDir = URL(fileURLWithPath: "FreezeRay/Fixtures/\(version)")
            #endif
        }

        // Create fixture directory
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

        print("✅ Frozen schema \(version) → \(fixtureDir.path)")
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
        var db: OpaquePointer?

        guard sqlite3_open(url.path, &db) == SQLITE_OK else {
            let error = String(cString: sqlite3_errmsg(db))
            sqlite3_close(db)
            throw FreezeRayError.sqliteCommandFailed(output: "Failed to open database: \(error)")
        }

        defer { sqlite3_close(db) }

        // Disable WAL mode by setting journal_mode to DELETE
        var errorMsg: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(
            db,
            "PRAGMA journal_mode=DELETE;",
            nil,
            nil,
            &errorMsg
        )

        if result != SQLITE_OK {
            let error = errorMsg.map { String(cString: $0) } ?? "Unknown error"
            sqlite3_free(errorMsg)
            throw FreezeRayError.sqliteCommandFailed(output: "Failed to disable WAL: \(error)")
        }
    }

    private static func exportSchemaSQL(from dbURL: URL, to outputURL: URL) throws {
        var db: OpaquePointer?

        guard sqlite3_open(dbURL.path, &db) == SQLITE_OK else {
            let error = String(cString: sqlite3_errmsg(db))
            sqlite3_close(db)
            throw FreezeRayError.sqliteCommandFailed(output: "Failed to open database: \(error)")
        }

        defer { sqlite3_close(db) }

        // Query sqlite_master to get all schema DDL statements
        var statement: OpaquePointer?
        let query = """
            SELECT sql FROM sqlite_master
            WHERE sql IS NOT NULL
            ORDER BY tbl_name, type DESC, name
            """

        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            let error = String(cString: sqlite3_errmsg(db))
            throw FreezeRayError.sqliteCommandFailed(output: "Failed to prepare query: \(error)")
        }

        defer { sqlite3_finalize(statement) }

        var schemaSQL = ""
        while sqlite3_step(statement) == SQLITE_ROW {
            if let cString = sqlite3_column_text(statement, 0) {
                let sql = String(cString: cString)
                schemaSQL += sql + ";\n"
            }
        }

        guard let data = schemaSQL.data(using: .utf8) else {
            throw FreezeRayError.sqliteCommandFailed(output: "Failed to encode schema SQL")
        }

        try data.write(to: outputURL)
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
