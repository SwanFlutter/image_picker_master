// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "image_picker_master",
    platforms: [
        .macOS(.v10_14),
        .iOS(.v12)
    ],
    products: [
        .library(name: "image_picker_master", targets: ["image_picker_master"])
    ],
    dependencies: [
        .package(url: "https://github.com/flutter/flutter.git", branch: "stable")
    ],
    targets: [
        .target(
            name: "image_picker_master",
            dependencies: [],
            resources: [
                .process("Resources")
            ]
        )
    ]
)
