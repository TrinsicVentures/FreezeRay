import Testing
import Foundation
import FreezeRay
@testable import FreezeRayTestApp

@Suite("FreezeRay Integration Tests", .serialized)
struct FreezeRayIntegrationTests {

    init() {
        // Clean up fixtures before tests
        try? FileManager.default.removeItem(atPath: "FreezeRay/Fixtures")
    }

    @Test("Freeze schemas and run migrations")
    func testFullWorkflow() throws {
        // 1. Freeze V1 schema
        print("🔹 Freezing V1 schema...")
        try AppSchemaV1.__freezeray_freeze_1_0_0()

        var fixtureDir = URL(fileURLWithPath: "FreezeRay/Fixtures/1.0.0")
        #expect(FileManager.default.fileExists(atPath: fixtureDir.path))
        #expect(FileManager.default.fileExists(atPath: fixtureDir.appendingPathComponent("App.sqlite").path))
        #expect(FileManager.default.fileExists(atPath: fixtureDir.appendingPathComponent("schema.json").path))
        #expect(FileManager.default.fileExists(atPath: fixtureDir.appendingPathComponent("schema.sha256").path))
        print("✅ V1 frozen successfully")

        // 2. Freeze V2 schema
        print("🔹 Freezing V2 schema...")
        try AppSchemaV2.__freezeray_freeze_2_0_0()

        fixtureDir = URL(fileURLWithPath: "FreezeRay/Fixtures/2.0.0")
        #expect(FileManager.default.fileExists(atPath: fixtureDir.path))
        print("✅ V2 frozen successfully")

        // 3. Check drift detection
        print("🔹 Checking drift detection...")
        try AppSchemaV1.__freezeray_check_1_0_0()
        try AppSchemaV2.__freezeray_check_2_0_0()
        print("✅ Drift detection passed")

        // 4. Run migration tests
        print("🔹 Running migration tests...")
        try AppMigrations.__freezeray_test_migrations()
        print("✅ Migration tests passed")

        print("\n🎉 All FreezeRay tests passed!")
    }
}
