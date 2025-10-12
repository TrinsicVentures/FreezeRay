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
        // CRITICAL: Write a marker file IMMEDIATELY to prove this function was called
        if let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let markerFile = docsDir.appendingPathComponent("FREEZERAY_WAS_CALLED.txt")
            try? "Function was called!".write(to: markerFile, atomically: true, encoding: .utf8)
        }

        // Write debug log to a file we can read later
        let debugLog = { (message: String) in
            if let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let logFile = docsDir.appendingPathComponent("freezeray_debug.log")
                let timestamp = Date().description
                let logMessage = "[\(timestamp)] \(message)\n"
                if let data = logMessage.data(using: .utf8) {
                    if FileManager.default.fileExists(atPath: logFile.path) {
                        if let handle = try? FileHandle(forWritingTo: logFile) {
                            handle.seekToEndOfFile()
                            handle.write(data)
                            try? handle.close()
                        }
                    } else {
                        try? data.write(to: logFile)
                    }
                }
            }
            print(message)  // Also print to console
        }

        debugLog("🔍 FreezeRayRuntime.freeze() called")
        debugLog("   Schema: \(S.self)")
        debugLog("   Version: \(version)")
        debugLog("   Custom output: \(outputDirectory?.path ?? "nil")")

        // Determine output directory
        let fixtureDir: URL
        if let customDir = outputDirectory {
            debugLog("   ℹ️  Using custom output directory")
            fixtureDir = customDir
        } else {
            #if targetEnvironment(simulator) && os(iOS)
            // iOS Simulator: Write to Documents directory (accessible by CLI)
            debugLog("   ℹ️  Detected iOS Simulator environment")
            guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                debugLog("   ❌ Failed to get Documents directory!")
                throw FreezeRayError.sqliteCommandFailed(output: "Could not locate Documents directory")
            }
            debugLog("   📁 Documents dir: \(documentsDir.path)")
            fixtureDir = documentsDir
                .appendingPathComponent("FreezeRay")
                .appendingPathComponent("Fixtures")
                .appendingPathComponent(version)
            #else
            // macOS or other: Write to relative path in source tree
            debugLog("   ℹ️  Using macOS/default environment")
            fixtureDir = URL(fileURLWithPath: "FreezeRay/Fixtures/\(version)")
            #endif
        }

        debugLog("   🎯 Target directory: \(fixtureDir.path)")

        // Create fixture directory
        debugLog("   📂 Creating fixture directory...")
        try FileManager.default.createDirectory(
            at: fixtureDir,
            withIntermediateDirectories: true
        )
        debugLog("   ✅ Directory created successfully")

        // Create schema with WAL disabled
        // Use versioned filenames to avoid conflicts in Xcode (e.g., App-1_0_0.sqlite)
        let versionSafe = version.replacingOccurrences(of: ".", with: "_")
        let swiftDataSchema = Schema(versionedSchema: schema)
        let storeURL = fixtureDir.appendingPathComponent("App-\(versionSafe).sqlite")

        print("   💾 Creating SQLite database: \(storeURL.lastPathComponent)")

        // Remove existing if present
        if FileManager.default.fileExists(atPath: storeURL.path) {
            print("   🗑️  Removing existing database")
            try? FileManager.default.removeItem(at: storeURL)
        }

        let config = ModelConfiguration(
            schema: swiftDataSchema,
            url: storeURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )

        print("   🏗️  Creating ModelContainer...")
        do {
            let container = try ModelContainer(
                for: swiftDataSchema,
                configurations: [config]
            )

            let context = ModelContext(container)
            try context.save()
            print("   ✅ ModelContainer created and saved")
        } catch {
            print("   ❌ Failed to create ModelContainer: \(error)")
            throw error
        }

        // Let container/context deallocate before modifying WAL
        // Sleep briefly to ensure file handles are closed
        print("   ⏳ Waiting for file handles to close...")
        Thread.sleep(forTimeInterval: 0.1)

        // Verify SQLite file was created
        if FileManager.default.fileExists(atPath: storeURL.path) {
            let attrs = try? FileManager.default.attributesOfItem(atPath: storeURL.path)
            let size = (attrs?[.size] as? Int) ?? 0
            print("   ✅ SQLite file created: \(size) bytes")
        } else {
            print("   ❌ SQLite file not found at: \(storeURL.path)")
            throw FreezeRayError.sqliteCommandFailed(output: "SQLite file was not created")
        }

        // Disable WAL mode
        print("   🔧 Disabling WAL mode...")
        try disableWAL(at: storeURL)
        print("   ✅ WAL disabled")

        // Generate schema.json with versioned filename
        print("   📄 Generating schema.json...")
        let schemaJSON = try generateSchemaJSON(schema: swiftDataSchema)
        let jsonPath = fixtureDir.appendingPathComponent("schema-\(versionSafe).json")
        try schemaJSON.write(
            to: jsonPath,
            atomically: true,
            encoding: .utf8
        )
        print("   ✅ schema.json written: \(jsonPath.lastPathComponent)")

        // Generate schema SQL for checksum with versioned filename
        print("   📝 Exporting schema SQL...")
        let schemaSQLPath = fixtureDir.appendingPathComponent("schema-\(versionSafe).sql")
        try exportSchemaSQL(from: storeURL, to: schemaSQLPath)
        print("   ✅ schema.sql exported: \(schemaSQLPath.lastPathComponent)")

        // Generate schema.sha256 from SQL (not binary SQLite) with versioned filename
        print("   🔐 Calculating checksum...")
        let checksum = try calculateChecksum(of: schemaSQLPath)
        let checksumPath = fixtureDir.appendingPathComponent("schema-\(versionSafe).sha256")
        try checksum.write(
            to: checksumPath,
            atomically: true,
            encoding: .utf8
        )
        print("   ✅ Checksum written: \(checksum.prefix(16))...")

        // List all files created
        print("   📋 Files created:")
        let files = try FileManager.default.contentsOfDirectory(atPath: fixtureDir.path)
        for file in files.sorted() {
            let path = fixtureDir.appendingPathComponent(file)
            let attrs = try? FileManager.default.attributesOfItem(atPath: path.path)
            let size = (attrs?[.size] as? Int) ?? 0
            print("      - \(file) (\(size) bytes)")
        }

        print("✅ Frozen schema \(version) → \(fixtureDir.path)")
        print("") // Add blank line for readability

        // CRITICAL: When running in test environment, also copy fixtures to /tmp
        // so the CLI can extract them (XCTestDevices directories are ephemeral)
        #if targetEnvironment(simulator) && os(iOS)
        debugLog("   📦 Copying fixtures to /tmp for CLI extraction...")
        let tmpExportDir = URL(fileURLWithPath: "/tmp/FreezeRay/Fixtures/\(version)")
        try? FileManager.default.createDirectory(at: tmpExportDir, withIntermediateDirectories: true)

        // Copy all files from fixtureDir to tmpExportDir
        for file in files {
            let sourceURL = fixtureDir.appendingPathComponent(file)
            let destURL = tmpExportDir.appendingPathComponent(file)
            try? FileManager.default.removeItem(at: destURL) // Remove if exists
            try? FileManager.default.copyItem(at: sourceURL, to: destURL)
        }
        debugLog("   ✅ Fixtures copied to: \(tmpExportDir.path)")

        // Also write a metadata file with the original path
        let metadata = """
        Original path: \(fixtureDir.path)
        Exported at: \(Date())
        Version: \(version)
        """
        try? metadata.write(to: tmpExportDir.appendingPathComponent("export_metadata.txt"), atomically: true, encoding: .utf8)
        #endif
    }

    /// Check if sealed schema has drifted from current definition.
    public static func checkDrift<S: VersionedSchema>(
        schema: S.Type,
        version: String
    ) throws {
        let versionSafe = version.replacingOccurrences(of: ".", with: "_")
        let fixtureDir = URL(fileURLWithPath: "FreezeRay/Fixtures/\(version)")
        let checksumPath = fixtureDir.appendingPathComponent("schema-\(versionSafe).sha256")

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
            let versionSafe = version.replacingOccurrences(of: ".", with: "_")
            let fixtureURL = versionDir.appendingPathComponent("App-\(versionSafe).sqlite")

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

    /// Test migration between two specific schema versions.
    public static func testMigration<FromSchema: VersionedSchema, ToSchema: VersionedSchema, Plan: SchemaMigrationPlan>(
        from: FromSchema.Type,
        to: ToSchema.Type,
        migrationPlan: Plan.Type
    ) throws {
        // Extract version from schema type
        let fromVersion = String(describing: FromSchema.versionIdentifier)
        let fromVersionSafe = fromVersion.replacingOccurrences(of: ".", with: "_")
        let toVersion = String(describing: ToSchema.versionIdentifier)

        print("🧪 Testing migration: \(fromVersion) → \(toVersion)")

        // Find fixture for source version
        let fixturesDir = URL(fileURLWithPath: "FreezeRay/Fixtures")
        let versionDir = fixturesDir.appendingPathComponent(fromVersion)
        let fixtureURL = versionDir.appendingPathComponent("App-\(fromVersionSafe).sqlite")

        guard FileManager.default.fileExists(atPath: fixtureURL.path) else {
            print("   ⚠️  No fixture found for version \(fromVersion) - skipping")
            return
        }

        // Copy fixture to temp location
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")

        try FileManager.default.copyItem(at: fixtureURL, to: tempURL)

        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        // Attempt migration to target schema
        let targetSchema = Schema(versionedSchema: to)
        let config = ModelConfiguration(
            schema: targetSchema,
            url: tempURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )

        let container = try ModelContainer(
            for: targetSchema,
            migrationPlan: Plan.self,
            configurations: [config]
        )

        // Basic integrity check - open and fetch
        _ = ModelContext(container)

        print("   ✅ Migration succeeded")
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
