import ArgumentParser
import Foundation

public struct FreezeRayCLI: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "freezeray",
        abstract: "Freeze SwiftData schemas for safe production releases",
        version: "0.4.0",
        subcommands: [
            FreezeCommand.self,
            ScaffoldCommand.self,
            ListCommand.self,
        ],
        defaultSubcommand: nil
    )

    public init() {}
}
