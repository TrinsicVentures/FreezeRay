import ArgumentParser
import Foundation

struct FreezeCommand: ParsableCommand {
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

    func run() throws {
        print("🔹 FreezeRay v0.4.2")
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

        let scaffolding = TestScaffolding()
        let scaffoldResult = try scaffolding.scaffoldDriftTest(
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
        if let previousVersion = scaffolding.findPreviousVersion(current: version, fixturesDir: fixturesRootDir) {
            print("🔹 Scaffolding migration test...")

            // Find schema type for previous version
            guard let previousSchema = discovery.freezeAnnotations.first(where: { $0.version == previousVersion }) else {
                print("   Skipped: Could not find schema type for v\(previousVersion)")
                return
            }

            // Get discovered migration plan (or skip if none found)
            if let migrationPlan = discovery.migrationPlans.first {
                if discovery.migrationPlans.count > 1 {
                    print("   ⚠️  Multiple migration plans found:")
                    for plan in discovery.migrationPlans {
                        print("      - \(plan.typeName)")
                    }
                    print("   Using: \(migrationPlan.typeName)")
                }

                let migrationResult = try scaffolding.scaffoldMigrationTest(
                    testsDir: testsDir,
                    migrationPlan: migrationPlan.typeName,
                    fromVersion: previousVersion,
                    fromSchemaType: previousSchema.typeName,
                    toVersion: version,
                    toSchemaType: freezeAnnotation.typeName,
                    appTarget: appTarget
                )

                if migrationResult.created {
                    print("   Created: \(migrationResult.fileName)")
                } else {
                    print("   Skipped: \(migrationResult.fileName) (already exists)")
                }
            } else {
                print("   Skipped: No SchemaMigrationPlan found")
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

}
