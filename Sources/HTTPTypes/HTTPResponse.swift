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

/// An HTTP response message consisting of the ":status" pseudo header field and header fields.
///
/// Conveniences are provided to access the status code and its reason phrase.
public struct HTTPResponse: Sendable, Hashable {
    /// The response status consisting of a 3-digit status code and a reason phrase. The reason
    /// phrase is ignored by modern HTTP versions.
    public struct Status: Sendable, Hashable, ExpressibleByIntegerLiteral, CustomStringConvertible {
        /// The 3-digit status code.
        public let code: Int
        /// The reason phrase.
        ///
        /// ISO Latin 1 encoding should be used to serialize and deserialize this string.
        public let reasonPhrase: String

        /// Create a custom status from a code and a reason phrase.
        /// - Parameters:
        ///   - code: The status code.
        ///   - reasonPhrase: The optional reason phrase. Invalid characters, including any
        ///                   characters not representable in ISO Latin 1 encoding, are converted
        ///                   into space characters.
        public init(code: Int, reasonPhrase: String = "") {
            precondition((0...999).contains(code), "Invalid status code")
            self.code = code
            self.reasonPhrase = Self.legalizingReasonPhrase(reasonPhrase)
        }

        fileprivate init(uncheckedCode: Int, reasonPhrase: String) {
            self.code = uncheckedCode
            self.reasonPhrase = reasonPhrase
        }

        /// Create a custom status from an integer literal.
        /// - Parameter value: The status code.
        public init(integerLiteral value: Int) {
            precondition((0...999).contains(value), "Invalid status code")
            self.code = value
            self.reasonPhrase = ""
        }

        /// The first digit of the status code defines the kind of response.
        @frozen public enum Kind {
            /// The status code is outside the range of 100...599.
            case invalid
            /// The status code is informational (1xx) and the response is not final.
            case informational
            /// The status code is successful (2xx).
            case successful
            /// The status code is a redirection (3xx).
            case redirection
            /// The status code is a client error (4xx).
            case clientError
            /// The status code is a server error (5xx).
            case serverError
        }

        /// The kind of the status code.
        public var kind: Kind {
            switch self.code {
            case 100...199:
                return .informational
            case 200...299:
                return .successful
            case 300...399:
                return .redirection
            case 400...499:
                return .clientError
            case 500...599:
                return .serverError
            default:
                return .invalid
            }
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(self.code)
        }

        public static func == (lhs: Status, rhs: Status) -> Bool {
            lhs.code == rhs.code
        }

        public var description: String {
            "\(self.code) \(self.reasonPhrase)"
        }

        var fieldValue: String {
            if #available(macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0, *) {
                return String(unsafeUninitializedCapacity: 3) { buffer in
                    buffer[0] = UInt8(self.code / 100) + 48
                    buffer[1] = UInt8((self.code / 10) % 10) + 48
                    buffer[2] = UInt8(self.code % 10) + 48
                    return 3
                }
            } else {
                return String([
                    Character(Unicode.Scalar(UInt8(self.code / 100) + 48)),
                    Character(Unicode.Scalar(UInt8((self.code / 10) % 10) + 48)),
                    Character(Unicode.Scalar(UInt8(self.code % 10) + 48)),
                ])
            }
        }

        static func isValidStatus(_ status: String) -> Bool {
            status.count == 3 && status.utf8.allSatisfy { (0x30...0x39).contains($0) }
        }

        static func isValidReasonPhrase(_ reasonPhrase: String) -> Bool {
            reasonPhrase.utf8.allSatisfy {
                switch $0 {
                case 0x09, 0x20:
                    return true
                case 0x21...0x7E, 0x80...0xFF:
                    return true
                default:
                    return false
                }
            }
        }

        static func legalizingReasonPhrase(_ reasonPhrase: String) -> String {
            if self.isValidReasonPhrase(reasonPhrase) {
                return reasonPhrase
            } else {
                let scalars = reasonPhrase.unicodeScalars.lazy.map { scala -> UnicodeScalar in
                    switch scala.value {
                    case 0x09, 0x20:
                        return scala
                    case 0x21...0x7E, 0x80...0xFF:
                        return scala
                    default:
                        return " "
                    }
                }
                var string = ""
                string.unicodeScalars.append(contentsOf: scalars)
                return string
            }
        }
    }

    /// The status of the response.
    ///
    /// A convenient way to access the value of the ":status" pseudo header field and the reason
    /// phrase.
    public var status: Status {
        get {
            var codeIterator = self.pseudoHeaderFields.status.rawValue._storage.utf8.makeIterator()
            let code =
                Int(codeIterator.next()! - 48) * 100 + Int(codeIterator.next()! - 48) * 10
                + Int(codeIterator.next()! - 48)
            return Status(uncheckedCode: code, reasonPhrase: self.pseudoHeaderFields.reasonPhrase)
        }
        set {
            self.pseudoHeaderFields.status.rawValue = ISOLatin1String(unchecked: newValue.fieldValue)
            self.pseudoHeaderFields.reasonPhrase = newValue.reasonPhrase
        }
    }

    /// The pseudo header fields of a response.
    public struct PseudoHeaderFields: Sendable, Hashable {
        private final class _Storage: @unchecked Sendable, Hashable {
            var status: HTTPField
            var reasonPhrase: String

            init(status: HTTPField, reasonPhrase: String) {
                self.status = status
                self.reasonPhrase = reasonPhrase
            }

            func copy() -> Self {
                .init(
                    status: self.status,
                    reasonPhrase: self.reasonPhrase
                )
            }

            static func == (lhs: _Storage, rhs: _Storage) -> Bool {
                lhs.status == rhs.status
            }

            func hash(into hasher: inout Hasher) {
                hasher.combine(self.status)
            }
        }

        private var _storage: _Storage

        /// The underlying ":status" pseudo header field.
        ///
        /// The value of this field must be 3 ASCII decimal digits.
        public var status: HTTPField {
            get {
                self._storage.status
            }
            set {
                precondition(newValue.name == .status, "Cannot change pseudo-header field name")
                precondition(Status.isValidStatus(newValue.rawValue._storage), "Invalid status code")

                if !isKnownUniquelyReferenced(&self._storage) {
                    self._storage = self._storage.copy()
                }
                self._storage.status = newValue
            }
        }

        var reasonPhrase: String {
            get {
                self._storage.reasonPhrase
            }
            set {
                if !isKnownUniquelyReferenced(&self._storage) {
                    self._storage = self._storage.copy()
                }
                self._storage.reasonPhrase = newValue
            }
        }

        private init(status: HTTPField) {
            self._storage = .init(status: status, reasonPhrase: "")
        }

        init(status: Status) {
            self._storage = .init(
                status: HTTPField(name: .status, uncheckedValue: ISOLatin1String(unchecked: status.fieldValue)),
                reasonPhrase: status.reasonPhrase
            )
        }
    }

    /// The pseudo header fields.
    public var pseudoHeaderFields: PseudoHeaderFields

    /// The response header fields.
    public var headerFields: HTTPFields

    /// Create an HTTP response with a status and header fields.
    /// - Parameters:
    ///   - status: The status code and an optional reason phrase.
    ///   - headerFields: The response header fields.
    public init(status: Status, headerFields: HTTPFields = [:]) {
        self.pseudoHeaderFields = .init(status: status)
        self.headerFields = headerFields
    }
}

extension HTTPResponse: CustomDebugStringConvertible {
    public var debugDescription: String {
        "\(self.status)"
    }
}

extension HTTPResponse.PseudoHeaderFields: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(self.status)
    }

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var status: HTTPField?
        while !container.isAtEnd {
            let field = try container.decode(HTTPField.self)
            switch field.name {
            case .status:
                guard status == nil else {
                    throw DecodingError.dataCorruptedError(
                        in: container,
                        debugDescription: "Multiple \":status\" pseudo header fields"
                    )
                }
                status = field
            default:
                guard field.name.rawName.utf8.first == UInt8(ascii: ":") else {
                    throw DecodingError.dataCorruptedError(
                        in: container,
                        debugDescription: "\"\(field)\" is not a pseudo header field"
                    )
                }
            }
        }
        guard let status else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "\":status\" pseudo header field is missing"
            )
        }
        guard HTTPResponse.Status.isValidStatus(status.rawValue._storage) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "\"\(status.rawValue._storage)\" is not a valid status code"
            )
        }
        self.init(status: status)
    }
}

extension HTTPResponse: Codable {
    enum CodingKeys: String, CodingKey {
        case pseudoHeaderFields
        case headerFields
        case reasonPhrase
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.pseudoHeaderFields, forKey: .pseudoHeaderFields)
        try container.encode(self.pseudoHeaderFields.reasonPhrase, forKey: .reasonPhrase)
        try container.encode(self.headerFields, forKey: .headerFields)
    }

    private enum DecodingError: Error {
        case invalidReasonPhrase(String)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.pseudoHeaderFields = try container.decode(PseudoHeaderFields.self, forKey: .pseudoHeaderFields)
        let reasonPhrase = try container.decode(String.self, forKey: .reasonPhrase)
        guard Status.isValidReasonPhrase(reasonPhrase) else {
            throw DecodingError.invalidReasonPhrase(reasonPhrase)
        }
        self.pseudoHeaderFields.reasonPhrase = reasonPhrase
        self.headerFields = try container.decode(HTTPFields.self, forKey: .headerFields)
    }
}

extension HTTPResponse.Status {
    // MARK: 1xx

    /// 100 Continue
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var `continue`: Self { .init(uncheckedCode: 100, reasonPhrase: "Continue") }

    /// 101 Switching Protocols
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var switchingProtocols: Self { .init(uncheckedCode: 101, reasonPhrase: "Switching Protocols") }

    /// 103 Early Hints
    ///
    /// https://www.rfc-editor.org/rfc/rfc8297.html
    public static var earlyHints: Self { .init(uncheckedCode: 103, reasonPhrase: "Early Hints") }

    // MARK: 2xx

    /// 200 OK
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var ok: Self { .init(uncheckedCode: 200, reasonPhrase: "OK") }

    /// 201 Created
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var created: Self { .init(uncheckedCode: 201, reasonPhrase: "Created") }

    /// 202 Accepted
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var accepted: Self { .init(uncheckedCode: 202, reasonPhrase: "Accepted") }

    /// 203 Non-Authoritative Information
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var nonAuthoritativeInformation: Self {
        .init(uncheckedCode: 203, reasonPhrase: "Non-Authoritative Information")
    }

    /// 204 No Content
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var noContent: Self { .init(uncheckedCode: 204, reasonPhrase: "No Content") }

    /// 205 Reset Content
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var resetContent: Self { .init(uncheckedCode: 205, reasonPhrase: "Reset Content") }

    /// 206 Partial Content
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var partialContent: Self { .init(uncheckedCode: 206, reasonPhrase: "Partial Content") }

    // MARK: 3xx

    /// 300 Multiple Choices
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var multipleChoices: Self { .init(uncheckedCode: 300, reasonPhrase: "Multiple Choices") }

    /// 301 Moved Permanently
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var movedPermanently: Self { .init(uncheckedCode: 301, reasonPhrase: "Moved Permanently") }

    /// 302 Found
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var found: Self { .init(uncheckedCode: 302, reasonPhrase: "Found") }

    /// 303 See Other
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var seeOther: Self { .init(uncheckedCode: 303, reasonPhrase: "See Other") }

    /// 304 Not Modified
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var notModified: Self { .init(uncheckedCode: 304, reasonPhrase: "Not Modified") }

    /// 307 Temporary Redirect
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var temporaryRedirect: Self { .init(uncheckedCode: 307, reasonPhrase: "Temporary Redirect") }

    /// 308 Permanent Redirect
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var permanentRedirect: Self { .init(uncheckedCode: 308, reasonPhrase: "Permanent Redirect") }

    // MARK: 4xx

    /// 400 Bad Request
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var badRequest: Self { .init(uncheckedCode: 400, reasonPhrase: "Bad Request") }

    /// 401 Unauthorized
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var unauthorized: Self { .init(uncheckedCode: 401, reasonPhrase: "Unauthorized") }

    /// 403 Forbidden
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var forbidden: Self { .init(uncheckedCode: 403, reasonPhrase: "Forbidden") }

    /// 404 Not Found
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var notFound: Self { .init(uncheckedCode: 404, reasonPhrase: "Not Found") }

    /// 405 Method Not Allowed
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var methodNotAllowed: Self { .init(uncheckedCode: 405, reasonPhrase: "Method Not Allowed") }

    /// 406 Not Acceptable
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var notAcceptable: Self { .init(uncheckedCode: 406, reasonPhrase: "Not Acceptable") }

    /// 407 Proxy Authentication Required
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var proxyAuthenticationRequired: Self {
        .init(uncheckedCode: 407, reasonPhrase: "Proxy Authentication Required")
    }

    /// 408 Request Timeout
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var requestTimeout: Self { .init(uncheckedCode: 408, reasonPhrase: "Request Timeout") }

    /// 409 Conflict
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var conflict: Self { .init(uncheckedCode: 409, reasonPhrase: "Conflict") }

    /// 410 Gone
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var gone: Self { .init(uncheckedCode: 410, reasonPhrase: "Gone") }

    /// 411 Length Required
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var lengthRequired: Self { .init(uncheckedCode: 411, reasonPhrase: "Length Required") }

    /// 412 Precondition Failed
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var preconditionFailed: Self { .init(uncheckedCode: 412, reasonPhrase: "Precondition Failed") }

    /// 413 Content Too Large
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var contentTooLarge: Self { .init(uncheckedCode: 413, reasonPhrase: "Content Too Large") }

    /// 414 URI Too Long
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var uriTooLong: Self { .init(uncheckedCode: 414, reasonPhrase: "URI Too Long") }

    /// 415 Unsupported Media Type
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var unsupportedMediaType: Self { .init(uncheckedCode: 415, reasonPhrase: "Unsupported Media Type") }

    /// 416 Range Not Satisfiable
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var rangeNotSatisfiable: Self { .init(uncheckedCode: 416, reasonPhrase: "Range Not Satisfiable") }

    /// 417 Expectation Failed
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var expectationFailed: Self { .init(uncheckedCode: 417, reasonPhrase: "Expectation Failed") }

    /// 421 Misdirected Request
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var misdirectedRequest: Self { .init(uncheckedCode: 421, reasonPhrase: "Misdirected Request") }

    /// 422 Unprocessable Content
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var unprocessableContent: Self { .init(uncheckedCode: 422, reasonPhrase: "Unprocessable Content") }

    /// 425 Too Early
    public static var tooEarly: Self { .init(uncheckedCode: 425, reasonPhrase: "Too Early") }

    /// 426 Upgrade Required
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var upgradeRequired: Self { .init(uncheckedCode: 426, reasonPhrase: "Upgrade Required") }

    /// 428 Precondition Required
    ///
    /// https://www.rfc-editor.org/rfc/rfc6585.html
    public static var preconditionRequired: Self { .init(uncheckedCode: 428, reasonPhrase: "Precondition Required") }

    /// 429 Too Many Requests
    ///
    /// https://www.rfc-editor.org/rfc/rfc6585.html
    public static var tooManyRequests: Self { .init(uncheckedCode: 429, reasonPhrase: "Too Many Requests") }

    /// 431 Request Header Fields Too Large
    ///
    /// https://www.rfc-editor.org/rfc/rfc6585.html
    public static var requestHeaderFieldsTooLarge: Self {
        .init(uncheckedCode: 431, reasonPhrase: "Request Header Fields Too Large")
    }

    /// 451 Unavailable For Legal Reasons
    ///
    /// https://www.rfc-editor.org/rfc/rfc7725.html
    public static var unavailableForLegalReasons: Self {
        .init(uncheckedCode: 451, reasonPhrase: "Unavailable For Legal Reasons")
    }

    // MARK: 5xx

    /// 500 Internal Server Error
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var internalServerError: Self { .init(uncheckedCode: 500, reasonPhrase: "Internal Server Error") }

    /// 501 Not Implemented
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var notImplemented: Self { .init(uncheckedCode: 501, reasonPhrase: "Not Implemented") }

    /// 502 Bad Gateway
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var badGateway: Self { .init(uncheckedCode: 502, reasonPhrase: "Bad Gateway") }

    /// 503 Service Unavailable
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var serviceUnavailable: Self { .init(uncheckedCode: 503, reasonPhrase: "Service Unavailable") }

    /// 504 Gateway Timeout
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var gatewayTimeout: Self { .init(uncheckedCode: 504, reasonPhrase: "Gateway Timeout") }

    /// 505 HTTP Version Not Supported
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html
    public static var httpVersionNotSupported: Self {
        .init(uncheckedCode: 505, reasonPhrase: "HTTP Version Not Supported")
    }

    /// 511 Network Authentication Required
    ///
    /// https://www.rfc-editor.org/rfc/rfc6585.html
    public static var networkAuthenticationRequired: Self {
        .init(uncheckedCode: 511, reasonPhrase: "Network Authentication Required")
    }
}
