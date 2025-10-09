import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Macro that seals a schema version and generates fixture artifacts.
public struct SealMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Extract version from @Seal(version: "1.4.0")
        guard case .argumentList(let arguments) = node.arguments,
              let versionArg = arguments.first(where: { arg in
                  arg.label?.text == "version" || arg.label == nil
              }),
              let stringExpr = versionArg.expression.as(StringLiteralExprSyntax.self),
              let segment = stringExpr.segments.first?.as(StringSegmentSyntax.self) else {
            throw MacroError.invalidVersionArgument
        }

        let version = segment.content.text

        // Get schema type name
        guard let enumDecl = declaration.as(EnumDeclSyntax.self) else {
            throw MacroError.notAnEnum
        }

        let schemaName = enumDecl.name.text

        // Generate fixture sealing function
        // This will be called at build time to generate fixtures
        let sealFunction: DeclSyntax = """
            #if DEBUG
            @available(macOS 14, iOS 17, *)
            static func __freezeray_seal_\(raw: version.replacingOccurrences(of: ".", with: "_"))() throws {
                try FreezeRayRuntime.seal(
                    schema: \(raw: schemaName).self,
                    version: "\(raw: version)"
                )
            }
            #endif
            """

        // Generate drift check
        // This validates the sealed schema hasn't changed
        let driftCheck: DeclSyntax = """
            #if DEBUG
            @available(macOS 14, iOS 17, *)
            static func __freezeray_check_\(raw: version.replacingOccurrences(of: ".", with: "_"))() throws {
                try FreezeRayRuntime.checkDrift(
                    schema: \(raw: schemaName).self,
                    version: "\(raw: version)"
                )
            }
            #endif
            """

        return [sealFunction, driftCheck]
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
            return "@Seal requires version argument: @Seal(version: \"1.4.0\")"
        case .notAnEnum:
            return "@Seal can only be applied to enum declarations"
        case .custom(let message):
            return message
        }
    }
}
