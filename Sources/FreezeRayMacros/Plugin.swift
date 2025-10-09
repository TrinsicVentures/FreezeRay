import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct FreezeRayPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        FreezeSchemasMacro.self,
        GenerateMigrationTestsMacro.self,
    ]
}
