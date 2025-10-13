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
        .library(
            name: "FreezeRayCLI",
            targets: ["freezeray-cli"]
        ),
        .executable(
            name: "freezeray",
            targets: ["freezeray-tool"]
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

        // CLI library (testable)
        .target(
            name: "freezeray-cli",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),

        // CLI executable (thin wrapper)
        .executableTarget(
            name: "freezeray-tool",
            dependencies: ["freezeray-cli"],
            path: "Sources/freezeray-bin"
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

        // CLI Tests
        .testTarget(
            name: "FreezeRayCLITests",
            dependencies: [
                "freezeray-cli",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
    ]
)
