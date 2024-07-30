// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "swift-http-types",
    platforms: [.macOS(.v10_15)],
    products: [
        .library(name: "HTTPTypes", targets: ["HTTPTypes"]),
        .library(name: "HTTPTypesFoundation", targets: ["HTTPTypesFoundation"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.3.0"),
        .package(url: "https://github.com/apple/swift-testing.git", from: "0.11.0"),
    ],
    targets: [
        .target(name: "HTTPTypes"),
        .target(
            name: "HTTPTypesFoundation",
            dependencies: [
                "HTTPTypes",
            ]
        ),
        .testTarget(
            name: "HTTPTypesTests",
            dependencies: [
                "HTTPTypes",
                .product(name: "Testing", package: "swift-testing"),
            ]
        ),
        .testTarget(
            name: "HTTPTypesFoundationTests",
            dependencies: [
                "HTTPTypesFoundation",
                .product(name: "Testing", package: "swift-testing"),
            ]
        ),
    ]
)
