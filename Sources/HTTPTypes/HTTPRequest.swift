//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift HTTP Types open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift HTTP Types project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift HTTP Types project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

/// HTTP request message consists of pseudo header fields and header fields.
///
/// Currently supported pseudo header fields are ":method", ":scheme", ":authority", ":path", and
/// ":protocol". Conveniences are provided to set these pseudo header fields through a URL and
/// strings.
///
/// In a legacy HTTP/1 context, the ":scheme" is ignored and the ":authority" is translated into
/// the "Host" header.
public struct HTTPRequest: Sendable, Hashable {
    /// HTTP request method
    public struct Method: Hashable, RawRepresentable, LosslessStringConvertible {
        /// The string value of the request.
        public let rawValue: String

        /// Create a request method from a string. Returns nil if the string contains invalid
        /// characters defined in RFC 9110.
        ///
        /// https://www.rfc-editor.org/rfc/rfc9110.html#name-overview
        ///
        /// - Parameter method: The method string. It can be accessed from the `rawValue` property.
        public init?(_ method: String) {
            guard HTTPField.isValidToken(method) else {
                return nil
            }
            rawValue = method
        }

        public init?(rawValue: String) {
            self.init(rawValue)
        }

        private init(unchecked: String) {
            rawValue = unchecked
        }

        public var description: String {
            rawValue
        }
    }

    /// The HTTP request method.
    public var method: Method {
        get {
            Method(methodField.rawValue._storage)!
        }
        set {
            methodField.rawValue = ISOLatin1String(unchecked: newValue.rawValue)
        }
    }

    /// The value of the ":scheme" pseudo header field.
    ///
    /// The scheme is ignored in a legacy HTTP/1 context.
    public var scheme: String? {
        get {
            schemeField?.value
        }
        set {
            if let newValue {
                if var field = schemeField {
                    field.value = newValue
                    schemeField = field
                } else {
                    var field = HTTPField(name: .scheme, value: newValue)
                    field.indexingStrategy = .prefer
                    schemeField = field
                }
            } else {
                schemeField = nil
            }
        }
    }

    /// The value of the ":authority" pseudo header field.
    ///
    /// The authority is translated into the "Host" header in a legacy HTTP/1 context.
    public var authority: String? {
        get {
            authorityField?.value
        }
        set {
            if let newValue {
                if var field = authorityField {
                    field.value = newValue
                    authorityField = field
                } else {
                    var field = HTTPField(name: .authority, value: newValue)
                    field.indexingStrategy = .prefer
                    authorityField = field
                }
            } else {
                authorityField = nil
            }
        }
    }

    /// The value of the ":path" pseudo header field.
    public var path: String? {
        get {
            pathField?.value
        }
        set {
            if let newValue {
                if var field = pathField {
                    field.value = newValue
                    pathField = field
                } else {
                    pathField = HTTPField(name: .path, value: newValue)
                }
            } else {
                pathField = nil
            }
        }
    }

    /// The value of the ":protocol" pseudo header field.
    public var extendedConnectProtocol: String? {
        get {
            extendedConnectProtocolField?.value
        }
        set {
            if let newValue {
                if var field = extendedConnectProtocolField {
                    field.value = newValue
                    extendedConnectProtocolField = field
                } else {
                    var field = HTTPField(name: .protocol, value: newValue)
                    field.indexingStrategy = .prefer
                    extendedConnectProtocolField = field
                }
            } else {
                extendedConnectProtocolField = nil
            }
        }
    }

    /// The underlying ":method" pseudo header field.
    public var methodField: HTTPField {
        willSet {
            precondition(newValue.name == .method, "Cannot change pseudo-header field name")
            precondition(HTTPField.isValidToken(newValue.rawValue._storage), "Invalid character in method field")
        }
    }

    /// The underlying ":scheme" pseudo header field.
    public var schemeField: HTTPField? {
        willSet {
            if let name = newValue?.name {
                precondition(name == .scheme, "Cannot change pseudo-header field name")
            }
        }
    }

    /// The underlying ":authority" pseudo header field.
    public var authorityField: HTTPField? {
        willSet {
            if let name = newValue?.name {
                precondition(name == .authority, "Cannot change pseudo-header field name")
            }
        }
    }

    /// The underlying ":path" pseudo header field.
    public var pathField: HTTPField? {
        willSet {
            if let name = newValue?.name {
                precondition(name == .path, "Cannot change pseudo-header field name")
            }
        }
    }

    /// The underlying ":protocol" pseudo header field.
    public var extendedConnectProtocolField: HTTPField? {
        willSet {
            if let name = newValue?.name {
                precondition(name == .protocol, "Cannot change pseudo-header field name")
            }
        }
    }

    /// The request header fields.
    public var headerFields: HTTPFields

    /// Create an HTTP request with values of pseudo header fields and header fields.
    /// - Parameters:
    ///   - method: The request method.
    ///   - scheme: The value of the ":scheme" pseudo header field.
    ///   - authority: The value of the ":authority" pseudo header field.
    ///   - path: The value of the ":path" pseudo header field.
    ///   - headerFields: The request header fields.
    public init(method: Method, scheme: String?, authority: String?, path: String?, headerFields: HTTPFields = [:]) {
        methodField = HTTPField(name: .method, uncheckedValue: ISOLatin1String(unchecked: method.rawValue))
        methodField.indexingStrategy = .prefer
        schemeField = scheme.map {
            var field = HTTPField(name: .scheme, value: $0)
            field.indexingStrategy = .prefer
            return field
        }
        authorityField = authority.map {
            var field = HTTPField(name: .authority, value: $0)
            field.indexingStrategy = .prefer
            return field
        }
        pathField = path.map { HTTPField(name: .path, value: $0) }
        self.headerFields = headerFields
    }
}

extension HTTPRequest: CustomDebugStringConvertible {
    public var debugDescription: String {
        "(\(methodField.rawValue._storage)) \((schemeField?.value).map { "\($0)://" } ?? "")\(authorityField?.value ?? "")\(pathField?.value ?? "")"
    }
}

extension HTTPRequest.Method {
    /// GET
    public static let get = HTTPRequest.Method(unchecked: "GET")
    /// PUT
    public static let put = HTTPRequest.Method(unchecked: "PUT")
    /// ACL
    public static let acl = HTTPRequest.Method(unchecked: "ACL")
    /// HEAD
    public static let head = HTTPRequest.Method(unchecked: "HEAD")
    /// POST
    public static let post = HTTPRequest.Method(unchecked: "POST")
    /// COPY
    public static let copy = HTTPRequest.Method(unchecked: "COPY")
    /// LOCK
    public static let lock = HTTPRequest.Method(unchecked: "LOCK")
    /// MOVE
    public static let move = HTTPRequest.Method(unchecked: "MOVE")
    /// BIND
    public static let bind = HTTPRequest.Method(unchecked: "BIND")
    /// LINK
    public static let link = HTTPRequest.Method(unchecked: "LINK")
    /// PATCH
    public static let patch = HTTPRequest.Method(unchecked: "PATCH")
    /// TRACE
    public static let trace = HTTPRequest.Method(unchecked: "TRACE")
    /// MKCOL
    public static let mkcol = HTTPRequest.Method(unchecked: "MKCOL")
    /// MERGE
    public static let merge = HTTPRequest.Method(unchecked: "MERGE")
    /// PURGE
    public static let purge = HTTPRequest.Method(unchecked: "PURGE")
    /// NOTIFY
    public static let notify = HTTPRequest.Method(unchecked: "NOTIFY")
    /// SEARCH
    public static let search = HTTPRequest.Method(unchecked: "SEARCH")
    /// UNLOCK
    public static let unlock = HTTPRequest.Method(unchecked: "UNLOCK")
    /// REBIND
    public static let rebind = HTTPRequest.Method(unchecked: "REBIND")
    /// UNBIND
    public static let unbind = HTTPRequest.Method(unchecked: "UNBIND")
    /// REPORT
    public static let report = HTTPRequest.Method(unchecked: "REPORT")
    /// DELETE
    public static let delete = HTTPRequest.Method(unchecked: "DELETE")
    /// UNLINK
    public static let unlink = HTTPRequest.Method(unchecked: "UNLINK")
    /// CONNECT
    public static let connect = HTTPRequest.Method(unchecked: "CONNECT")
    /// MSEARCH
    public static let msearch = HTTPRequest.Method(unchecked: "MSEARCH")
    /// OPTIONS
    public static let options = HTTPRequest.Method(unchecked: "OPTIONS")
    /// PROPFIND
    public static let propfind = HTTPRequest.Method(unchecked: "PROPFIND")
    /// CHECKOUT
    public static let checkout = HTTPRequest.Method(unchecked: "CHECKOUT")
    /// PROPPATCH
    public static let proppatch = HTTPRequest.Method(unchecked: "PROPPATCH")
    /// SUBSCRIBE
    public static let subscribe = HTTPRequest.Method(unchecked: "SUBSCRIBE")
    /// MKCALENDAR
    public static let mkcalendar = HTTPRequest.Method(unchecked: "MKCALENDAR")
    /// MKACTIVITY
    public static let mkactivity = HTTPRequest.Method(unchecked: "MKACTIVITY")
    /// UNSUBSCRIBE
    public static let unsubscribe = HTTPRequest.Method(unchecked: "UNSUBSCRIBE")
    /// SOURCE
    public static let source = HTTPRequest.Method(unchecked: "SOURCE")
    /// CONNECT-UDP
    static let connectUDP = HTTPRequest.Method(unchecked: "CONNECT-UDP")
}
