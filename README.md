# Swift HTTP Types

Swift HTTP Types are version-independent HTTP currency types designed for both clients and servers. They provide a common set of representations for HTTP requests and responses, focusing on modern HTTP features.

## Getting Started

Add the following dependency clause to your Package.swift:

```swift
dependencies: [
    .package(url: "https://github.com/apple/swift-http-types.git", from: "1.0.0")
]
```

The `HTTPTypes` library exposes the core HTTP currency types, including `HTTPRequest`, `HTTPResponse`, and `HTTPFields`.

The `HTTPTypesFoundation` library provides conveniences for using new HTTP types with Foundation, including bidirectional convertors between the new types and Foundation URL types, and URLSession convenience methods with the new types.

The `NIOHTTPTypes`, `NIOHTTPTypesHTTP1`, and `NIOHTTPTypesHTTP2` libraries provide channel handlers for translating the version-specific NIO HTTP types with the new HTTP types. They can be found in [`swift-nio-extras`](https://github.com/apple/swift-nio-extras).

## Usage

#### Create a request

```swift
let request = HTTPRequest(method: .get, scheme: "https", authority: "www.example.com", path: "/")
```

#### Create a request from a Foundation URL

```swift
var request = HTTPRequest(method: .get, url: URL(string: "https://www.example.com/")!)
request.method = .post
request.path = "/upload"
```

#### Create a response

```swift
let response = HTTPResponse(status: .ok)
```

#### Access and modify header fields

```swift
extension HTTPField.Name {
    static let myCustomHeader = Self("My-Custom-Header")!
}

// Set
request.headerFields[.userAgent] = "MyApp/1.0"
request.headerFields[.myCustomHeader] = "custom-value"
request.headerFields[values: .acceptLanguage] = ["en-US", "zh-Hans-CN"]

// Get
request.headerFields[.userAgent] // "MyApp/1.0"
request.headerFields[.myCustomHeader] // "custom-value"
request.headerFields[.acceptLanguage] // "en-US, zh-Hans-CN"
request.headerFields[values: .acceptLanguage] // ["en-US", "zh-Hans-CN"]
```

#### Use with URLSession

```swift
var request = HTTPRequest(method: .post, url: URL(string: "https://www.example.com/upload")!)
request.headerFields[.userAgent] = "MyApp/1.0"
let (responseBody, response) = try await URLSession.shared.upload(for: request, from: requestBody)
guard response.status == .created else {
    // Handle error
}
```

#### Use with SwiftNIO

```swift
channel.configureHTTP2Pipeline(mode: .server) { channel in
    channel.pipeline.addHandlers([
        HTTP2FramePayloadToHTTPServerCodec(),
        ExampleChannelHandler()
    ])
}.map { _ in () }
```

```swift
final class ExampleChannelHandler: ChannelDuplexHandler {
    typealias InboundIn = HTTPTypeServerRequestPart
    typealias OutboundOut = HTTPTypeServerResponsePart

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        switch unwrapInboundIn(data) {
        case .head(let request):
            // Handle request headers
        case .body(let body):
            // Handle request body
        case .end(let trailers):
            // Handle complete request
            let response = HTTPResponse(status: .ok)
            context.write(wrapOutboundOut(.head(response)), promise: nil)
            context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
        }
    }
}
```

## Developing HTTP Types

For the most part, HTTP Types development is as straightforward as any other SwiftPM project. With that said, we do have a few processes that are worth understanding before you contribute. For details, please see `CONTRIBUTING.md` in this repository.

Please note that all work on HTTP Types is covered by the [Swift HTTP Types Code of Conduct](https://github.com/apple/swift-http-types/blob/main/CODE_OF_CONDUCT.md).
