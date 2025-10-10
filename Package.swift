// swift-tools-version: 6.0
import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "FreezeRay",
    platforms: [.macOS(.v13), .iOS(.v17)],
    products: [
        .library(
            name: "FreezeRay",
            targets: ["FreezeRay"]
        ),
        .executable(
            name: "freezeray",
            targets: ["freezeray-cli"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", from: "600.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
    ],
    targets: [
        // Macro implementation
        .macro(
            name: "FreezeRayMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),

        // Public API and runtime support
        .target(
            name: "FreezeRay",
            dependencies: ["FreezeRayMacros"]
        ),

        // CLI tool
        .executableTarget(
            name: "freezeray-cli",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ],
            path: "Sources/freezeray-cli"
        ),

        // Tests
        .testTarget(
            name: "FreezeRayTests",
            dependencies: [
                "FreezeRay",
                "FreezeRayMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
    ]
)
