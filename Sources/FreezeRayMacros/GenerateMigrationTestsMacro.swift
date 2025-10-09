import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Macro that generates migration smoke tests.
public struct GenerateMigrationTestsMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Get migration plan name
        guard let enumDecl = declaration.as(EnumDeclSyntax.self) else {
            throw MacroError.notAnEnum
        }

        let planName = enumDecl.name.text

        // Extract schema versions from the migration plan's schemas property
        let schemas = try extractSchemas(from: enumDecl)

        guard schemas.count >= 2 else {
            // No migrations to test if less than 2 schemas
            return []
        }

        var testMethods: [DeclSyntax] = []

        // Generate test for full migration path (first → last)
        let firstSchema = schemas.first!
        let lastSchema = schemas.last!

        let fullPathTest: DeclSyntax = """
            func test_migrationV\(raw: firstSchema.version)toV\(raw: lastSchema.version)() throws {
                try FreezeRayClient.testMigrationPath(
                    from: \(raw: firstSchema.name).self,
                    to: \(raw: lastSchema.name).self,
                    migrationPlan: \(raw: planName).self
                )
            }
            """

        testMethods.append(fullPathTest)

        // Generate test for each individual migration step
        for i in 0..<schemas.count - 1 {
            let fromSchema = schemas[i]
            let toSchema = schemas[i + 1]

            let stepTest: DeclSyntax = """
                func test_migrationV\(raw: fromSchema.version)toV\(raw: toSchema.version)() throws {
                    try FreezeRayClient.testMigrationPath(
                        from: \(raw: fromSchema.name).self,
                        to: \(raw: toSchema.name).self,
                        migrationPlan: \(raw: planName).self
                    )
                }
                """

            testMethods.append(stepTest)
        }

        return testMethods
    }

    /// Extract schema versions from the migration plan's schemas property
    private static func extractSchemas(from decl: EnumDeclSyntax) throws -> [SchemaInfo] {
        // Look for: static var schemas: [any VersionedSchema.Type] { [...] }
        for member in decl.memberBlock.members {
            guard let varDecl = member.decl.as(VariableDeclSyntax.self) else {
                continue
            }

            // Check if this is the "schemas" variable
            let isSchemas = varDecl.bindings.contains { binding in
                if let pattern = binding.pattern.as(IdentifierPatternSyntax.self) {
                    return pattern.identifier.text == "schemas"
                }
                return false
            }

            guard isSchemas, let binding = varDecl.bindings.first else {
                continue
            }

            // Extract array literal from initializer or accessor
            if let initializer = binding.initializer?.value.as(ArrayExprSyntax.self) {
                return try parseSchemaArray(initializer)
            } else if let accessor = binding.accessorBlock {
                // Handle both explicit getter and implicit computed property
                switch accessor.accessors {
                case .getter(let codeBlock):
                    // Implicit computed property: var schemas { [...] }
                    // Check for direct array expression (no return keyword)
                    if let arrayExpr = codeBlock.first?.item.as(ArrayExprSyntax.self) {
                        return try parseSchemaArray(arrayExpr)
                    }

                    // Explicit return: { return [...] }
                    for statement in codeBlock {
                        if let returnStmt = statement.item.as(ReturnStmtSyntax.self),
                           let arrayExpr = returnStmt.expression?.as(ArrayExprSyntax.self) {
                            return try parseSchemaArray(arrayExpr)
                        }
                    }
                case .accessors(let accessorList):
                    // Check for getter accessor in list
                    for accessor in accessorList {
                        if accessor.accessorSpecifier.text == "get",
                           let body = accessor.body {
                            // Check for direct array expression (no return keyword)
                            if let arrayExpr = body.statements.first?.item.as(ArrayExprSyntax.self) {
                                return try parseSchemaArray(arrayExpr)
                            }

                            // Explicit return
                            for statement in body.statements {
                                if let returnStmt = statement.item.as(ReturnStmtSyntax.self),
                                   let arrayExpr = returnStmt.expression?.as(ArrayExprSyntax.self) {
                                    return try parseSchemaArray(arrayExpr)
                                }
                            }
                        }
                    }
                }
            }
        }

        throw MacroError.schemasPropertyNotFound
    }

    /// Parse array literal to extract schema names and versions
    private static func parseSchemaArray(_ arrayExpr: ArrayExprSyntax) throws -> [SchemaInfo] {
        var schemas: [SchemaInfo] = []

        for element in arrayExpr.elements {
            // Extract "SchemaVN.self" → ("SchemaVN", N)
            if let memberAccess = element.expression.as(MemberAccessExprSyntax.self),
               memberAccess.declName.baseName.text == "self",
               let baseExpr = memberAccess.base?.as(DeclReferenceExprSyntax.self) {
                let schemaName = baseExpr.baseName.text

                // Extract version number from "SchemaVN"
                if schemaName.hasPrefix("SchemaV") {
                    let versionString = String(schemaName.dropFirst(7))  // Drop "SchemaV"
                    if let version = Int(versionString) {
                        schemas.append(SchemaInfo(name: schemaName, version: version))
                    }
                }
            }
        }

        return schemas.sorted { $0.version < $1.version }
    }
}

// MARK: - Schema Info

struct SchemaInfo {
    let name: String
    let version: Int
}

// MARK: - Errors

extension MacroError {
    static var schemasPropertyNotFound: MacroError {
        .custom("""
            @GenerateMigrationTests requires a 'schemas' property:

            static var schemas: [any VersionedSchema.Type] {
                [SchemaV1.self, SchemaV2.self, SchemaV3.self]
            }
            """)
    }
}
