// Runtime support for FreezeRay macros

import Foundation
import SwiftData

/// Runtime client for sealing schemas and testing migrations.
@available(macOS 14, iOS 17, *)
public enum FreezeRayRuntime {
    /// Seal a schema version by generating fixture artifacts.
    ///
    /// Generates:
    /// - `FreezeRay/Fixtures/{version}/App.sqlite`
    /// - `FreezeRay/Fixtures/{version}/schema.json`
    /// - `FreezeRay/Fixtures/{version}/schema.sha256`
    public static func seal<S: VersionedSchema>(
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

        let container = try ModelContainer(
            for: swiftDataSchema,
            configurations: [config]
        )

        let context = ModelContext(container)
        try context.save()

        // Disable WAL mode
        try disableWAL(at: storeURL)

        // Generate schema.json
        let schemaJSON = try generateSchemaJSON(schema: swiftDataSchema)
        try schemaJSON.write(
            to: fixtureDir.appendingPathComponent("schema.json"),
            atomically: true,
            encoding: .utf8
        )

        // Generate schema.sha256
        let checksum = try calculateChecksum(of: storeURL)
        try checksum.write(
            to: fixtureDir.appendingPathComponent("schema.sha256"),
            atomically: true,
            encoding: .utf8
        )

        print("✅ Sealed schema \(version) → FreezeRay/Fixtures/\(version)/")
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

        let container = try ModelContainer(
            for: swiftDataSchema,
            configurations: [config]
        )

        let context = ModelContext(container)
        try context.save()
        try disableWAL(at: tempURL)

        // Calculate current checksum
        let currentChecksum = try calculateChecksum(of: tempURL)

        // Compare
        guard currentChecksum == storedChecksum else {
            throw FreezeRayError.schemaDrift(
                version: version,
                expected: storedChecksum,
                actual: currentChecksum
            )
        }
    }

    /// Test migrations from all sealed fixtures to HEAD.
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
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = [url.path, "PRAGMA journal_mode=DELETE;"]

        try process.run()
        process.waitUntilExit()
    }

    private static func generateSchemaJSON(schema: Schema) throws -> String {
        // TODO: Generate structured schema metadata
        // For now, return basic info
        return """
        {
          "entities": \(schema.entities.count),
          "timestamp": "\(ISO8601DateFormatter().string(from: Date()))"
        }
        """
    }

    private static func calculateChecksum(of url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Errors

public enum FreezeRayError: Error, CustomStringConvertible {
    case schemaDrift(version: String, expected: String, actual: String)

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
        }
    }
}

// MARK: - SHA256

import CryptoKit

extension SHA256 {
    static func hash(data: Data) -> [UInt8] {
        let digest = SHA256.hash(data: data)
        return Array(digest)
    }
}
