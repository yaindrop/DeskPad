// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "DeskPad",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .executable(name: "DeskPad", targets: ["DeskPad"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "DeskPad",
            dependencies: [],
            path: "DeskPad",
            exclude: [
                "DeskPad.entitlements",
                "Assets.xcassets",
                "DeskPad-Bridging-Header.h",
                "CGVirtualDisplayPrivate.h"
            ],
            swiftSettings: [
                .unsafeFlags([
                    "-import-objc-header", "DeskPad/DeskPad-Bridging-Header.h",
                    "-I", "DeskPad" 
                ])
            ]
        )
    ]
)
