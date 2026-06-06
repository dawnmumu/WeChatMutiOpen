// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MacMultiOpen",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "MultiOpenKit", targets: ["MultiOpenKit"]),
        .executable(name: "multiopen", targets: ["MultiOpenCLI"]),
        .executable(name: "MacMultiOpenApp", targets: ["MultiOpenApp"]),
        .executable(name: "MultiOpenTests", targets: ["MultiOpenTests"])
    ],
    targets: [
        .target(name: "MultiOpenKit"),
        .executableTarget(
            name: "MultiOpenCLI",
            dependencies: ["MultiOpenKit"]
        ),
        .executableTarget(
            name: "MultiOpenApp",
            dependencies: ["MultiOpenKit"]
        ),
        .executableTarget(
            name: "MultiOpenTests",
            dependencies: ["MultiOpenKit"]
        )
    ]
)
