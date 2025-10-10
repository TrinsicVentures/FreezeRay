// Sources/freezeray-cli/Simulator/SimulatorManager.swift

import Foundation

enum SimulatorError: Error, CustomStringConvertible {
    case simulatorNotFound(String)
    case buildFailed(output: String)
    case testFailed(output: String)
    case containerNotFound(bundleID: String)
    case fixturesNotFound(URL)
    case invalidOutput(String)

    var description: String {
        switch self {
        case .simulatorNotFound(let name):
            return "Simulator '\(name)' not found. Use 'xcrun simctl list devices' to see available simulators."
        case .buildFailed(let output):
            return "Build failed:\n\(output)"
        case .testFailed(let output):
            return "Test execution failed:\n\(output)"
        case .containerNotFound(let bundleID):
            return "Could not find app container for bundle ID: \(bundleID)"
        case .fixturesNotFound(let url):
            return "Fixtures not found at expected location: \(url.path)"
        case .invalidOutput(let message):
            return "Invalid command output: \(message)"
        }
    }
}

struct SimulatorManager {

    /// Runs the freeze operation in iOS simulator and extracts fixtures
    /// - Parameters:
    ///   - projectPath: Path to .xcodeproj or .xcworkspace
    ///   - scheme: Xcode scheme name
    ///   - testTarget: Test target name
    ///   - schemaType: Schema type name (e.g., "SchemaV1")
    ///   - version: Version string (e.g., "1.0.0")
    ///   - simulator: Simulator name (e.g., "iPhone 16")
    /// - Returns: URL to the extracted fixtures directory
    func runFreezeInSimulator(
        projectPath: String,
        scheme: String,
        testTarget: String,
        schemaType: String,
        version: String,
        simulator: String = "iPhone 16"
    ) throws -> URL {
        // Validate simulator exists
        try validateSimulator(simulator)

        // 1. Build test target
        print("🔹 Building test target for iOS Simulator...")
        try buildForTesting(
            projectPath: projectPath,
            scheme: scheme,
            simulator: simulator
        )

        // 2. Run freeze test
        print("🔹 Running freeze operation in simulator...")
        let bundleID = try runFreezeTest(
            projectPath: projectPath,
            scheme: scheme,
            testTarget: testTarget,
            version: version,
            simulator: simulator
        )

        // 3. Find simulator container
        print("🔹 Locating simulator container...")
        let containerURL = try findSimulatorContainer(bundleID: bundleID, simulator: simulator)

        // 4. Locate fixtures in simulator's Documents directory
        let fixturesURL = containerURL
            .appendingPathComponent("Documents")
            .appendingPathComponent("FreezeRay")
            .appendingPathComponent("Fixtures")
            .appendingPathComponent(version)

        // Verify fixtures exist
        guard FileManager.default.fileExists(atPath: fixturesURL.path) else {
            throw SimulatorError.fixturesNotFound(fixturesURL)
        }

        return fixturesURL
    }

    // MARK: - Private Helpers

    private func validateSimulator(_ name: String) throws {
        // List available simulators
        let output = try shell("xcrun", "simctl", "list", "devices", "available")

        // Check if simulator exists
        if !output.contains(name) {
            throw SimulatorError.simulatorNotFound(name)
        }
    }

    private func buildForTesting(
        projectPath: String,
        scheme: String,
        simulator: String
    ) throws {
        let projectArg: String
        if projectPath.hasSuffix(".xcworkspace") {
            projectArg = "-workspace"
        } else {
            projectArg = "-project"
        }

        let destination = "platform=iOS Simulator,name=\(simulator)"

        let output = try shell(
            "xcodebuild",
            projectArg, projectPath,
            "-scheme", scheme,
            "-destination", destination,
            "build-for-testing"
        )

        // Check for build failures
        if output.contains("** BUILD FAILED **") {
            throw SimulatorError.buildFailed(output: output)
        }
    }

    private func runFreezeTest(
        projectPath: String,
        scheme: String,
        testTarget: String,
        version: String,
        simulator: String
    ) throws -> String {
        let projectArg: String
        if projectPath.hasSuffix(".xcworkspace") {
            projectArg = "-workspace"
        } else {
            projectArg = "-project"
        }

        let destination = "platform=iOS Simulator,name=\(simulator)"

        // The test should be named FreezeSchemaV{version}
        // e.g., for version "1.0.0", test name is "FreezeSchemaV1_0_0"
        let versionSafe = version.replacingOccurrences(of: ".", with: "_")
        let testName = "\(testTarget)/FreezeSchemaV\(versionSafe)"

        let output = try shell(
            "xcodebuild",
            projectArg, projectPath,
            "-scheme", scheme,
            "-destination", destination,
            "test-without-building",
            "-only-testing:\(testName)"
        )

        // Check for test failures
        if output.contains("** TEST FAILED **") {
            throw SimulatorError.testFailed(output: output)
        }

        // Extract bundle ID from output
        // Look for pattern like: "Test target ClearlyTests.xctest"
        // Bundle ID is typically the scheme name
        return scheme
    }

    private func findSimulatorContainer(
        bundleID: String,
        simulator: String
    ) throws -> URL {
        // First, boot the simulator if not already booted
        _ = try? shell("xcrun", "simctl", "boot", simulator)
        // Ignore errors - simulator may already be booted

        // Get app container path
        let output = try shell(
            "xcrun", "simctl", "get_app_container",
            "booted",
            bundleID,
            "data"
        )

        let path = output.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !path.isEmpty else {
            throw SimulatorError.containerNotFound(bundleID: bundleID)
        }

        return URL(fileURLWithPath: path)
    }

    private func shell(_ args: String...) throws -> String {
        let process = Process()
        let pipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = args
        process.standardOutput = pipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        let output = String(data: data, encoding: .utf8) ?? ""
        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

        if process.terminationStatus != 0 {
            throw SimulatorError.invalidOutput(
                "Command failed: \(args.joined(separator: " "))\n\(errorOutput)"
            )
        }

        return output + errorOutput
    }
}

// MARK: - Project Discovery

extension SimulatorManager {

    /// Auto-discovers project file (*.xcodeproj or *.xcworkspace)
    static func discoverProject(in directory: URL) throws -> String {
        let fm = FileManager.default
        let contents = try fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )

        // Prefer workspace over project
        if let workspace = contents.first(where: { $0.pathExtension == "xcworkspace" }) {
            return workspace.path
        }

        if let project = contents.first(where: { $0.pathExtension == "xcodeproj" }) {
            return project.path
        }

        throw SimulatorError.invalidOutput("No .xcodeproj or .xcworkspace found in \(directory.path)")
    }

    /// Auto-discovers scheme by listing available schemes
    static func discoverScheme(projectPath: String) throws -> String {
        let projectArg: String
        if projectPath.hasSuffix(".xcworkspace") {
            projectArg = "-workspace"
        } else {
            projectArg = "-project"
        }

        let manager = SimulatorManager()
        let output = try manager.shell("xcodebuild", projectArg, projectPath, "-list")

        // Parse output to find first scheme
        // Output format:
        // Schemes:
        //     Clearly
        //     ClearlyTests

        let lines = output.components(separatedBy: .newlines)
        var inSchemesSection = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed == "Schemes:" {
                inSchemesSection = true
                continue
            }

            if inSchemesSection && !trimmed.isEmpty && trimmed != "Schemes:" {
                // First non-empty line after "Schemes:" is the first scheme
                return trimmed
            }
        }

        throw SimulatorError.invalidOutput("No schemes found in project")
    }

    /// Infers test target from scheme name (typically {SchemeName}Tests)
    static func inferTestTarget(from scheme: String) -> String {
        return "\(scheme)Tests"
    }
}
