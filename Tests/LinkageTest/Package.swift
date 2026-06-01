// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "linkage-test",
    dependencies: [
        .package(name: "swift-http-types", path: "../..", traits: [])
    ],
    targets: [
        .executableTarget(
            name: "linkageTest",
            dependencies: [
                .product(name: "HTTPTypes", package: "swift-http-types")
            ]
        )
    ]
)
