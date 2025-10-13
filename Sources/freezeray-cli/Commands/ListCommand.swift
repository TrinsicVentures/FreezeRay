import ArgumentParser
import Foundation

struct ListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List all discovered schemas and their freeze status"
    )

    @Flag(name: .long, help: "Show file paths and checksums")
    var verbose: Bool = false

    func run() throws {
        print("📦 Discovering schemas...")

        // TODO: Implement list command
        throw FreezeRayError.custom("list command not yet implemented - coming in v0.4.0")
    }
}
