import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Macro that generates migration smoke tests.
public struct AutoTestsMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Get migration plan name
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw MacroError.notAStruct
        }

        let planName = structDecl.name.text

        // Generate test class
        let testClass: DeclSyntax = """
            #if DEBUG
            import Testing

            @available(macOS 14, iOS 17, *)
            @Suite("FreezeRay Migration Tests")
            struct __FreezeRay_\(raw: planName)_Tests {
                @Test("Migrate all sealed fixtures to HEAD")
                func testAllMigrations() throws {
                    try FreezeRayRuntime.testAllMigrations(
                        migrationPlan: \(raw: planName).self
                    )
                }
            }
            #endif
            """

        return [testClass]
    }
}

// MARK: - Errors

extension MacroError {
    static var notAStruct: MacroError {
        .custom("@AutoTests can only be applied to struct declarations")
    }
}
