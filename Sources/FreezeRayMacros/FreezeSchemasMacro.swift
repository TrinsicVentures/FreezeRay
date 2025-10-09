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
        // Extract arguments from @FreezeSchema(version: N, fixtureDir: "path")
        guard case .argumentList(let arguments) = node.arguments else {
            throw MacroError.invalidVersionArgument
        }

        // Extract version
        guard let versionArg = arguments.first(where: { arg in
            arg.label?.text == "version" || arg.label == nil
        }),
              let versionExpr = versionArg.expression.as(IntegerLiteralExprSyntax.self),
              let version = Int(versionExpr.literal.text) else {
            throw MacroError.invalidVersionArgument
        }

        // Extract fixtureDir (default to "Tests/Fixtures/SwiftData")
        let fixtureDir: String
        if let fixtureDirArg = arguments.first(where: { $0.label?.text == "fixtureDir" }),
           let stringExpr = fixtureDirArg.expression.as(StringLiteralExprSyntax.self),
           let segment = stringExpr.segments.first?.as(StringSegmentSyntax.self) {
            fixtureDir = segment.content.text
        } else {
            fixtureDir = "Tests/Fixtures/SwiftData"
        }

        // Get schema type name from declaration
        guard let enumDecl = declaration.as(EnumDeclSyntax.self) else {
            throw MacroError.notAnEnum
        }

        let schemaName = enumDecl.name.text

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
}

// MARK: - Errors

enum MacroError: Error, CustomStringConvertible {
    case invalidVersionArgument
    case notAnEnum
    case custom(String)

    var description: String {
        switch self {
        case .invalidVersionArgument:
            return "@FreezeSchema requires version argument: @FreezeSchema(version: 1)"
        case .notAnEnum:
            return "@FreezeSchema can only be applied to enum declarations"
        case .custom(let message):
            return message
        }
    }
}
