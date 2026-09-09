// swift-tools-version:6.1

import PackageDescription

// Build the library products as dynamic libraries when
// SWIFT_HTTP_TYPES_DYNAMIC_LIBRARY is set in the environment. This is used by
// distributions that ship the modules as shared libraries in a common
// location; the default (automatic) linkage is unchanged.
let libraryType: Product.Library.LibraryType? =
    Context.environment["SWIFT_HTTP_TYPES_DYNAMIC_LIBRARY"] != nil ? .dynamic : nil

let package = Package(
    name: "swift-http-types",
    products: [
        .library(name: "HTTPTypes", type: libraryType, targets: ["HTTPTypes"]),
        .library(name: "HTTPTypesFoundation", type: libraryType, targets: ["HTTPTypesFoundation"]),
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
    "HTTPTypes 1.7": "macOS 10.0",
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
