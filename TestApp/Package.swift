// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TestApp",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "TestApp", targets: ["TestApp"]),
    ],
    dependencies: [
        .package(path: ".."),  // FreezeRay package
    ],
    targets: [
        .target(
            name: "TestApp",
            dependencies: [
                .product(name: "FreezeRay", package: "FreezeRay"),
            ]
        ),
        .testTarget(
            name: "TestAppTests",
            dependencies: [
                "TestApp",
                .product(name: "FreezeRay", package: "FreezeRay"),
            ]
        ),
    ]
)
