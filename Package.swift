// swift-tools-version: 5.7.1

import PackageDescription

let package = Package(
    name: "swift-http-types",
    products: [
        .library(name: "HTTPTypes", targets: ["HTTPTypes"]),
        .library(name: "HTTPTypesFoundation", targets: ["HTTPTypesFoundation"]),
        .library(name: "HTTPTypesFoundationNetworking", targets: ["HTTPTypesFoundationNetworking"]),
    ],
    targets: [
        .target(name: "HTTPTypes"),
        .target(
            name: "HTTPTypesFoundation",
            dependencies: [
                "HTTPTypes"
            ]
        ),
        .target(
            name: "HTTPTypesFoundationNetworking",
            dependencies: [
                "HTTPTypes",
                "HTTPTypesFoundation"
            ]
        ),
        .testTarget(
            name: "HTTPTypesTests",
            dependencies: [
                "HTTPTypes"
            ]
        ),
        .testTarget(
            name: "HTTPTypesFoundationTests",
            dependencies: [
                "HTTPTypes",
                "HTTPTypesFoundation"
            ]
        ),
        .testTarget(
            name: "HTTPTypesFoundationNetworkingTests",
            dependencies: [
                "HTTPTypes",
                "HTTPTypesFoundationNetworking"
            ]
        ),
    ]
)
