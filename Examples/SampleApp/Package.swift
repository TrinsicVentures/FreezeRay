// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SampleApp",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SampleApp", targets: ["SampleApp"]),
    ],
    dependencies: [
        .package(path: "../.."),  // FreezeRay package
    ],
    targets: [
        .target(
            name: "SampleApp",
            dependencies: []
        ),
        .testTarget(
            name: "SampleAppTests",
            dependencies: [
                "SampleApp",
                .product(name: "FreezeRay", package: "FreezeRay"),
            ]
        ),
    ]
)
