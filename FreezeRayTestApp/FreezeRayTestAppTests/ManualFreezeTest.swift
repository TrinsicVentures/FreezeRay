import XCTest
import FreezeRay
@testable import FreezeRayTestApp

/// Manual test to verify the macro-generated freeze function exists and works
final class ManualFreezeTest: XCTestCase {

    func testMacroGeneratedFunctionExists() throws {
        // This will fail to compile if the macro didn't generate the function
        NSLog("About to call freeze function...")

        // Try calling FreezeRayRuntime directly to see if it works
        do {
            NSLog("Calling FreezeRayRuntime.freeze directly...")
            try FreezeRayRuntime.freeze(
                schema: AppSchemaV3.self,
                version: "3.0.0"
            )
            NSLog("Direct FreezeRayRuntime call completed!")
        } catch {
            NSLog("Direct call error: \(error)")
        }

        do {
            // Call the macro-generated function
            NSLog("Calling macro-generated function...")
            try AppSchemaV3.__freezeray_freeze_3_0_0()
            NSLog("Freeze function completed without error")
        } catch {
            NSLog("Freeze function threw error: \(error)")
            throw error
        }

        // Check if the debug log was written
        if let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            // Write path to /tmp so we can find it
            let pathInfo = """
            Documents directory: \(docsDir.path)
            Marker file would be at: \(docsDir.appendingPathComponent("FREEZERAY_WAS_CALLED.txt").path)
            """
            try? pathInfo.write(toFile: "/tmp/freezeray_test_path.txt", atomically: true, encoding: .utf8)

            NSLog("========== TEST SANDBOX INFO ==========")
            NSLog("Documents directory: \(docsDir.path)")

            // List everything in Documents
            if let contents = try? FileManager.default.contentsOfDirectory(atPath: docsDir.path) {
                NSLog("Contents of Documents: \(contents)")
            }

            // Check for marker file (MUST exist if freeze was called)
            let markerFile = docsDir.appendingPathComponent("FREEZERAY_WAS_CALLED.txt")
            if FileManager.default.fileExists(atPath: markerFile.path) {
                NSLog("✅ MARKER FILE EXISTS!")
                if let contents = try? String(contentsOf: markerFile) {
                    NSLog("Marker contents: \(contents)")
                }
            } else {
                NSLog("❌ MARKER FILE NOT FOUND!")
            }

            XCTAssert(FileManager.default.fileExists(atPath: markerFile.path),
                     "MARKER FILE NOT FOUND! FreezeRayRuntime.freeze() was NOT called!")

            let logFile = docsDir.appendingPathComponent("freezeray_debug.log")
            if FileManager.default.fileExists(atPath: logFile.path) {
                let contents = try? String(contentsOf: logFile)
                NSLog("Debug log exists! Contents:\n\(contents ?? "empty")")
            } else {
                NSLog("No debug log found at: \(logFile.path)")
            }

            // Check for fixtures
            let fixturesDir = docsDir
                .appendingPathComponent("FreezeRay")
                .appendingPathComponent("Fixtures")
                .appendingPathComponent("3.0.0")

            if FileManager.default.fileExists(atPath: fixturesDir.path) {
                NSLog("Fixtures directory exists!")
                let files = try? FileManager.default.contentsOfDirectory(atPath: fixturesDir.path)
                NSLog("Files: \(files ?? [])")
            } else {
                NSLog("Fixtures directory does NOT exist at: \(fixturesDir.path)")
            }
        }
    }
}
