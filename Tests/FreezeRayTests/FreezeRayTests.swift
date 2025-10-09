import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

#if canImport(FreezeRayMacros)
import FreezeRayMacros

final class FreezeRayTests: XCTestCase {
    func testFreezeSchemaExpansion() throws {
        // TODO: Add macro expansion tests
        // This requires setting up .freezeray.yml in test environment
    }

    func testGenerateMigrationTestsExpansion() throws {
        // TODO: Add macro expansion tests
    }
}
#endif
