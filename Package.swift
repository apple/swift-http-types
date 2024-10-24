// swift-tools-version: 5.7.1

import PackageDescription

let package = Package(
    name: "swift-http-types",
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
        .target(
            name: "HTTPClient",
            dependencies: [
                .target(name: "HTTPTypes"),
            ]
        ),
        .target(
            name: "HTTPClientFoundation",
            dependencies: [
                .target(name: "HTTPClient"),
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
