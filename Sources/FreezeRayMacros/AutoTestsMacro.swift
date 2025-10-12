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

        // Parse schemas array to extract schema type names
        let schemaTypes = try extractSchemaTypes(from: declaration)

        // Generate per-version migration test functions
        var generatedFunctions: [DeclSyntax] = []

        for i in 0..<schemaTypes.count - 1 {
            let fromSchema = schemaTypes[i]
            let toSchema = schemaTypes[i + 1]

            // Generate function name: __freezeray_test_migrate_{from}_{to}
            let functionName = "__freezeray_test_migrate_\(fromSchema)_to_\(toSchema)"

            let migrationTestMethod: DeclSyntax = """
                #if DEBUG
                @available(macOS 14, iOS 17, *)
                static func \(raw: functionName)() throws {
                    try FreezeRayRuntime.testMigration(
                        from: \(raw: fromSchema).self,
                        to: \(raw: toSchema).self,
                        migrationPlan: \(raw: planName).self
                    )
                }
                #endif
                """

            generatedFunctions.append(migrationTestMethod)
        }

        // Generate monolithic test method (for convenience)
        let monolithicTestMethod: DeclSyntax = """
            #if DEBUG
            @available(macOS 14, iOS 17, *)
            static func __freezeray_test_migrations() throws {
                try FreezeRayRuntime.testAllMigrations(
                    migrationPlan: \(raw: planName).self
                )
            }
            #endif
            """

        generatedFunctions.append(monolithicTestMethod)

        return generatedFunctions
    }

    /// Extracts schema type names from the `schemas` static property
    private static func extractSchemaTypes(from declaration: some DeclGroupSyntax) throws -> [String] {
        // Find the `static var schemas` property
        guard let schemasProperty = declaration.memberBlock.members.first(where: { member in
            guard let varDecl = member.decl.as(VariableDeclSyntax.self) else { return false }
            return varDecl.bindings.contains { binding in
                binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text == "schemas"
            }
        }) else {
            throw MacroError.schemasPropertyNotFound
        }

        guard let varDecl = schemasProperty.decl.as(VariableDeclSyntax.self),
              let binding = varDecl.bindings.first,
              let accessorBlock = binding.accessorBlock,
              case .getter(let codeBlockItems) = accessorBlock.accessors else {
            throw MacroError.invalidSchemasProperty
        }

        // Find the array expression in the getter
        guard let returnStmt = codeBlockItems.first(where: { item in
            item.item.is(ArrayExprSyntax.self) ||
            item.item.as(ReturnStmtSyntax.self)?.expression?.is(ArrayExprSyntax.self) == true
        }) else {
            throw MacroError.schemasArrayNotFound
        }

        let arrayExpr: ArrayExprSyntax?
        if let array = returnStmt.item.as(ArrayExprSyntax.self) {
            arrayExpr = array
        } else if let returnStmt = returnStmt.item.as(ReturnStmtSyntax.self),
                  let array = returnStmt.expression?.as(ArrayExprSyntax.self) {
            arrayExpr = array
        } else {
            arrayExpr = nil
        }

        guard let array = arrayExpr else {
            throw MacroError.schemasArrayNotFound
        }

        // Extract schema type names from array elements
        var schemaTypes: [String] = []
        for element in array.elements {
            // Each element looks like: AppSchemaV1.self
            if let memberAccess = element.expression.as(MemberAccessExprSyntax.self),
               memberAccess.declName.baseName.text == "self",
               let baseExpr = memberAccess.base?.as(DeclReferenceExprSyntax.self) {
                schemaTypes.append(baseExpr.baseName.text)
            }
        }

        guard !schemaTypes.isEmpty else {
            throw MacroError.noSchemasFound
        }

        return schemaTypes
    }
}

// MARK: - Errors

extension MacroError {
    static var notAStructOrEnum: MacroError {
        .custom("@TestMigrations can only be applied to struct or enum declarations")
    }

    static var schemasPropertyNotFound: MacroError {
        .custom("@TestMigrations requires a 'static var schemas' property")
    }

    static var invalidSchemasProperty: MacroError {
        .custom("'schemas' property must be a computed property with a getter")
    }

    static var schemasArrayNotFound: MacroError {
        .custom("Could not find array expression in 'schemas' getter")
    }

    static var noSchemasFound: MacroError {
        .custom("No schema types found in 'schemas' array")
    }
}
