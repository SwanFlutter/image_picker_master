// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "image_picker_master",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "image-picker-master", targets: ["image_picker_master"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "image_picker_master",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            resources: [
                // Privacy manifest describing camera, photo library, and file access usage
                .process("PrivacyInfo.xcprivacy"),
            ]
        )
    ]
)
