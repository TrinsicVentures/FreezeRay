import Testing
import Foundation
@testable import freezeray_cli

/// Unit tests for TestScaffolding helper functions
/// These tests validate the scaffolding and version discovery logic
@Suite("TestScaffolding Helper Tests")
struct FreezeCommandTests {

    // MARK: - findPreviousVersion Tests

    @Test("findPreviousVersion returns nil when fixtures directory doesn't exist")
    func testFindPreviousVersion_NoDirectory() throws {
        let scaffolding = TestScaffolding()
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

        let result = scaffolding.findPreviousVersion(current: "2.0.0", fixturesDir: tempDir)

        #expect(result == nil)
    }

    @Test("findPreviousVersion returns nil when no previous versions exist")
    func testFindPreviousVersion_NoPreviousVersions() throws {
        let scaffolding = TestScaffolding()
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Create current version directory
        try FileManager.default.createDirectory(
            at: tempDir.appendingPathComponent("2.0.0"),
            withIntermediateDirectories: true
        )

        let result = scaffolding.findPreviousVersion(current: "2.0.0", fixturesDir: tempDir)

        #expect(result == nil)
    }

    @Test("findPreviousVersion returns highest version less than current")
    func testFindPreviousVersion_MultipleVersions() throws {
        let scaffolding = TestScaffolding()
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Create version directories
        for version in ["1.0.0", "1.5.0", "2.0.0", "3.0.0"] {
            try FileManager.default.createDirectory(
                at: tempDir.appendingPathComponent(version),
                withIntermediateDirectories: true
            )
        }

        let result = scaffolding.findPreviousVersion(current: "3.0.0", fixturesDir: tempDir)

        #expect(result == "2.0.0")
    }

    @Test("findPreviousVersion handles semantic versioning correctly")
    func testFindPreviousVersion_SemanticVersioning() throws {
        let scaffolding = TestScaffolding()
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Create versions with different minor/patch numbers
        for version in ["1.0.0", "1.9.0", "1.10.0", "1.11.0", "2.0.0"] {
            try FileManager.default.createDirectory(
                at: tempDir.appendingPathComponent(version),
                withIntermediateDirectories: true
            )
        }

        let result = scaffolding.findPreviousVersion(current: "2.0.0", fixturesDir: tempDir)

        // Should return 1.11.0, not 1.9.0 (semantic versioning, not lexicographic)
        #expect(result == "1.11.0")
    }

    @Test("findPreviousVersion ignores non-version directories")
    func testFindPreviousVersion_IgnoresNonVersions() throws {
        let scaffolding = TestScaffolding()
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Create version directories and some junk
        for dir in ["1.0.0", ".git", "README.md", "v1.5.0", "2.0.0"] {
            try FileManager.default.createDirectory(
                at: tempDir.appendingPathComponent(dir),
                withIntermediateDirectories: true
            )
        }

        let result = scaffolding.findPreviousVersion(current: "2.0.0", fixturesDir: tempDir)

        // Should only consider valid semantic versions (1.0.0)
        #expect(result == "1.0.0")
    }

    @Test("findPreviousVersion handles patch version increments")
    func testFindPreviousVersion_PatchVersions() throws {
        let scaffolding = TestScaffolding()
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Create patch versions
        for version in ["1.0.0", "1.0.1", "1.0.2", "1.0.5"] {
            try FileManager.default.createDirectory(
                at: tempDir.appendingPathComponent(version),
                withIntermediateDirectories: true
            )
        }

        let result = scaffolding.findPreviousVersion(current: "1.0.5", fixturesDir: tempDir)

        #expect(result == "1.0.2")
    }

    // MARK: - scaffoldDriftTest Tests

    @Test("scaffoldDriftTest creates new file when it doesn't exist")
    func testScaffoldDriftTest_CreatesNewFile() throws {
        let scaffolding = TestScaffolding()
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let result = try scaffolding.scaffoldDriftTest(
            testsDir: tempDir,
            schemaType: "AppSchemaV1",
            appTarget: "MyApp",
            version: "1.0.0"
        )

        #expect(result.created == true)
        #expect(result.fileName == "AppSchemaV1_DriftTests.swift")

        // Verify file was created
        let filePath = tempDir.appendingPathComponent(result.fileName)
        #expect(FileManager.default.fileExists(atPath: filePath.path))

        // Verify content contains expected elements
        let content = try String(contentsOf: filePath)
        #expect(content.contains("import Testing"))
        #expect(content.contains("@testable import MyApp"))
        #expect(content.contains("AppSchemaV1.__freezeray_check_1_0_0()"))
        #expect(content.contains("TODO"))
    }

    @Test("scaffoldDriftTest skips existing file")
    func testScaffoldDriftTest_SkipsExistingFile() throws {
        let scaffolding = TestScaffolding()
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Create existing file
        let fileName = "AppSchemaV1_DriftTests.swift"
        let filePath = tempDir.appendingPathComponent(fileName)
        try "// Existing user content".write(to: filePath, atomically: true, encoding: .utf8)

        let result = try scaffolding.scaffoldDriftTest(
            testsDir: tempDir,
            schemaType: "AppSchemaV1",
            appTarget: "MyApp",
            version: "1.0.0"
        )

        #expect(result.created == false)
        #expect(result.fileName == fileName)

        // Verify existing content wasn't modified
        let content = try String(contentsOf: filePath)
        #expect(content == "// Existing user content")
    }

    // MARK: - scaffoldMigrationTest Tests

    @Test("scaffoldMigrationTest creates new file when it doesn't exist")
    func testScaffoldMigrationTest_CreatesNewFile() throws {
        let scaffolding = TestScaffolding()
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let result = try scaffolding.scaffoldMigrationTest(
            testsDir: tempDir,
            migrationPlan: "AppMigrations",
            fromVersion: "1.0.0",
            toVersion: "2.0.0",
            appTarget: "MyApp"
        )

        #expect(result.created == true)
        #expect(result.fileName == "MigrateV1_0_0toV2_0_0_Tests.swift")

        // Verify file was created
        let filePath = tempDir.appendingPathComponent(result.fileName)
        #expect(FileManager.default.fileExists(atPath: filePath.path))

        // Verify content contains expected elements
        let content = try String(contentsOf: filePath)
        #expect(content.contains("import Testing"))
        #expect(content.contains("@testable import MyApp"))
        #expect(content.contains("AppMigrations.__freezeray_test_migrate_1_0_0_to_2_0_0()"))
        #expect(content.contains("TODO"))
        #expect(content.contains("v1.0.0 → v2.0.0"))
    }

    @Test("scaffoldMigrationTest skips existing file")
    func testScaffoldMigrationTest_SkipsExistingFile() throws {
        let scaffolding = TestScaffolding()
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Create existing file
        let fileName = "MigrateV1_0_0toV2_0_0_Tests.swift"
        let filePath = tempDir.appendingPathComponent(fileName)
        try "// Existing migration test".write(to: filePath, atomically: true, encoding: .utf8)

        let result = try scaffolding.scaffoldMigrationTest(
            testsDir: tempDir,
            migrationPlan: "AppMigrations",
            fromVersion: "1.0.0",
            toVersion: "2.0.0",
            appTarget: "MyApp"
        )

        #expect(result.created == false)
        #expect(result.fileName == fileName)

        // Verify existing content wasn't modified
        let content = try String(contentsOf: filePath)
        #expect(content == "// Existing migration test")
    }
}
