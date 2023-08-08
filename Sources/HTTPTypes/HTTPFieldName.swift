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

        private init(rawName: String, canonicalName: String) {
            self.rawName = rawName
            self.canonicalName = canonicalName
        }

        var isPseudo: Bool {
            self.rawName.hasPrefix(":")
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
        if nameString.hasPrefix(":") {
            guard nameString.lowercased() == nameString,
                  HTTPField.isValidToken(nameString.dropFirst()) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "HTTP pseudo field name \"\(nameString)\" contains invalid characters")
            }
            self.init(rawName: nameString, canonicalName: nameString)
        } else {
            guard let name = Self(nameString) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "HTTP field name \"\(nameString)\" contains invalid characters")
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
    public static var accept: Self { .init(rawName: "Accept", canonicalName: "accept") }
    /// Accept-Encoding
    public static var acceptEncoding: Self { .init(rawName: "Accept-Encoding", canonicalName: "accept-encoding") }
    /// Accept-Language
    public static var acceptLanguage: Self { .init(rawName: "Accept-Language", canonicalName: "accept-language") }
    /// Accept-Ranges
    public static var acceptRanges: Self { .init(rawName: "Accept-Ranges", canonicalName: "accept-ranges") }
    /// Access-Control-Allow-Credentials
    public static var accessControlAllowCredentials: Self { .init(rawName: "Access-Control-Allow-Credentials", canonicalName: "access-control-allow-credentials") }
    /// Access-Control-Allow-Headers
    public static var accessControlAllowHeaders: Self { .init(rawName: "Access-Control-Allow-Headers", canonicalName: "access-control-allow-headers") }
    /// Access-Control-Allow-Methods
    public static var accessControlAllowMethods: Self { .init(rawName: "Access-Control-Allow-Methods", canonicalName: "access-control-allow-methods") }
    /// Access-Control-Allow-Origin
    public static var accessControlAllowOrigin: Self { .init(rawName: "Access-Control-Allow-Origin", canonicalName: "access-control-allow-origin") }
    /// Access-Control-Expose-Headers
    public static var accessControlExposeHeaders: Self { .init(rawName: "Access-Control-Expose-Headers", canonicalName: "access-control-expose-headers") }
    /// Access-Control-Max-Age
    public static var accessControlMaxAge: Self { .init(rawName: "Access-Control-Max-Age", canonicalName: "access-control-max-age") }
    /// Access-Control-Request-Headers
    public static var accessControlRequestHeaders: Self { .init(rawName: "Access-Control-Request-Headers", canonicalName: "access-control-request-headers") }
    /// Access-Control-Request-Method
    public static var accessControlRequestMethod: Self { .init(rawName: "Access-Control-Request-Method", canonicalName: "access-control-request-method") }
    /// Age
    public static var age: Self { .init(rawName: "Age", canonicalName: "age") }
    /// Alt-Svc
    public static var altSvc: Self { .init(rawName: "Alt-Svc", canonicalName: "alt-svc") }
    /// Authentication-Info
    public static var authenticationInfo: Self { .init(rawName: "Authentication-Info", canonicalName: "authentication-info") }
    /// Authorization
    public static var authorization: Self { .init(rawName: "Authorization", canonicalName: "authorization") }
    /// Cache-Control
    public static var cacheControl: Self { .init(rawName: "Cache-Control", canonicalName: "cache-control") }
    /// Connection
    public static var connection: Self { .init(rawName: "Connection", canonicalName: "connection") }
    /// Content-Disposition
    public static var contentDisposition: Self { .init(rawName: "Content-Disposition", canonicalName: "content-disposition") }
    /// Content-Encoding
    public static var contentEncoding: Self { .init(rawName: "Content-Encoding", canonicalName: "content-encoding") }
    /// Content-Length
    public static var contentLength: Self { .init(rawName: "Content-Length", canonicalName: "content-length") }
    /// Content-Security-Policy
    public static var contentSecurityPolicy: Self { .init(rawName: "Content-Security-Policy", canonicalName: "content-security-policy") }
    /// Content-Type
    public static var contentType: Self { .init(rawName: "Content-Type", canonicalName: "content-type") }
    /// Cookie
    public static var cookie: Self { .init(rawName: "Cookie", canonicalName: "cookie") }
    /// Date
    public static var date: Self { .init(rawName: "Date", canonicalName: "date") }
    /// Early-Data
    public static var earlyData: Self { .init(rawName: "Early-Data", canonicalName: "early-data") }
    /// ETag
    public static var eTag: Self { .init(rawName: "ETag", canonicalName: "etag") }
    /// Expect
    public static var expect: Self { .init(rawName: "Expect", canonicalName: "expect") }
    /// Expires
    public static var expires: Self { .init(rawName: "Expires", canonicalName: "expires") }
    @available(*, unavailable, message: "Please use HTTPRequest.authority instead")
    /// Host
    public static var host: Self { .init(rawName: "Host", canonicalName: "host") }
    /// If-Modified-Since
    public static var ifModifiedSince: Self { .init(rawName: "If-Modified-Since", canonicalName: "if-modified-since") }
    /// If-None-Match
    public static var ifNoneMatch: Self { .init(rawName: "If-None-Match", canonicalName: "if-none-match") }
    /// If-Range
    public static var ifRange: Self { .init(rawName: "If-Range", canonicalName: "if-range") }
    /// Keep-Alive
    public static var keepAlive: Self { .init(rawName: "Keep-Alive", canonicalName: "keep-alive") }
    /// Last-Modified
    public static var lastModified: Self { .init(rawName: "Last-Modified", canonicalName: "last-modified") }
    /// Location
    public static var location: Self { .init(rawName: "Location", canonicalName: "location") }
    /// Origin
    public static var origin: Self { .init(rawName: "Origin", canonicalName: "origin") }
    /// Priority
    public static var priority: Self { .init(rawName: "Priority", canonicalName: "priority") }
    /// Proxy-Authenticate
    public static var proxyAuthenticate: Self { .init(rawName: "Proxy-Authenticate", canonicalName: "proxy-authenticate") }
    /// Proxy-Authentication-Info
    public static var proxyAuthenticationInfo: Self { .init(rawName: "Proxy-Authentication-Info", canonicalName: "proxy-authentication-info") }
    /// Proxy-Authorization
    public static var proxyAuthorization: Self { .init(rawName: "Proxy-Authorization", canonicalName: "proxy-authorization") }
    /// Proxy-Connection
    public static var proxyConnection: Self { .init(rawName: "Proxy-Connection", canonicalName: "proxy-connection") }
    /// Range
    public static var range: Self { .init(rawName: "Range", canonicalName: "range") }
    /// Referer
    public static var referer: Self { .init(rawName: "Referer", canonicalName: "referer") }
    /// Sec-WebSocket-Accept
    public static var secWebSocketAccept: Self { .init(rawName: "Sec-WebSocket-Accept", canonicalName: "sec-websocket-accept") }
    /// Sec-WebSocket-Extensions
    public static var secWebSocketExtensions: Self { .init(rawName: "Sec-WebSocket-Extensions", canonicalName: "sec-websocket-extensions") }
    /// Sec-WebSocket-Key
    public static var secWebSocketKey: Self { .init(rawName: "Sec-WebSocket-Key", canonicalName: "sec-websocket-key") }
    /// Sec-WebSocket-Protocol
    public static var secWebSocketProtocol: Self { .init(rawName: "Sec-WebSocket-Protocol", canonicalName: "sec-websocket-protocol") }
    /// Sec-WebSocket-Version
    public static var secWebSocketVersion: Self { .init(rawName: "Sec-WebSocket-Version", canonicalName: "sec-websocket-version") }
    /// Server
    public static var server: Self { .init(rawName: "Server", canonicalName: "server") }
    /// Set-Cookie
    public static var setCookie: Self { .init(rawName: "Set-Cookie", canonicalName: "set-cookie") }
    /// Strict-Transport-Security
    public static var strictTransportSecurity: Self { .init(rawName: "Strict-Transport-Security", canonicalName: "strict-transport-security") }
    /// Trailer
    public static var trailer: Self { .init(rawName: "Trailer", canonicalName: "trailer") }
    /// Transfer-Encoding
    public static var transferEncoding: Self { .init(rawName: "Transfer-Encoding", canonicalName: "transfer-encoding") }
    /// Upgrade
    public static var upgrade: Self { .init(rawName: "Upgrade", canonicalName: "upgrade") }
    /// Upgrade-Insecure-Requests
    public static var upgradeInsecureRequests: Self { .init(rawName: "Upgrade-Insecure-Requests", canonicalName: "upgrade-insecure-requests") }
    /// User-Agent
    public static var userAgent: Self { .init(rawName: "User-Agent", canonicalName: "user-agent") }
    /// Vary
    public static var vary: Self { .init(rawName: "Vary", canonicalName: "vary") }
    /// Via
    public static var via: Self { .init(rawName: "Via", canonicalName: "via") }
    /// WWW-Authenticate
    public static var wwwAuthenticate: Self { .init(rawName: "WWW-Authenticate", canonicalName: "www-authenticate") }
    /// X-Content-Type-Options
    public static var xContentTypeOptions: Self { .init(rawName: "X-Content-Type-Options", canonicalName: "x-content-type-options") }
    // Deprecated
    /// P3P
    static var p3P: Self { .init(rawName: "P3P", canonicalName: "p3p") }
    /// Pragma
    static var pragma: Self { .init(rawName: "Pragma", canonicalName: "pragma") }
    /// Timing-Allow-Origin
    static var timingAllowOrigin: Self { .init(rawName: "Timing-Allow-Origin", canonicalName: "timing-allow-origin") }
    /// X-Frame-Options
    static var xFrameOptions: Self { .init(rawName: "X-Frame-Options", canonicalName: "x-frame-options") }
    /// X-XSS-Protection
    static var xXSSProtection: Self { .init(rawName: "X-XSS-Protection", canonicalName: "x-xss-protection") }
    // Internal
    /// Datagram-Flow-Id
    static var datagramFlowId: Self { .init(rawName: "Datagram-Flow-Id", canonicalName: "datagram-flow-id") }
    /// Capsule-Protocol
    static var capsuleProtocol: Self { .init(rawName: "Capsule-Protocol", canonicalName: "capsule-protocol") }
    /// Server-Connection-Id
    static var serverConnectionId: Self { .init(rawName: "Server-Connection-Id", canonicalName: "server-connection-id") }
    /// Client-Connection-Id
    static var clientConnectionId: Self { .init(rawName: "Client-Connection-Id", canonicalName: "client-connection-id") }
    /// Sec-CH-Background
    static var secCHBackground: Self { .init(rawName: "Sec-CH-Background", canonicalName: "sec-ch-background") }
    /// Sec-CH-Geohash
    static var secCHGeohash: Self { .init(rawName: "Sec-CH-Geohash", canonicalName: "sec-ch-geohash") }
    /// Client-Geohash
    static var clientGeohash: Self { .init(rawName: "Client-Geohash", canonicalName: "client-geohash") }
    /// Proxy-Status
    static var proxyStatus: Self { .init(rawName: "Proxy-Status", canonicalName: "proxy-status") }
    /// Proxy-QUIC-Forwarding
    static var proxyQUICForwarding: Self { .init(rawName: "Proxy-QUIC-Forwarding", canonicalName: "proxy-quic-forwarding") }
    /// Proxy-Config-Epoch
    static var proxyConfigEpoch: Self { .init(rawName: "Proxy-Config-Epoch", canonicalName: "proxy-config-epoch") }
}
