//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

extension HTTPField {
    /// A case-insensitive but case-preserving ASCII string with an allowed character set defined
    /// in RFC 9110.
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html#name-field-names
    ///
    /// Common HTTP field names are provided as convenience static properties, and for custom field
    /// names, it is recommended to extend the `HTTPField.Name` struct with new static members.
    ///
    /// ```
    /// extension HTTPField.Name {
    ///     static let example = Self("X-Example")!
    /// }
    /// ```
    public struct Name: Sendable {
        /// The original name of the HTTP field received or supplied to the initializer.
        public let rawName: String

        /// The lowercased canonical name of the HTTP field used for hashing and comparison.
        public let canonicalName: String

        /// Create an HTTP field name from a string. Returns nil if the name contains invalid
        /// characters defined in RFC 9110.
        ///
        /// https://www.rfc-editor.org/rfc/rfc9110.html#name-field-names
        ///
        /// - Parameter name: The name of the HTTP field. It can be accessed from the `rawName`
        ///                   property.
        public init?(_ name: String) {
            guard HTTPField.isValidToken(name) else {
                return nil
            }
            self.rawName = name
            self.canonicalName = name.lowercased()
        }

        /// Create an HTTP field name from a string produced by HPACK or QPACK decoders used in
        /// modern HTTP versions.
        ///
        /// - Warning: Do not use directly with the `HTTPFields` struct which does not allow pseudo
        ///            header fields.
        ///
        /// - Parameter name: The name of the HTTP field or the HTTP pseudo header field. It must
        ///                   be lowercased.
        public init?(parsed name: String) {
            guard !name.isEmpty else {
                return nil
            }
            let token: Substring
            if name.utf8.first == UInt8(ascii: ":") {
                token = name.dropFirst()
            } else {
                token = Substring(name)
            }
            guard
                token.utf8.allSatisfy({
                    switch $0 {
                    case 0x21, 0x23, 0x24, 0x25, 0x26, 0x27, 0x2A, 0x2B, 0x2D, 0x2E, 0x5E, 0x5F, 0x60, 0x7C, 0x7E:
                        return true
                    case 0x30...0x39, 0x61...0x7A:  // DIGHT, ALPHA
                        return true
                    default:
                        return false
                    }
                })
            else {
                return nil
            }
            self.rawName = name
            self.canonicalName = name
        }

        private init(rawName: String, canonicalName: String) {
            self.rawName = rawName
            self.canonicalName = canonicalName
        }

        var isPseudo: Bool {
            self.rawName.utf8.first == UInt8(ascii: ":")
        }
    }
}

extension HTTPField.Name: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.canonicalName)
    }

    public static func == (lhs: HTTPField.Name, rhs: HTTPField.Name) -> Bool {
        lhs.canonicalName == rhs.canonicalName
    }
}

extension HTTPField.Name: LosslessStringConvertible {
    public var description: String {
        self.rawName
    }
}

extension HTTPField.Name: CustomPlaygroundDisplayConvertible {
    public var playgroundDescription: Any {
        self.description
    }
}

extension HTTPField.Name: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawName)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let nameString = try container.decode(String.self)
        if nameString.utf8.first == UInt8(ascii: ":") {
            guard nameString.lowercased() == nameString,
                HTTPField.isValidToken(nameString.dropFirst())
            else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "HTTP pseudo field name \"\(nameString)\" contains invalid characters"
                )
            }
            self.init(rawName: nameString, canonicalName: nameString)
        } else {
            guard let name = Self(nameString) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "HTTP field name \"\(nameString)\" contains invalid characters"
                )
            }
            self = name
        }
    }
}

extension HTTPField.Name {
    static var method: Self { .init(rawName: ":method", canonicalName: ":method") }
    static var scheme: Self { .init(rawName: ":scheme", canonicalName: ":scheme") }
    static var authority: Self { .init(rawName: ":authority", canonicalName: ":authority") }
    static var path: Self { .init(rawName: ":path", canonicalName: ":path") }
    static var `protocol`: Self { .init(rawName: ":protocol", canonicalName: ":protocol") }
    static var status: Self { .init(rawName: ":status", canonicalName: ":status") }

    /// Accept
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var accept: Self { .init(rawName: "Accept", canonicalName: "accept") }

    /// Accept-Encoding
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var acceptEncoding: Self { .init(rawName: "Accept-Encoding", canonicalName: "accept-encoding") }

    /// Accept-Language
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var acceptLanguage: Self { .init(rawName: "Accept-Language", canonicalName: "accept-language") }

    /// Accept-Ranges
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var acceptRanges: Self { .init(rawName: "Accept-Ranges", canonicalName: "accept-ranges") }

    /// Access-Control-Allow-Credentials
    ///
    /// https://fetch.spec.whatwg.org/
    public static var accessControlAllowCredentials: Self {
        .init(rawName: "Access-Control-Allow-Credentials", canonicalName: "access-control-allow-credentials")
    }

    /// Access-Control-Allow-Headers
    ///
    /// https://fetch.spec.whatwg.org/
    public static var accessControlAllowHeaders: Self {
        .init(rawName: "Access-Control-Allow-Headers", canonicalName: "access-control-allow-headers")
    }

    /// Access-Control-Allow-Methods
    ///
    /// https://fetch.spec.whatwg.org/
    public static var accessControlAllowMethods: Self {
        .init(rawName: "Access-Control-Allow-Methods", canonicalName: "access-control-allow-methods")
    }

    /// Access-Control-Allow-Origin
    ///
    /// https://fetch.spec.whatwg.org/
    public static var accessControlAllowOrigin: Self {
        .init(rawName: "Access-Control-Allow-Origin", canonicalName: "access-control-allow-origin")
    }

    /// Access-Control-Expose-Headers
    ///
    /// https://fetch.spec.whatwg.org/
    public static var accessControlExposeHeaders: Self {
        .init(rawName: "Access-Control-Expose-Headers", canonicalName: "access-control-expose-headers")
    }

    /// Access-Control-Max-Age
    ///
    /// https://fetch.spec.whatwg.org/
    public static var accessControlMaxAge: Self {
        .init(rawName: "Access-Control-Max-Age", canonicalName: "access-control-max-age")
    }

    /// Access-Control-Request-Headers
    ///
    /// https://fetch.spec.whatwg.org/
    public static var accessControlRequestHeaders: Self {
        .init(rawName: "Access-Control-Request-Headers", canonicalName: "access-control-request-headers")
    }

    /// Access-Control-Request-Method
    ///
    /// https://fetch.spec.whatwg.org/
    public static var accessControlRequestMethod: Self {
        .init(rawName: "Access-Control-Request-Method", canonicalName: "access-control-request-method")
    }

    /// Age
    ///
    /// https://www.rfc-editor.org/rfc/rfc9111.html
    public static var age: Self { .init(rawName: "Age", canonicalName: "age") }

    /// Allow
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var allow: Self { .init(rawName: "Allow", canonicalName: "allow") }

    /// Authentication-Info
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var authenticationInfo: Self {
        .init(rawName: "Authentication-Info", canonicalName: "authentication-info")
    }

    /// Authorization
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var authorization: Self { .init(rawName: "Authorization", canonicalName: "authorization") }

    /// Cache-Control
    ///
    /// https://www.rfc-editor.org/rfc/rfc9111.html
    public static var cacheControl: Self { .init(rawName: "Cache-Control", canonicalName: "cache-control") }

    /// Connection
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var connection: Self { .init(rawName: "Connection", canonicalName: "connection") }

    /// Content-Disposition
    ///
    /// https://www.rfc-editor.org/rfc/rfc6266.html
    public static var contentDisposition: Self {
        .init(rawName: "Content-Disposition", canonicalName: "content-disposition")
    }

    /// Content-Encoding
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var contentEncoding: Self { .init(rawName: "Content-Encoding", canonicalName: "content-encoding") }

    /// Content-Language
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var contentLanguage: Self { .init(rawName: "Content-Language", canonicalName: "content-language") }

    /// Content-Length
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var contentLength: Self { .init(rawName: "Content-Length", canonicalName: "content-length") }

    /// Content-Location
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var contentLocation: Self { .init(rawName: "Content-Location", canonicalName: "content-location") }

    /// Content-Range
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var contentRange: Self { .init(rawName: "Content-Range", canonicalName: "content-range") }

    /// Content-Security-Policy
    ///
    /// https://www.w3.org/TR/CSP/
    public static var contentSecurityPolicy: Self {
        .init(rawName: "Content-Security-Policy", canonicalName: "content-security-policy")
    }

    /// Content-Security-Policy-Report-Only
    ///
    /// https://www.w3.org/TR/CSP/
    public static var contentSecurityPolicyReportOnly: Self {
        .init(rawName: "Content-Security-Policy-Report-Only", canonicalName: "content-security-policy-report-only")
    }

    /// Content-Type
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var contentType: Self { .init(rawName: "Content-Type", canonicalName: "content-type") }

    /// Cookie
    ///
    /// https://www.rfc-editor.org/rfc/rfc6265.html
    public static var cookie: Self { .init(rawName: "Cookie", canonicalName: "cookie") }

    /// Cross-Origin-Resource-Policy
    ///
    /// https://fetch.spec.whatwg.org/
    public static var crossOriginResourcePolicy: Self {
        .init(rawName: "Cross-Origin-Resource-Policy", canonicalName: "cross-origin-resource-policy")
    }

    /// Date
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var date: Self { .init(rawName: "Date", canonicalName: "date") }

    /// Early-Data
    ///
    /// https://www.rfc-editor.org/rfc/rfc8470.html
    public static var earlyData: Self { .init(rawName: "Early-Data", canonicalName: "early-data") }

    /// ETag
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var eTag: Self { .init(rawName: "ETag", canonicalName: "etag") }

    /// Expect
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var expect: Self { .init(rawName: "Expect", canonicalName: "expect") }

    /// Expires
    ///
    /// https://www.rfc-editor.org/rfc/rfc9111.html
    public static var expires: Self { .init(rawName: "Expires", canonicalName: "expires") }

    /// From
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var from: Self { .init(rawName: "From", canonicalName: "from") }

    /// Host
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    @available(*, unavailable, message: "Use HTTPRequest.authority instead")
    public static var host: Self { .init(rawName: "Host", canonicalName: "host") }

    /// If-Match
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var ifMatch: Self { .init(rawName: "If-Match", canonicalName: "if-match") }

    /// If-Modified-Since
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var ifModifiedSince: Self { .init(rawName: "If-Modified-Since", canonicalName: "if-modified-since") }

    /// If-None-Match
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var ifNoneMatch: Self { .init(rawName: "If-None-Match", canonicalName: "if-none-match") }

    /// If-Range
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var ifRange: Self { .init(rawName: "If-Range", canonicalName: "if-range") }

    /// If-Unmodified-Since
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var ifUnmodifiedSince: Self {
        .init(rawName: "If-Unmodified-Since", canonicalName: "if-unmodified-since")
    }

    /// Last-Modified
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var lastModified: Self { .init(rawName: "Last-Modified", canonicalName: "last-modified") }

    /// Location
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var location: Self { .init(rawName: "Location", canonicalName: "location") }

    /// Max-Forwards
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var maxForwards: Self { .init(rawName: "Max-Forwards", canonicalName: "max-forwards") }

    /// Origin
    ///
    /// https://www.rfc-editor.org/rfc/rfc6454.html
    public static var origin: Self { .init(rawName: "Origin", canonicalName: "origin") }

    /// Priority
    ///
    /// https://www.rfc-editor.org/rfc/rfc9218.html
    public static var priority: Self { .init(rawName: "Priority", canonicalName: "priority") }

    /// Proxy-Authenticate
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var proxyAuthenticate: Self {
        .init(rawName: "Proxy-Authenticate", canonicalName: "proxy-authenticate")
    }

    /// Proxy-Authentication-Info
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var proxyAuthenticationInfo: Self {
        .init(rawName: "Proxy-Authentication-Info", canonicalName: "proxy-authentication-info")
    }

    /// Proxy-Authorization
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var proxyAuthorization: Self {
        .init(rawName: "Proxy-Authorization", canonicalName: "proxy-authorization")
    }

    /// Proxy-Status
    ///
    /// https://www.rfc-editor.org/rfc/rfc9209.html
    public static var proxyStatus: Self { .init(rawName: "Proxy-Status", canonicalName: "proxy-status") }

    /// Range
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var range: Self { .init(rawName: "Range", canonicalName: "range") }

    /// Referer
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var referer: Self { .init(rawName: "Referer", canonicalName: "referer") }

    /// Retry-After
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var retryAfter: Self { .init(rawName: "Retry-After", canonicalName: "retry-after") }

    /// Sec-Purpose
    ///
    /// https://fetch.spec.whatwg.org/
    public static var secPurpose: Self { .init(rawName: "Sec-Purpose", canonicalName: "sec-purpose") }

    /// Sec-WebSocket-Accept
    ///
    /// https://www.rfc-editor.org/rfc/rfc6455.html
    public static var secWebSocketAccept: Self {
        .init(rawName: "Sec-WebSocket-Accept", canonicalName: "sec-websocket-accept")
    }

    /// Sec-WebSocket-Extensions
    ///
    /// https://www.rfc-editor.org/rfc/rfc6455.html
    public static var secWebSocketExtensions: Self {
        .init(rawName: "Sec-WebSocket-Extensions", canonicalName: "sec-websocket-extensions")
    }

    /// Sec-WebSocket-Key
    ///
    /// https://www.rfc-editor.org/rfc/rfc6455.html
    public static var secWebSocketKey: Self { .init(rawName: "Sec-WebSocket-Key", canonicalName: "sec-websocket-key") }

    /// Sec-WebSocket-Protocol
    ///
    /// https://www.rfc-editor.org/rfc/rfc6455.html
    public static var secWebSocketProtocol: Self {
        .init(rawName: "Sec-WebSocket-Protocol", canonicalName: "sec-websocket-protocol")
    }

    /// Sec-WebSocket-Version
    ///
    /// https://www.rfc-editor.org/rfc/rfc6455.html
    public static var secWebSocketVersion: Self {
        .init(rawName: "Sec-WebSocket-Version", canonicalName: "sec-websocket-version")
    }

    /// Server
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var server: Self { .init(rawName: "Server", canonicalName: "server") }

    /// Set-Cookie
    ///
    /// https://www.rfc-editor.org/rfc/rfc6265.html
    public static var setCookie: Self { .init(rawName: "Set-Cookie", canonicalName: "set-cookie") }

    /// Strict-Transport-Security
    ///
    /// https://www.rfc-editor.org/rfc/rfc6797.html
    public static var strictTransportSecurity: Self {
        .init(rawName: "Strict-Transport-Security", canonicalName: "strict-transport-security")
    }

    /// TE
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var te: Self { .init(rawName: "TE", canonicalName: "te") }

    /// Trailer
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var trailer: Self { .init(rawName: "Trailer", canonicalName: "trailer") }

    /// Transfer-Encoding
    ///
    /// https://www.rfc-editor.org/rfc/rfc9112.html
    public static var transferEncoding: Self { .init(rawName: "Transfer-Encoding", canonicalName: "transfer-encoding") }

    /// Upgrade
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var upgrade: Self { .init(rawName: "Upgrade", canonicalName: "upgrade") }

    /// User-Agent
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var userAgent: Self { .init(rawName: "User-Agent", canonicalName: "user-agent") }

    /// Vary
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var vary: Self { .init(rawName: "Vary", canonicalName: "vary") }

    /// Via
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var via: Self { .init(rawName: "Via", canonicalName: "via") }

    /// WWW-Authenticate
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var wwwAuthenticate: Self { .init(rawName: "WWW-Authenticate", canonicalName: "www-authenticate") }

    /// X-Content-Type-Options
    ///
    /// https://fetch.spec.whatwg.org/
    public static var xContentTypeOptions: Self {
        .init(rawName: "X-Content-Type-Options", canonicalName: "x-content-type-options")
    }
}
