import Foundation
import SwiftSyntax
import SwiftParser

// MARK: - Discovered Annotations

struct FreezeAnnotation: Sendable {
    let version: String
    let typeName: String
    let filePath: String
    let lineNumber: Int
}

struct AutoTestsAnnotation: Sendable {
    let typeName: String
    let filePath: String
    let lineNumber: Int
}

// MARK: - AST Visitor

class MacroDiscoveryVisitor: SyntaxVisitor {
    var freezeAnnotations: [FreezeAnnotation] = []
    var autoTestsAnnotations: [AutoTestsAnnotation] = []
    var currentFile: String = ""

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        // Look for @Freeze(version: "X.Y.Z") or @FreezeRay.Freeze(version: "X.Y.Z")
        // Also check for @AutoTests (MigrationPlan might be an enum)
        for attribute in node.attributes {
            if let attr = attribute.as(AttributeSyntax.self) {
                let attrName = attr.attributeName.trimmedDescription

                // Handle both @Freeze and @FreezeRay.Freeze
                if attrName == "Freeze" || attrName.hasSuffix(".Freeze") {
                    if let version = extractVersion(from: attr) {
                        let lineNumber = node.position.utf8Offset
                        freezeAnnotations.append(FreezeAnnotation(
                            version: version,
                            typeName: node.name.text,
                            filePath: currentFile,
                            lineNumber: lineNumber
                        ))
                    }
                }

                // Also check for @AutoTests on enums
                if attrName == "AutoTests" || attrName.hasSuffix(".AutoTests") {
                    let lineNumber = node.position.utf8Offset
                    autoTestsAnnotations.append(AutoTestsAnnotation(
                        typeName: node.name.text,
                        filePath: currentFile,
                        lineNumber: lineNumber
                    ))
                }
            }
        }
        return .visitChildren
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        // Look for @AutoTests or @FreezeRay.AutoTests on structs
        for attribute in node.attributes {
            if let attr = attribute.as(AttributeSyntax.self) {
                let attrName = attr.attributeName.trimmedDescription

                if attrName == "AutoTests" || attrName.hasSuffix(".AutoTests") {
                    let lineNumber = node.position.utf8Offset
                    autoTestsAnnotations.append(AutoTestsAnnotation(
                        typeName: node.name.text,
                        filePath: currentFile,
                        lineNumber: lineNumber
                    ))
                }
            }
        }
        return .visitChildren
    }

    private func extractVersion(from attribute: AttributeSyntax) -> String? {
        guard let arguments = attribute.arguments else {
            return nil
        }

        // Handle LabeledExprListSyntax (argument list)
        if let labeledArgs = arguments.as(LabeledExprListSyntax.self) {
            for arg in labeledArgs {
                if arg.label?.text == "version" {
                    if let stringExpr = arg.expression.as(StringLiteralExprSyntax.self),
                       let segment = stringExpr.segments.first?.as(StringSegmentSyntax.self) {
                        return segment.content.text
                    }
                }
            }
        }

        return nil
    }
}

// MARK: - Discovery Function

/// Discovers all @Freeze and @AutoTests annotations in the given source paths
func discoverMacros(in sourcePaths: [String]) throws -> (
    freezeAnnotations: [FreezeAnnotation],
    autoTestsAnnotations: [AutoTestsAnnotation]
) {
    var allFreeze: [FreezeAnnotation] = []
    var allAutoTests: [AutoTestsAnnotation] = []

    for sourcePath in sourcePaths {
        let files = try findSwiftFiles(at: sourcePath)

        for file in files {
            let source = try String(contentsOfFile: file, encoding: .utf8)
            let tree = Parser.parse(source: source)

            let visitor = MacroDiscoveryVisitor(viewMode: .sourceAccurate)
            visitor.currentFile = file
            visitor.walk(tree)

            allFreeze.append(contentsOf: visitor.freezeAnnotations)
            allAutoTests.append(contentsOf: visitor.autoTestsAnnotations)
        }
    }

    return (allFreeze, allAutoTests)
}

/// Recursively finds all .swift files in a directory
func findSwiftFiles(at path: String) throws -> [String] {
    let fileManager = FileManager.default
    var swiftFiles: [String] = []

    // Check if path is a file or directory
    var isDirectory: ObjCBool = false
    guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else {
        throw MacroDiscoveryError.pathNotFound(path)
    }

    if isDirectory.boolValue {
        // Recursively scan directory
        let enumerator = fileManager.enumerator(atPath: path)
        while let file = enumerator?.nextObject() as? String {
            if file.hasSuffix(".swift") {
                let fullPath = (path as NSString).appendingPathComponent(file)
                swiftFiles.append(fullPath)
            }
        }
    } else if path.hasSuffix(".swift") {
        // Single file
        swiftFiles.append(path)
    }

    return swiftFiles
}

// MARK: - Errors

enum MacroDiscoveryError: Error, CustomStringConvertible {
    case pathNotFound(String)
    case noSchemasFound
    case noMigrationPlanFound

    var description: String {
        switch self {
        case .pathNotFound(let path):
            return "Path not found: \(path)"
        case .noSchemasFound:
            return "No @Freeze annotations found in source files"
        case .noMigrationPlanFound:
            return "No @AutoTests annotations found in source files"
        }
    }
}
