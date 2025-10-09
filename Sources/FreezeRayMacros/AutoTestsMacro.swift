import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Macro that generates migration smoke tests.
public struct AutoTestsMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Get migration plan name
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw MacroError.notAStruct
        }

        let planName = structDecl.name.text

        // Generate test method inside the struct
        let testMethod: DeclSyntax = """
            #if DEBUG
            @available(macOS 14, iOS 17, *)
            static func __freezeray_test_migrations() throws {
                try FreezeRayRuntime.testAllMigrations(
                    migrationPlan: \(raw: planName).self
                )
            }
            #endif
            """

        return [testMethod]
    }
}

// MARK: - Errors

extension MacroError {
    static var notAStruct: MacroError {
        .custom("@AutoTests can only be applied to struct declarations")
    }
}
