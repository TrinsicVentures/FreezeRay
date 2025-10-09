import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct FreezeRayPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        FreezeMacro.self,
        AutoTestsMacro.self,
    ]
}
