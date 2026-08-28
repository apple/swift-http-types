# ``HTTPTypes``

A set of version-independent HTTP currency types.

## Overview

`HTTPRequest` represents an HTTP request message, including its method, scheme, authority, path, and header fields.

`HTTPResponse` represents an HTTP response message, including its status and header fields.

`HTTPFields` represents a list of HTTP header or trailer fields.

`HTTP2ErrorCode` and `HTTP3ErrorCode` represent the version-specific error codes used to terminate HTTP/2 and HTTP/3 streams and connections.

## Getting Started

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
