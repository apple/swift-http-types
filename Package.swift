// swift-tools-version:6.1

import PackageDescription

let package = Package(
    name: "swift-http-types",
    products: [
        .library(name: "HTTPTypes", targets: ["HTTPTypes"]),
        .library(name: "HTTPTypesFoundation", targets: ["HTTPTypesFoundation"]),
    ],
    traits: [
        .trait(name: "FoundationURL", description: "Enable HTTPRequest conveniences with Foundation URL"),
        .default(enabledTraits: ["FoundationURL"]),
    ],
    targets: [
        .target(name: "HTTPTypes"),
        .target(
            name: "HTTPTypesFoundation",
            dependencies: [
                "HTTPTypes"
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
                "HTTPTypesFoundation"
            ]
        ),
    ]
)

let availabilityMacros: KeyValuePairs<String, String> = [
    "HTTPTypes 1.0": "macOS 10.0",
    "HTTPTypes 1.1": "macOS 10.0",
    "HTTPTypes 1.2": "macOS 10.0",
    "HTTPTypes 1.3": "macOS 10.0",
    "HTTPTypes 1.6": "macOS 10.0",
]

for target in package.targets {
    var settings = target.swiftSettings ?? []
    settings.append(.enableUpcomingFeature("InternalImportsByDefault"))
    settings += availabilityMacros.map { name, value in
        .enableExperimentalFeature("AvailabilityMacro=\(name): \(value)")
    }
    target.swiftSettings = settings
}

// ---    STANDARD CROSS-REPO SETTINGS DO NOT EDIT   --- //
for target in package.targets {
    switch target.type {
    case .regular, .test, .executable:
        var settings = target.swiftSettings ?? []
        // https://github.com/swiftlang/swift-evolution/blob/main/proposals/0444-member-import-visibility.md
        settings.append(.enableUpcomingFeature("MemberImportVisibility"))
        target.swiftSettings = settings
    case .macro, .plugin, .system, .binary:
        ()  // not applicable
    @unknown default:
        ()  // we don't know what to do here, do nothing
    }
}
// --- END: STANDARD CROSS-REPO SETTINGS DO NOT EDIT --- //
