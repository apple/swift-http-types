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

/// An HTTP request message consisting of pseudo header fields and header fields.
///
/// Currently supported pseudo header fields are ":method", ":scheme", ":authority", ":path", and
/// ":protocol". Conveniences are provided to set these pseudo header fields through a URL and
/// strings.
///
/// In a legacy HTTP/1 context, the ":scheme" is ignored and the ":authority" is translated into
/// the "Host" header.
public struct HTTPRequest: Sendable, Hashable {
    /// The HTTP request method
    public struct Method: Sendable, Hashable, RawRepresentable, LosslessStringConvertible {
        /// The string value of the request.
        public let rawValue: String

        /// Create a request method from a string. Returns nil if the string contains invalid
        /// characters defined in RFC 9110.
        ///
        /// https://www.rfc-editor.org/rfc/rfc9110.html#name-methods
        ///
        /// - Parameter method: The method string. It can be accessed from the `rawValue` property.
        public init?(_ method: String) {
            guard HTTPField.isValidToken(method) else {
                return nil
            }
            self.rawValue = method
        }

        public init?(rawValue: String) {
            self.init(rawValue)
        }

        private init(unchecked: String) {
            self.rawValue = unchecked
        }

        public var description: String {
            self.rawValue
        }
    }

    /// The HTTP request method.
    ///
    /// A convenient way to access the value of the ":method" pseudo header field.
    public var method: Method {
        get {
            Method(self.pseudoHeaderFields.method.rawValue._storage)!
        }
        set {
            self.pseudoHeaderFields.method.rawValue = ISOLatin1String(unchecked: newValue.rawValue)
        }
    }

    /// A convenient way to access the value of the ":scheme" pseudo header field.
    ///
    /// The scheme is ignored in a legacy HTTP/1 context.
    public var scheme: String? {
        get {
            self.pseudoHeaderFields.scheme?.value
        }
        set {
            if let newValue {
                if var field = pseudoHeaderFields.scheme {
                    field.value = newValue
                    self.pseudoHeaderFields.scheme = field
                } else {
                    self.pseudoHeaderFields.scheme = HTTPField(name: .scheme, value: newValue)
                }
            } else {
                self.pseudoHeaderFields.scheme = nil
            }
        }
    }

    /// A convenient way to access the value of the ":authority" pseudo header field.
    ///
    /// The authority is translated into the "Host" header in a legacy HTTP/1 context.
    public var authority: String? {
        get {
            self.pseudoHeaderFields.authority?.value
        }
        set {
            if let newValue {
                if var field = pseudoHeaderFields.authority {
                    field.value = newValue
                    self.pseudoHeaderFields.authority = field
                } else {
                    self.pseudoHeaderFields.authority = HTTPField(name: .authority, value: newValue)
                }
            } else {
                self.pseudoHeaderFields.authority = nil
            }
        }
    }

    /// A convenient way to access the value of the ":path" pseudo header field.
    public var path: String? {
        get {
            self.pseudoHeaderFields.path?.value
        }
        set {
            if let newValue {
                if var field = pseudoHeaderFields.path {
                    field.value = newValue
                    self.pseudoHeaderFields.path = field
                } else {
                    self.pseudoHeaderFields.path = HTTPField(name: .path, value: newValue)
                }
            } else {
                self.pseudoHeaderFields.path = nil
            }
        }
    }

    /// A convenient way to access the value of the ":protocol" pseudo header field.
    public var extendedConnectProtocol: String? {
        get {
            self.pseudoHeaderFields.extendedConnectProtocol?.value
        }
        set {
            if let newValue {
                if var field = pseudoHeaderFields.extendedConnectProtocol {
                    field.value = newValue
                    self.pseudoHeaderFields.extendedConnectProtocol = field
                } else {
                    self.pseudoHeaderFields.extendedConnectProtocol = HTTPField(name: .protocol, value: newValue)
                }
            } else {
                self.pseudoHeaderFields.extendedConnectProtocol = nil
            }
        }
    }

    /// The pseudo header fields of a request.
    public struct PseudoHeaderFields: Sendable, Hashable {
        /// The underlying ":method" pseudo header field.
        ///
        /// The value of this field must be a valid method.
        ///
        /// https://www.rfc-editor.org/rfc/rfc9110.html#name-methods
        public var method: HTTPField {
            willSet {
                precondition(newValue.name == .method, "Cannot change pseudo-header field name")
                precondition(HTTPField.isValidToken(newValue.rawValue._storage), "Invalid character in method field")
            }
        }

        /// The underlying ":scheme" pseudo header field.
        public var scheme: HTTPField? {
            willSet {
                if let name = newValue?.name {
                    precondition(name == .scheme, "Cannot change pseudo-header field name")
                }
            }
        }

        /// The underlying ":authority" pseudo header field.
        public var authority: HTTPField? {
            willSet {
                if let name = newValue?.name {
                    precondition(name == .authority, "Cannot change pseudo-header field name")
                }
            }
        }

        /// The underlying ":path" pseudo header field.
        public var path: HTTPField? {
            willSet {
                if let name = newValue?.name {
                    precondition(name == .path, "Cannot change pseudo-header field name")
                }
            }
        }

        /// The underlying ":protocol" pseudo header field.
        public var extendedConnectProtocol: HTTPField? {
            willSet {
                if let name = newValue?.name {
                    precondition(name == .protocol, "Cannot change pseudo-header field name")
                }
            }
        }
    }

    /// The pseudo header fields.
    public var pseudoHeaderFields: PseudoHeaderFields

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
        let methodField = HTTPField(name: .method, uncheckedValue: ISOLatin1String(unchecked: method.rawValue))
        let schemeField = scheme.map { HTTPField(name: .scheme, value: $0) }
        let authorityField = authority.map { HTTPField(name: .authority, value: $0) }
        let pathField = path.map { HTTPField(name: .path, value: $0) }
        self.pseudoHeaderFields = .init(method: methodField, scheme: schemeField, authority: authorityField, path: pathField)
        self.headerFields = headerFields
    }
}

extension HTTPRequest: CustomDebugStringConvertible {
    public var debugDescription: String {
        "(\(self.pseudoHeaderFields.method.rawValue._storage)) \((self.pseudoHeaderFields.scheme?.value).map { "\($0)://" } ?? "")\(self.pseudoHeaderFields.authority?.value ?? "")\(self.pseudoHeaderFields.path?.value ?? "")"
    }
}

extension HTTPRequest.Method {
    /// GET
    public static var get: Self { .init(unchecked: "GET") }
    /// PUT
    public static var put: Self { .init(unchecked: "PUT") }
    /// ACL
    public static var acl: Self { .init(unchecked: "ACL") }
    /// HEAD
    public static var head: Self { .init(unchecked: "HEAD") }
    /// POST
    public static var post: Self { .init(unchecked: "POST") }
    /// COPY
    public static var copy: Self { .init(unchecked: "COPY") }
    /// LOCK
    public static var lock: Self { .init(unchecked: "LOCK") }
    /// MOVE
    public static var move: Self { .init(unchecked: "MOVE") }
    /// BIND
    public static var bind: Self { .init(unchecked: "BIND") }
    /// LINK
    public static var link: Self { .init(unchecked: "LINK") }
    /// PATCH
    public static var patch: Self { .init(unchecked: "PATCH") }
    /// TRACE
    public static var trace: Self { .init(unchecked: "TRACE") }
    /// MKCOL
    public static var mkcol: Self { .init(unchecked: "MKCOL") }
    /// MERGE
    public static var merge: Self { .init(unchecked: "MERGE") }
    /// PURGE
    public static var purge: Self { .init(unchecked: "PURGE") }
    /// NOTIFY
    public static var notify: Self { .init(unchecked: "NOTIFY") }
    /// SEARCH
    public static var search: Self { .init(unchecked: "SEARCH") }
    /// UNLOCK
    public static var unlock: Self { .init(unchecked: "UNLOCK") }
    /// REBIND
    public static var rebind: Self { .init(unchecked: "REBIND") }
    /// UNBIND
    public static var unbind: Self { .init(unchecked: "UNBIND") }
    /// REPORT
    public static var report: Self { .init(unchecked: "REPORT") }
    /// DELETE
    public static var delete: Self { .init(unchecked: "DELETE") }
    /// UNLINK
    public static var unlink: Self { .init(unchecked: "UNLINK") }
    /// CONNECT
    public static var connect: Self { .init(unchecked: "CONNECT") }
    /// MSEARCH
    public static var msearch: Self { .init(unchecked: "MSEARCH") }
    /// OPTIONS
    public static var options: Self { .init(unchecked: "OPTIONS") }
    /// PROPFIND
    public static var propfind: Self { .init(unchecked: "PROPFIND") }
    /// CHECKOUT
    public static var checkout: Self { .init(unchecked: "CHECKOUT") }
    /// PROPPATCH
    public static var proppatch: Self { .init(unchecked: "PROPPATCH") }
    /// SUBSCRIBE
    public static var subscribe: Self { .init(unchecked: "SUBSCRIBE") }
    /// MKCALENDAR
    public static var mkcalendar: Self { .init(unchecked: "MKCALENDAR") }
    /// MKACTIVITY
    public static var mkactivity: Self { .init(unchecked: "MKACTIVITY") }
    /// UNSUBSCRIBE
    public static var unsubscribe: Self { .init(unchecked: "UNSUBSCRIBE") }
    /// SOURCE
    public static var source: Self { .init(unchecked: "SOURCE") }
    /// CONNECT-UDP
    static var connectUDP: Self { .init(unchecked: "CONNECT-UDP") }
}
