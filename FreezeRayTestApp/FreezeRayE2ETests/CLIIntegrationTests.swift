import XCTest
import Foundation

/// E2E integration tests for the FreezeRay CLI
/// Tests the complete workflow: freeze → fixtures → scaffolding → tests
final class CLIIntegrationTests: XCTestCase {

    let projectRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // FreezeRayTestAppTests/
        .deletingLastPathComponent()  // FreezeRayTestApp/

    let cliPath = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // FreezeRayTestAppTests/
        .deletingLastPathComponent()  // FreezeRayTestApp/
        .deletingLastPathComponent()  // FreezeRay/
        .appendingPathComponent(".build/debug/freezeray")

    override func setUp() async throws {
        // Build the CLI before running tests
        print("📦 Building CLI...")
        let buildResult = try await runCommand(
            executable: "/usr/bin/swift",
            arguments: ["build"],
            workingDirectory: projectRoot.deletingLastPathComponent()
        )
        XCTAssertTrue(buildResult.success, "Failed to build CLI:\n\(buildResult.output)")
    }

    override func tearDown() async throws {
        // Clean up /tmp fixtures
        try? FileManager.default.removeItem(atPath: "/tmp/FreezeRay")
    }

    // MARK: - Test: Fixture Extraction from /tmp

    func testFixtureExtractionFromTmp() async throws {
        // Given: Clean /tmp directory
        try? FileManager.default.removeItem(atPath: "/tmp/FreezeRay")

        // When: Run the manual freeze test (this should export to /tmp)
        let testResult = try await runCommand(
            executable: "/usr/bin/xcodebuild",
            arguments: [
                "test",
                "-project", "FreezeRayTestApp.xcodeproj",
                "-scheme", "FreezeRayTestApp",
                "-destination", "platform=iOS Simulator,name=iPhone 17",
                "-only-testing:FreezeRayTestAppTests/ManualFreezeTest/testMacroGeneratedFunctionExists"
            ],
            workingDirectory: projectRoot
        )

        // Then: Test should pass
        XCTAssertTrue(testResult.success, "Manual freeze test failed:\n\(testResult.output)")

        // And: Fixtures should be in /tmp
        let tmpFixturesDir = URL(fileURLWithPath: "/tmp/FreezeRay/Fixtures/3.0.0")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: tmpFixturesDir.path),
            "Fixtures not found in /tmp at: \(tmpFixturesDir.path)"
        )

        // And: All required files should exist
        let requiredFiles = [
            "App-3_0_0.sqlite",
            "schema-3_0_0.json",
            "schema-3_0_0.sql",
            "schema-3_0_0.sha256",
            "export_metadata.txt"
        ]

        for file in requiredFiles {
            let filePath = tmpFixturesDir.appendingPathComponent(file)
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: filePath.path),
                "Required file missing: \(file)"
            )
        }

        print("✅ Fixture extraction from /tmp verified")
    }

    // MARK: - Test: Full CLI Freeze Workflow (v1.0.0)

    func testFreezeVersion1_0_0() async throws {
        // Given: Clean state
        let fixturesDir = projectRoot.appendingPathComponent("FreezeRay/Fixtures/1.0.0")
        let testsDir = projectRoot.appendingPathComponent("FreezeRay/Tests")
        try? FileManager.default.removeItem(at: fixturesDir)
        try? FileManager.default.removeItem(at: testsDir)

        // When: Run freezeray freeze 1.0.0
        let freezeResult = try await runCommand(
            executable: cliPath.path,
            arguments: ["freeze", "1.0.0"],
            workingDirectory: projectRoot
        )

        // Then: Command should succeed
        XCTAssertTrue(
            freezeResult.success,
            "freezeray freeze 1.0.0 failed:\n\(freezeResult.output)"
        )

        // And: Fixtures should be created
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: fixturesDir.path),
            "Fixtures directory not created"
        )

        let expectedFiles = [
            "App-1_0_0.sqlite",
            "schema-1_0_0.json",
            "schema-1_0_0.sql",
            "schema-1_0_0.sha256"
        ]

        for file in expectedFiles {
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: fixturesDir.appendingPathComponent(file).path),
                "Expected fixture file missing: \(file)"
            )
        }

        // And: Drift test should be scaffolded
        let driftTestPath = testsDir.appendingPathComponent("AppSchemaV1_DriftTests.swift")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: driftTestPath.path),
            "Drift test not scaffolded"
        )

        // And: Drift test should contain TODO marker
        let driftTestContent = try String(contentsOf: driftTestPath)
        XCTAssertTrue(
            driftTestContent.contains("// TODO:"),
            "Drift test missing TODO marker"
        )

        // And: No migration test (this is the first version)
        let migrationFiles = try FileManager.default.contentsOfDirectory(atPath: testsDir.path)
            .filter { $0.hasPrefix("MigrateV") }
        XCTAssertEqual(migrationFiles.count, 0, "Should not create migration test for first version")

        print("✅ Version 1.0.0 frozen successfully")
    }

    // MARK: - Test: Full CLI Freeze Workflow (v2.0.0 with migration)

    func testFreezeVersion2_0_0_WithMigration() async throws {
        // Given: Version 1.0.0 already frozen
        try await testFreezeVersion1_0_0()

        // When: Run freezeray freeze 2.0.0
        let freezeResult = try await runCommand(
            executable: cliPath.path,
            arguments: ["freeze", "2.0.0"],
            workingDirectory: projectRoot
        )

        // Then: Command should succeed
        XCTAssertTrue(
            freezeResult.success,
            "freezeray freeze 2.0.0 failed:\n\(freezeResult.output)"
        )

        // And: Fixtures should be created
        let fixturesDir = projectRoot.appendingPathComponent("FreezeRay/Fixtures/2.0.0")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: fixturesDir.path),
            "Fixtures directory not created for 2.0.0"
        )

        // And: Drift test should be scaffolded
        let testsDir = projectRoot.appendingPathComponent("FreezeRay/Tests")
        let driftTestPath = testsDir.appendingPathComponent("AppSchemaV2_DriftTests.swift")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: driftTestPath.path),
            "Drift test not scaffolded for 2.0.0"
        )

        // And: Migration test should be scaffolded (1.0.0 → 2.0.0)
        let migrationTestPath = testsDir.appendingPathComponent("MigrateV1_0_0toV2_0_0_Tests.swift")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: migrationTestPath.path),
            "Migration test not scaffolded"
        )

        // And: Migration test should call the correct function
        let migrationTestContent = try String(contentsOf: migrationTestPath)
        XCTAssertTrue(
            migrationTestContent.contains("__freezeray_test_migrate_1_0_0_to_2_0_0"),
            "Migration test should call macro-generated migration function"
        )

        print("✅ Version 2.0.0 frozen successfully with migration test")
    }

    // MARK: - Test: Scaffolded Tests Compile

    func testScaffoldedTestsCompile() async throws {
        // Given: Frozen versions with scaffolded tests
        try await testFreezeVersion2_0_0_WithMigration()

        // When: Build the test target
        let buildResult = try await runCommand(
            executable: "/usr/bin/xcodebuild",
            arguments: [
                "build-for-testing",
                "-project", "FreezeRayTestApp.xcodeproj",
                "-scheme", "FreezeRayTestApp",
                "-destination", "platform=iOS Simulator,name=iPhone 17"
            ],
            workingDirectory: projectRoot
        )

        // Then: Build should succeed
        XCTAssertTrue(
            buildResult.success,
            "Scaffolded tests failed to compile:\n\(buildResult.output)"
        )

        print("✅ Scaffolded tests compile successfully")
    }

    // MARK: - Test: Force Flag Overwrites Existing Fixtures

    func testForceFlag() async throws {
        // Given: Version 1.0.0 already frozen
        try await testFreezeVersion1_0_0()

        let fixturesDir = projectRoot.appendingPathComponent("FreezeRay/Fixtures/1.0.0")
        let originalModificationDate = try FileManager.default
            .attributesOfItem(atPath: fixturesDir.path)[.modificationDate] as? Date

        // Wait a bit to ensure modification date would change
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

        // When: Run freezeray freeze 1.0.0 --force
        let freezeResult = try await runCommand(
            executable: cliPath.path,
            arguments: ["freeze", "1.0.0", "--force"],
            workingDirectory: projectRoot
        )

        // Then: Command should succeed
        XCTAssertTrue(
            freezeResult.success,
            "freezeray freeze 1.0.0 --force failed:\n\(freezeResult.output)"
        )

        // And: Fixtures should be overwritten (modification date changed)
        let newModificationDate = try FileManager.default
            .attributesOfItem(atPath: fixturesDir.path)[.modificationDate] as? Date

        XCTAssertNotEqual(
            originalModificationDate,
            newModificationDate,
            "Fixtures were not overwritten"
        )

        print("✅ Force flag overwrites existing fixtures")
    }

    // MARK: - Test: Error Handling - Already Frozen

    func testErrorWhenAlreadyFrozen() async throws {
        // Given: Version 1.0.0 already frozen
        try await testFreezeVersion1_0_0()

        // When: Try to freeze again without --force
        let freezeResult = try await runCommand(
            executable: cliPath.path,
            arguments: ["freeze", "1.0.0"],
            workingDirectory: projectRoot
        )

        // Then: Command should fail
        XCTAssertFalse(
            freezeResult.success,
            "Should fail when trying to freeze already-frozen version"
        )

        // And: Error message should mention --force flag
        XCTAssertTrue(
            freezeResult.output.contains("--force") || freezeResult.output.contains("already exist"),
            "Error message should mention --force flag or existing fixtures"
        )

        print("✅ Error handling for already-frozen versions works")
    }

    // MARK: - Test: Scaffolding Skips Existing Files

    func testScaffoldingSkipsExistingFiles() async throws {
        // Given: Version 1.0.0 frozen with tests
        try await testFreezeVersion1_0_0()

        let testsDir = projectRoot.appendingPathComponent("FreezeRay/Tests")
        let driftTestPath = testsDir.appendingPathComponent("AppSchemaV1_DriftTests.swift")

        // Modify the drift test
        let customContent = "// MY CUSTOM ASSERTION\n"
        try customContent.write(to: driftTestPath, atomically: true, encoding: .utf8)

        // When: Freeze again with --force
        let freezeResult = try await runCommand(
            executable: cliPath.path,
            arguments: ["freeze", "1.0.0", "--force"],
            workingDirectory: projectRoot
        )

        XCTAssertTrue(freezeResult.success, "Freeze command failed")

        // Then: Custom drift test should NOT be overwritten
        let driftTestContent = try String(contentsOf: driftTestPath)
        XCTAssertEqual(
            driftTestContent,
            customContent,
            "Scaffolding should not overwrite existing test files"
        )

        // And: Output should indicate file was skipped
        XCTAssertTrue(
            freezeResult.output.contains("Skipped") || freezeResult.output.contains("already exists"),
            "Output should indicate test was skipped"
        )

        print("✅ Scaffolding preserves user customizations")
    }

    // MARK: - Helper: Run Command

    struct CommandResult {
        let success: Bool
        let output: String
        let exitCode: Int32
    }

    func runCommand(
        executable: String,
        arguments: [String],
        workingDirectory: URL
    ) async throws -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = workingDirectory

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        let output = [
            String(data: outputData, encoding: .utf8) ?? "",
            String(data: errorData, encoding: .utf8) ?? ""
        ].joined(separator: "\n")

        return CommandResult(
            success: process.terminationStatus == 0,
            output: output,
            exitCode: process.terminationStatus
        )
    }
}
