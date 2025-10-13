import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing

#if canImport(FreezeRayMacros)
import FreezeRayMacros

let testMacros: [String: Macro.Type] = [
    "FreezeSchema": FreezeMacro.self,
]

@Suite("FreezeRay Macro Tests")
struct FreezeRayTests {
    @Test("@FreezeSchema macro generates freeze and check functions")
    func freezeMacroExpansion() throws {
        assertMacroExpansion(
            """
            @FreezeSchema(version: "1.0.0")
            enum AppSchemaV1: VersionedSchema {
                static let versionIdentifier = Schema.Version(1, 0, 0)
                static var models: [any PersistentModel.Type] {
                    [User.self]
                }
            }
            """,
            expandedSource: """
            enum AppSchemaV1: VersionedSchema {
                static let versionIdentifier = Schema.Version(1, 0, 0)
                static var models: [any PersistentModel.Type] {
                    [User.self]
                }

                #if DEBUG
                @available(macOS 14, iOS 17, *)
                static func __freezeray_freeze_1_0_0() throws {
                    try FreezeRayRuntime.freeze(
                        schema: AppSchemaV1.self,
                        version: "1.0.0"
                    )
                }
                #endif

                #if DEBUG
                @available(macOS 14, iOS 17, *)
                static func __freezeray_check_1_0_0() throws {
                    try FreezeRayRuntime.checkDrift(
                        schema: AppSchemaV1.self,
                        version: "1.0.0"
                    )
                }
                #endif
            }
            """,
            macros: testMacros
        )
    }

    @Test("@FreezeSchema handles version with multiple dots")
    func freezeMacroVersionFormatting() throws {
        assertMacroExpansion(
            """
            @FreezeSchema(version: "2.1.3")
            enum AppSchemaV2: VersionedSchema {
                static var models: [any PersistentModel.Type] { [] }
            }
            """,
            expandedSource: """
            enum AppSchemaV2: VersionedSchema {
                static var models: [any PersistentModel.Type] { [] }

                #if DEBUG
                @available(macOS 14, iOS 17, *)
                static func __freezeray_freeze_2_1_3() throws {
                    try FreezeRayRuntime.freeze(
                        schema: AppSchemaV2.self,
                        version: "2.1.3"
                    )
                }
                #endif

                #if DEBUG
                @available(macOS 14, iOS 17, *)
                static func __freezeray_check_2_1_3() throws {
                    try FreezeRayRuntime.checkDrift(
                        schema: AppSchemaV2.self,
                        version: "2.1.3"
                    )
                }
                #endif
            }
            """,
            macros: testMacros
        )
    }
}
#endif
