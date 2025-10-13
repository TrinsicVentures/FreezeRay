import ArgumentParser
import Foundation

struct FreezeCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "freeze",
        abstract: "Freeze a schema version by generating immutable fixture artifacts"
    )

    @Argument(help: "Schema version to freeze (e.g., \"1.0.0\")")
    var version: String

    @Option(name: .long, help: "Path to .freezeray.yml config file")
    var config: String?

    @Option(name: .long, help: "Simulator to use (default: iPhone 17)")
    var simulator: String = "iPhone 17"

    @Option(name: .long, help: "Xcode scheme to use (auto-detected if not specified)")
    var scheme: String?

    @Flag(name: .long, help: "Overwrite existing frozen fixtures (dangerous!)")
    var force: Bool = false

    @Option(name: .long, help: "Override output directory for fixtures")
    var output: String?

    func run() async throws {
        print("🔹 FreezeRay v0.4.0")
        print("🔹 Freezing schema version: \(version)")
        print("")

        // 1. Auto-detect project
        print("🔹 Auto-detecting project configuration...")
        let workingDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let projectPath = try SimulatorManager.discoverProject(in: workingDir)
        print("   Found: \(projectPath.components(separatedBy: "/").last ?? projectPath)")

        let discoveredScheme: String
        if let userScheme = scheme {
            discoveredScheme = userScheme
            print("   Scheme: \(discoveredScheme) (user-specified)")
        } else {
            discoveredScheme = try SimulatorManager.discoverScheme(projectPath: projectPath)
            print("   Scheme: \(discoveredScheme) (auto-detected)")
        }

        let testTarget = SimulatorManager.inferTestTarget(from: discoveredScheme)
        print("   Test target: \(testTarget) (inferred)")
        print("")

        // 2. Discover @Freeze(version: "X.X.X") annotations
        print("🔹 Parsing source files for @Freeze(version: \"\(version)\")...")
        let sourcePaths = [workingDir.path]  // TODO: Support custom source paths from config
        let discovery = try discoverMacros(in: sourcePaths)

        guard let freezeAnnotation = discovery.freezeAnnotations.first(where: { $0.version == version }) else {
            throw FreezeRayError.schemaNotFound(version: version)
        }

        print("   Found: \(freezeAnnotation.typeName) in \(freezeAnnotation.filePath)")
        print("")

        // 3. Check if fixtures already exist
        let fixturesDir = output.map { URL(fileURLWithPath: $0) } ??
            workingDir.appendingPathComponent("FreezeRay/Fixtures/\(version)")

        if FileManager.default.fileExists(atPath: fixturesDir.path) && !force {
            throw FreezeRayError.fixturesAlreadyExist(path: fixturesDir.path, version: version)
        }

        if force {
            print("⚠️  WARNING: Overwriting existing fixtures for v\(version)")
            print("⚠️  Frozen schemas should be immutable once shipped to production!")
            print("")
            try? FileManager.default.removeItem(at: fixturesDir)
        }

        // 4. Generate temporary freeze test
        print("🔹 Generating freeze test...")
        // Convention: app target is test target without "Tests" suffix
        let appTarget = testTarget.replacingOccurrences(of: "Tests", with: "")
        let testFilePath = try generateFreezeTest(
            workingDir: workingDir,
            testTarget: testTarget,
            appTarget: appTarget,
            schemaType: freezeAnnotation.typeName,
            version: version
        )
        defer {
            // Clean up temporary test file
            try? FileManager.default.removeItem(at: testFilePath)
        }

        // 5. Run freeze operation in simulator
        let manager = SimulatorManager()
        let simulatorFixturesURL = try manager.runFreezeInSimulator(
            projectPath: projectPath,
            scheme: discoveredScheme,
            testTarget: testTarget,
            schemaType: freezeAnnotation.typeName,
            version: version,
            simulator: simulator
        )

        // 6. Copy fixtures from simulator to project
        print("🔹 Extracting fixtures from simulator...")
        try FileManager.default.createDirectory(
            at: fixturesDir.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        try FileManager.default.copyItem(at: simulatorFixturesURL, to: fixturesDir)

        let files = try FileManager.default.contentsOfDirectory(atPath: fixturesDir.path)
        for file in files {
            print("   Copied: \(file) → \(fixturesDir.path)/")
        }
        print("")

        // 7. Scaffold drift test
        print("🔹 Scaffolding drift test...")
        let testsDir = workingDir.appendingPathComponent("FreezeRay/Tests")
        try? FileManager.default.createDirectory(at: testsDir, withIntermediateDirectories: true)

        let scaffoldResult = try scaffoldDriftTest(
            testsDir: testsDir,
            schemaType: freezeAnnotation.typeName,
            appTarget: appTarget,
            version: version
        )

        if scaffoldResult.created {
            print("   Created: \(scaffoldResult.fileName)")
        } else {
            print("   Skipped: \(scaffoldResult.fileName) (already exists)")
        }

        // 8. Scaffold migration test (if previous version exists)
        let fixturesRootDir = workingDir.appendingPathComponent("FreezeRay/Fixtures")
        if let previousVersion = findPreviousVersion(current: version, fixturesDir: fixturesRootDir) {
            print("🔹 Scaffolding migration test...")
            // Check if we found a migration plan with @TestMigrations annotation
            if let migrationPlan = discovery.testMigrationsAnnotations.first {
                let migrationResult = try scaffoldMigrationTest(
                    testsDir: testsDir,
                    migrationPlan: migrationPlan.typeName,
                    fromVersion: previousVersion,
                    toVersion: version,
                    appTarget: appTarget
                )

                if migrationResult.created {
                    print("   Created: \(migrationResult.fileName)")
                } else {
                    print("   Skipped: \(migrationResult.fileName) (already exists)")
                }
            } else {
                print("   Skipped: No @TestMigrations annotation found")
            }
        }
        print("")

        print("✅ Schema v\(version) frozen successfully!")
        print("")
        print("📝 Next steps:")
        print("   1. Review fixtures: \(fixturesDir.path)")
        if scaffoldResult.created {
            print("   2. Customize drift test: FreezeRay/Tests/\(scaffoldResult.fileName)")
            print("   3. Add FreezeRay/ folder to Xcode project if needed")
        } else {
            print("   2. Add FreezeRay/ folder to Xcode project if needed")
        }
        print("   4. Run tests: xcodebuild test -scheme \(discoveredScheme)")
        print("   5. Commit to git: git add FreezeRay/")
    }
}

enum FreezeRayError: Error, CustomStringConvertible {
    case custom(String)
    case schemaNotFound(version: String)
    case fixturesAlreadyExist(path: String, version: String)

    var description: String {
        switch self {
        case .custom(let message):
            return "❌ \(message)"
        case .schemaNotFound(let version):
            return """
            ❌ No @Freeze(version: "\(version)") annotation found in source files

            Please add @Freeze(version: "\(version)") to your schema:

            @Freeze(version: "\(version)")
            enum SchemaV\(version.replacingOccurrences(of: ".", with: "_")): VersionedSchema {
                // ...
            }
            """
        case .fixturesAlreadyExist(let path, let version):
            return """
            ❌ Fixtures for v\(version) already exist at \(path)

            Frozen schemas are immutable. If you need to update the schema:
              1. Create a new schema version (e.g., v\(nextVersion(version)))
              2. Add a migration from v\(version) → v\(nextVersion(version))
              3. Freeze the new version: freezeray freeze \(nextVersion(version))

            To overwrite existing fixtures (⚠️  DANGEROUS):
              freezeray freeze \(version) --force
            """
        }
    }

    private func nextVersion(_ version: String) -> String {
        let components = version.split(separator: ".").compactMap { Int($0) }
        guard components.count == 3 else { return version }
        return "\(components[0]).\(components[1]).\(components[2] + 1)"
    }
}

// MARK: - Freeze Test Generation

extension FreezeCommand {

    /// Generates a temporary test file that calls the macro-generated freeze function
    /// Returns the path to the generated test file
    func generateFreezeTest(
        workingDir: URL,
        testTarget: String,
        appTarget: String,
        schemaType: String,
        version: String
    ) throws -> URL {
        let versionSafe = version.replacingOccurrences(of: ".", with: "_")
        let functionName = "__freezeray_freeze_\(versionSafe)"

        let testContent = """
        // AUTO-GENERATED by FreezeRay CLI - DO NOT EDIT
        // This file is temporary and will be deleted after the freeze operation

        import XCTest
        import FreezeRay
        @testable import \(appTarget)

        /// Temporary freeze test for schema version \(version)
        /// Invoked by: freezeray freeze \(version)
        final class FreezeSchemaV\(versionSafe)_Test: XCTestCase {

            func testFreezeSchemaV\(versionSafe)() throws {
                try \(schemaType).\(functionName)()
            }
        }

        """

        // Write to test target directory
        let testTargetDir = workingDir.appendingPathComponent(testTarget)
        let testFilePath = testTargetDir.appendingPathComponent("FreezeSchemaV\(versionSafe)_Test.swift")

        try testContent.write(to: testFilePath, atomically: true, encoding: .utf8)
        print("   Generated: \(testFilePath.lastPathComponent)")

        return testFilePath
    }

    /// Result of scaffolding operation
    struct ScaffoldResult {
        let fileName: String
        let created: Bool  // true if created, false if already existed
    }

    /// Scaffolds a drift test file for a schema version
    /// Only creates the file if it doesn't already exist (user-owned)
    func scaffoldDriftTest(
        testsDir: URL,
        schemaType: String,
        appTarget: String,
        version: String
    ) throws -> ScaffoldResult {
        let versionSafe = version.replacingOccurrences(of: ".", with: "_")
        let fileName = "\(schemaType)_DriftTests.swift"
        let filePath = testsDir.appendingPathComponent(fileName)

        // Skip if file already exists (user-owned, never overwrite)
        if FileManager.default.fileExists(atPath: filePath.path) {
            return ScaffoldResult(fileName: fileName, created: false)
        }

        let testContent = """
        // AUTO-GENERATED by FreezeRay CLI
        // This file is scaffolded once and owned by you. Customize as needed.
        //
        // Purpose: Verify that the frozen schema v\(version) hasn't drifted
        // Generated by: freezeray freeze \(version)

        import Testing
        import FreezeRay
        @testable import \(appTarget)

        /// Drift test for \(schemaType) v\(version)
        ///
        /// This test verifies that the current schema definition matches the frozen fixture.
        /// If this test fails, it means the schema has been modified since it was frozen.
        @Test("\(schemaType) v\(version) has not drifted")
        func test\(schemaType)_\(versionSafe)_Drift() throws {
            // Call the macro-generated check function
            try \(schemaType).__freezeray_check_\(versionSafe)()

            // TODO: Add custom data validation here
            // Example:
            // - Verify specific model properties exist
            // - Check relationship configurations
            // - Validate index definitions
        }

        """

        try testContent.write(to: filePath, atomically: true, encoding: .utf8)

        return ScaffoldResult(fileName: fileName, created: true)
    }

    /// Scaffolds a migration test file for upgrading from one version to another
    /// Only creates the file if it doesn't already exist (user-owned)
    func scaffoldMigrationTest(
        testsDir: URL,
        migrationPlan: String,
        fromVersion: String,
        toVersion: String,
        appTarget: String
    ) throws -> ScaffoldResult {
        let fromSafe = fromVersion.replacingOccurrences(of: ".", with: "_")
        let toSafe = toVersion.replacingOccurrences(of: ".", with: "_")
        let fileName = "MigrateV\(fromSafe)toV\(toSafe)_Tests.swift"
        let filePath = testsDir.appendingPathComponent(fileName)

        // Skip if file already exists (user-owned, never overwrite)
        if FileManager.default.fileExists(atPath: filePath.path) {
            return ScaffoldResult(fileName: fileName, created: false)
        }

        let testContent = """
        // AUTO-GENERATED by FreezeRay CLI
        // This file is scaffolded once and owned by you. Customize as needed.
        //
        // Purpose: Test migration from v\(fromVersion) → v\(toVersion)
        // Generated by: freezeray freeze \(toVersion)

        import Testing
        import FreezeRay
        @testable import \(appTarget)

        /// Migration test from v\(fromVersion) → v\(toVersion)
        ///
        /// This test verifies that the migration path between these versions works correctly.
        @Test("Migrate v\(fromVersion) → v\(toVersion)")
        func testMigrateV\(fromSafe)toV\(toSafe)() throws {
            // Call the macro-generated per-version migration function
            try \(migrationPlan).__freezeray_test_migrate_\(fromSafe)_to_\(toSafe)()

            // TODO: Add data integrity checks here
            // Example:
            // - Verify data is preserved during migration
            // - Check that new fields have default values
            // - Validate relationship updates
            // - Ensure no data loss for critical fields
        }

        """

        try testContent.write(to: filePath, atomically: true, encoding: .utf8)

        return ScaffoldResult(fileName: fileName, created: true)
    }

    /// Finds the previous version by scanning the Fixtures directory
    /// Returns nil if no previous version exists (this is the first schema)
    func findPreviousVersion(current: String, fixturesDir: URL) -> String? {
        guard FileManager.default.fileExists(atPath: fixturesDir.path) else {
            return nil
        }

        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: fixturesDir.path) else {
            return nil
        }

        // Filter out non-version directories and the current version
        let versions = contents.filter { dir in
            dir != current && dir.range(of: #"^\d+\.\d+\.\d+$"#, options: .regularExpression) != nil
        }

        guard !versions.isEmpty else {
            return nil
        }

        // Sort semantically (semantic versioning)
        let sorted = versions.sorted { v1, v2 in
            let c1 = v1.split(separator: ".").compactMap { Int($0) }
            let c2 = v2.split(separator: ".").compactMap { Int($0) }

            for i in 0..<min(c1.count, c2.count) {
                if c1[i] != c2[i] {
                    return c1[i] < c2[i]
                }
            }
            return c1.count < c2.count
        }

        // Return the highest version that's less than current
        let currentComponents = current.split(separator: ".").compactMap { Int($0) }
        for version in sorted.reversed() {
            let versionComponents = version.split(separator: ".").compactMap { Int($0) }

            var isLess = false
            for i in 0..<min(currentComponents.count, versionComponents.count) {
                if versionComponents[i] < currentComponents[i] {
                    isLess = true
                    break
                } else if versionComponents[i] > currentComponents[i] {
                    break
                }
            }

            if isLess {
                return version
            }
        }

        return nil
    }
}
