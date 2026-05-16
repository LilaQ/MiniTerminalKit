// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MiniTerminalKit",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "MiniTerminalKit",
            targets: ["MiniTerminalKit"]
        )
    ],
    targets: [
        .target(
            name: "MiniTerminalKit"
        ),
        .testTarget(
            name: "MiniTerminalKitTests",
            dependencies: ["MiniTerminalKit"]
        )
    ]
)
