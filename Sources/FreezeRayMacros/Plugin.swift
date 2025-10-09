import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct FreezeRayPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        SealMacro.self,
        AutoTestsMacro.self,
    ]
}
