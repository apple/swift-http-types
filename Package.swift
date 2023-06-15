// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "http-types",
    products: [
        .library(name: "HTTPTypes", targets: ["HTTPTypes"]),
        .library(name: "HTTPTypesFoundation", targets: ["HTTPTypesFoundation"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.3.0"),
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
            ]
        ),
        .testTarget(
            name: "HTTPTypesFoundationTests",
            dependencies: [
                "HTTPTypesFoundation",
            ]
        ),
    ]
)
