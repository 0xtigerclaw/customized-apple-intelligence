// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "RightClickWriter",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "RightClickWriter", targets: ["RightClickWriter"]),
        .executable(name: "RewriteClipboardLauncher", targets: ["RewriteClipboardLauncher"])
    ],
    targets: [
        .executableTarget(
            name: "RightClickWriter",
            path: "Sources/RightClickWriter",
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "RewriteClipboardLauncher",
            path: "Sources/RewriteClipboardLauncher"
        ),
        .testTarget(
            name: "RightClickWriterTests",
            dependencies: ["RightClickWriter"],
            path: "Tests/RightClickWriterTests"
        )
    ]
)
