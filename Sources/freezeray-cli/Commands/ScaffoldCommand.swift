import ArgumentParser
import Foundation

struct ScaffoldCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "scaffold",
        abstract: "Scaffold a test file for a frozen schema (rarely needed - freeze does this automatically)"
    )

    @Argument(help: "Schema version to scaffold test for")
    var version: String

    @Flag(name: .long, help: "Overwrite existing test file")
    var force: Bool = false

    func run() async throws {
        print("🔹 Scaffolding test for version: \(version)")

        // TODO: Implement scaffold command
        throw FreezeRayError.custom("scaffold command not yet implemented - coming in v0.4.0")
    }
}
