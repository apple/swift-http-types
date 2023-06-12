# Swift HTTP Types

Swift HTTP Types are version-independent HTTP currency types designed for both clients and servers. They provide a common set of representations for HTTP requests and responses, focusing on modern HTTP features.

## Getting Started

Add the following dependency clause to your Package.swift:

```
dependencies: [
    .package(url: "https://github.com/apple/swift-http-types.git", from: "0.1.0")
]
```

The `HTTPTypes` library exposes the core HTTP currency types, including `HTTPRequest`, `HTTPResponse`, and `HTTPFields`.

The `HTTPTypesFoundation` library provides conveniences for using new HTTP types with Foundation, including bidirectional convertors between the new types and Foundation URL types, and URLSession convenience methods with the new types.

The `HTTPTypesNIO`, `HTTPTypesNIOHTTP1`, and `HTTPTypesNIOHTTP2` libraries provide channel handlers for translating the version-specific NIO HTTP types with the new HTTP types. They can be found in [`swift-nio-extras`](https://github.com/apple/swift-nio-extras).

## Developing HTTP Types

For the most part, HTTP Types development is as straightforward as any other SwiftPM project. With that said, we do have a few processes that are worth understanding before you contribute. For details, please see `CONTRIBUTING.md` in this repository.

Please note that all work on HTTP Types is covered by the [Swift HTTP Types Code of Conduct](https://github.com/apple/swift-http-types/blob/main/CODE_OF_CONDUCT.md).
