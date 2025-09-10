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

        fileprivate init(unchecked: String) {
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
            Method(unchecked: self.pseudoHeaderFields.method.rawValue._storage)
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
        private final class _Storage: @unchecked Sendable, Hashable {
            var method: HTTPField
            var scheme: HTTPField?
            var authority: HTTPField?
            var path: HTTPField?
            var extendedConnectProtocol: HTTPField?

            init(
                method: HTTPField,
                scheme: HTTPField?,
                authority: HTTPField?,
                path: HTTPField?,
                extendedConnectProtocol: HTTPField?
            ) {
                self.method = method
                self.scheme = scheme
                self.authority = authority
                self.path = path
                self.extendedConnectProtocol = extendedConnectProtocol
            }

            func copy() -> Self {
                .init(
                    method: self.method,
                    scheme: self.scheme,
                    authority: self.authority,
                    path: self.path,
                    extendedConnectProtocol: self.extendedConnectProtocol
                )
            }

            static func == (lhs: _Storage, rhs: _Storage) -> Bool {
                lhs.method == rhs.method && lhs.scheme == rhs.scheme && lhs.authority == rhs.authority
                    && lhs.path == rhs.path && lhs.extendedConnectProtocol == rhs.extendedConnectProtocol
            }

            func hash(into hasher: inout Hasher) {
                hasher.combine(self.method)
                hasher.combine(self.scheme)
                hasher.combine(self.authority)
                hasher.combine(self.path)
                hasher.combine(self.extendedConnectProtocol)
            }
        }

        private var _storage: _Storage

        /// The underlying ":method" pseudo header field.
        ///
        /// The value of this field must be a valid method.
        ///
        /// https://www.rfc-editor.org/rfc/rfc9110.html#name-methods
        public var method: HTTPField {
            get {
                self._storage.method
            }
            set {
                precondition(newValue.name == .method, "Cannot change pseudo-header field name")
                precondition(HTTPField.isValidToken(newValue.rawValue._storage), "Invalid character in method field")

                if !isKnownUniquelyReferenced(&self._storage) {
                    self._storage = self._storage.copy()
                }
                self._storage.method = newValue
            }
        }

        /// The underlying ":scheme" pseudo header field.
        public var scheme: HTTPField? {
            get {
                self._storage.scheme
            }
            set {
                if let name = newValue?.name {
                    precondition(name == .scheme, "Cannot change pseudo-header field name")
                }

                if !isKnownUniquelyReferenced(&self._storage) {
                    self._storage = self._storage.copy()
                }
                self._storage.scheme = newValue
            }
        }

        /// The underlying ":authority" pseudo header field.
        public var authority: HTTPField? {
            get {
                self._storage.authority
            }
            set {
                if let name = newValue?.name {
                    precondition(name == .authority, "Cannot change pseudo-header field name")
                }

                if !isKnownUniquelyReferenced(&self._storage) {
                    self._storage = self._storage.copy()
                }
                self._storage.authority = newValue
            }
        }

        /// The underlying ":path" pseudo header field.
        public var path: HTTPField? {
            get {
                self._storage.path
            }
            set {
                if let name = newValue?.name {
                    precondition(name == .path, "Cannot change pseudo-header field name")
                }

                if !isKnownUniquelyReferenced(&self._storage) {
                    self._storage = self._storage.copy()
                }
                self._storage.path = newValue
            }
        }

        /// The underlying ":protocol" pseudo header field.
        public var extendedConnectProtocol: HTTPField? {
            get {
                self._storage.extendedConnectProtocol
            }
            set {
                if let name = newValue?.name {
                    precondition(name == .protocol, "Cannot change pseudo-header field name")
                }

                if !isKnownUniquelyReferenced(&self._storage) {
                    self._storage = self._storage.copy()
                }
                self._storage.extendedConnectProtocol = newValue
            }
        }

        init(
            method: HTTPField,
            scheme: HTTPField?,
            authority: HTTPField?,
            path: HTTPField?,
            extendedConnectProtocol: HTTPField? = nil
        ) {
            self._storage = .init(
                method: method,
                scheme: scheme,
                authority: authority,
                path: path,
                extendedConnectProtocol: extendedConnectProtocol
            )
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
        self.pseudoHeaderFields = .init(
            method: methodField,
            scheme: schemeField,
            authority: authorityField,
            path: pathField
        )
        self.headerFields = headerFields
    }
}

extension HTTPRequest: CustomDebugStringConvertible {
    public var debugDescription: String {
        "(\(self.pseudoHeaderFields.method.rawValue._storage)) \((self.pseudoHeaderFields.scheme?.value).map { "\($0)://" } ?? "")\(self.pseudoHeaderFields.authority?.value ?? "")\(self.pseudoHeaderFields.path?.value ?? "")"
    }
}

extension HTTPRequest.PseudoHeaderFields: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(self.method)
        if let scheme = self.scheme {
            try container.encode(scheme)
        }
        if let authority = self.authority {
            try container.encode(authority)
        }
        if let path = self.path {
            try container.encode(path)
        }
        if let extendedConnectProtocol = self.extendedConnectProtocol {
            try container.encode(extendedConnectProtocol)
        }
    }

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var method: HTTPField?
        var scheme: HTTPField?
        var authority: HTTPField?
        var path: HTTPField?
        var extendedConnectProtocol: HTTPField?
        while !container.isAtEnd {
            let field = try container.decode(HTTPField.self)
            switch field.name {
            case .method:
                guard method == nil else {
                    throw DecodingError.dataCorruptedError(
                        in: container,
                        debugDescription: "Multiple \":method\" pseudo header fields"
                    )
                }
                method = field
            case .scheme:
                guard scheme == nil else {
                    throw DecodingError.dataCorruptedError(
                        in: container,
                        debugDescription: "Multiple \":scheme\" pseudo header fields"
                    )
                }
                scheme = field
            case .authority:
                guard authority == nil else {
                    throw DecodingError.dataCorruptedError(
                        in: container,
                        debugDescription: "Multiple \":authority\" pseudo header fields"
                    )
                }
                authority = field
            case .path:
                guard path == nil else {
                    throw DecodingError.dataCorruptedError(
                        in: container,
                        debugDescription: "Multiple \":path\" pseudo header fields"
                    )
                }
                path = field
            case .protocol:
                guard extendedConnectProtocol == nil else {
                    throw DecodingError.dataCorruptedError(
                        in: container,
                        debugDescription: "Multiple \":protocol\" pseudo header fields"
                    )
                }
                extendedConnectProtocol = field
            default:
                guard field.name.rawName.utf8.first == UInt8(ascii: ":") else {
                    throw DecodingError.dataCorruptedError(
                        in: container,
                        debugDescription: "\"\(field)\" is not a pseudo header field"
                    )
                }
            }
        }
        guard let method else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "\":method\" pseudo header field is missing"
            )
        }
        guard HTTPField.isValidToken(method.rawValue._storage) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "\"\(method.rawValue._storage)\" is not a valid method"
            )
        }
        self.init(
            method: method,
            scheme: scheme,
            authority: authority,
            path: path,
            extendedConnectProtocol: extendedConnectProtocol
        )
    }
}

extension HTTPRequest: Codable {
    enum CodingKeys: String, CodingKey {
        case pseudoHeaderFields
        case headerFields
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.pseudoHeaderFields, forKey: .pseudoHeaderFields)
        try container.encode(self.headerFields, forKey: .headerFields)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.pseudoHeaderFields = try container.decode(PseudoHeaderFields.self, forKey: .pseudoHeaderFields)
        self.headerFields = try container.decode(HTTPFields.self, forKey: .headerFields)
    }
}

extension HTTPRequest.Method {
    /// GET
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var get: Self { .init(unchecked: "GET") }

    /// HEAD
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var head: Self { .init(unchecked: "HEAD") }

    /// POST
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var post: Self { .init(unchecked: "POST") }

    /// PUT
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var put: Self { .init(unchecked: "PUT") }

    /// DELETE
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var delete: Self { .init(unchecked: "DELETE") }

    /// CONNECT
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var connect: Self { .init(unchecked: "CONNECT") }
    /// OPTIONS
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var options: Self { .init(unchecked: "OPTIONS") }

    /// TRACE
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var trace: Self { .init(unchecked: "TRACE") }

    /// PATCH
    ///
    /// https://www.rfc-editor.org/rfc/rfc5789.html
    public static var patch: Self { .init(unchecked: "PATCH") }

    /// QUERY
    ///
    /// https://datatracker.ietf.org/doc/draft-ietf-httpbis-safe-method-w-body/
    static var query: Self { .init(unchecked: "QUERY") }

    /// CONNECT-UDP
    static var connectUDP: Self { .init(unchecked: "CONNECT-UDP") }

    var isSafe: Bool {
        self == .get || self == .head || self == .options || self == .query
    }
}
