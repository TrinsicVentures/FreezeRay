import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import Foundation

/// Macro that generates a test method to freeze a schema version.
public struct FreezeSchemasMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Extract version number from @FreezeSchema(version: N)
        guard case .argumentList(let arguments) = node.arguments,
              let versionArg = arguments.first,
              let versionExpr = versionArg.expression.as(IntegerLiteralExprSyntax.self),
              let version = Int(versionExpr.literal.text) else {
            throw MacroError.invalidVersionArgument
        }

        // Get schema type name from declaration
        guard let enumDecl = declaration.as(EnumDeclSyntax.self) else {
            throw MacroError.notAnEnum
        }

        let schemaName = enumDecl.name.text

        // Load config to get fixture directory
        let fixtureDir = try loadFixtureDir()

        // Generate test method
        let testMethod: DeclSyntax = """
            func test_freezeV\(raw: version)() throws {
                try FreezeRayClient.freezeSchema(
                    version: \(raw: version),
                    schemaType: \(raw: schemaName).self,
                    fixtureDir: "\(raw: fixtureDir)"
                )
            }
            """

        return [testMethod]
    }

    /// Load fixture_dir from .freezeray.yml
    private static func loadFixtureDir() throws -> String {
        let fileManager = FileManager.default
        let currentDir = fileManager.currentDirectoryPath
        let configPath = URL(fileURLWithPath: currentDir)
            .appendingPathComponent(".freezeray.yml")
            .path

        guard fileManager.fileExists(atPath: configPath) else {
            throw MacroError.configNotFound(path: configPath)
        }

        let content = try String(contentsOfFile: configPath)
        let config = try parseSimpleYAML(content)

        guard let fixtureDir = config["fixture_dir"] else {
            throw MacroError.fixtureDirectoryNotConfigured
        }

        return fixtureDir
    }

    /// Simple YAML parser for basic key-value pairs
    private static func parseSimpleYAML(_ content: String) throws -> [String: String] {
        var result: [String: String] = [:]

        for line in content.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip comments and empty lines
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }

            // Parse "key: value" format
            let parts = trimmed.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }

            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts[1].trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))

            result[key] = value
        }

        return result
    }
}

// MARK: - Errors

enum MacroError: Error, CustomStringConvertible {
    case invalidVersionArgument
    case notAnEnum
    case configNotFound(path: String)
    case fixtureDirectoryNotConfigured
    case custom(String)

    var description: String {
        switch self {
        case .invalidVersionArgument:
            return "@FreezeSchema requires version argument: @FreezeSchema(version: 1)"
        case .notAnEnum:
            return "@FreezeSchema can only be applied to enum declarations"
        case .configNotFound(let path):
            return """
                .freezeray.yml not found at \(path)

                Create .freezeray.yml with:
                    fixture_dir: app/MyAppTests/Fixtures/SwiftData
                """
        case .fixtureDirectoryNotConfigured:
            return """
                fixture_dir not defined in .freezeray.yml

                Add to .freezeray.yml:
                    fixture_dir: app/MyAppTests/Fixtures/SwiftData
                """
        case .custom(let message):
            return message
        }
    }
}
