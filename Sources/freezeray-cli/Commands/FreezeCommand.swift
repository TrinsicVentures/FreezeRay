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

    @Option(name: .long, help: "Simulator to use (default: iPhone 16)")
    var simulator: String = "iPhone 16"

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

        let scheme = try SimulatorManager.discoverScheme(projectPath: projectPath)
        print("   Scheme: \(scheme) (auto-detected)")

        let testTarget = SimulatorManager.inferTestTarget(from: scheme)
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

        // 4. Run freeze operation in simulator
        let manager = SimulatorManager()
        let simulatorFixturesURL = try manager.runFreezeInSimulator(
            projectPath: projectPath,
            scheme: scheme,
            testTarget: testTarget,
            schemaType: freezeAnnotation.typeName,
            version: version,
            simulator: simulator
        )

        // 5. Copy fixtures from simulator to project
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

        // 6. Scaffold test if not exists
        // TODO: Implement test scaffolding
        print("🔹 Test scaffolding not yet implemented")
        print("   Manual test creation required for now")
        print("")

        print("✅ Schema v\(version) frozen successfully!")
        print("")
        print("📝 Next steps:")
        print("   1. Review fixtures: \(fixturesDir.path)")
        print("   2. Create validation test for \(freezeAnnotation.typeName)")
        print("   3. Add FreezeRay/ folder to Xcode project if needed")
        print("   4. Run tests: xcodebuild test -scheme \(scheme)")
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
