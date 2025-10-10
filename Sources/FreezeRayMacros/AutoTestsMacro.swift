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
        // Get migration plan name from either struct or enum
        let planName: String
        if let structDecl = declaration.as(StructDeclSyntax.self) {
            planName = structDecl.name.text
        } else if let enumDecl = declaration.as(EnumDeclSyntax.self) {
            planName = enumDecl.name.text
        } else {
            throw MacroError.notAStructOrEnum
        }

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
    static var notAStructOrEnum: MacroError {
        .custom("@AutoTests can only be applied to struct or enum declarations")
    }
}
