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
public struct HTTPResponse: Sendable, Hashable, Codable {
    /// The response status consisting of a 3-digit status code and a reason phrase. The reason
    /// phrase is ignored by modern HTTP versions.
    public struct Status: Sendable, Hashable, ExpressibleByIntegerLiteral, CustomStringConvertible, Codable {
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
            precondition((0 ... 999).contains(code), "Invalid status code")
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
            precondition((0 ... 999).contains(value), "Invalid status code")
            self.code = value
            self.reasonPhrase = ""
        }

        /// The first digit of the status code defines the kind of response.
        @frozen public enum Kind: Codable {
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
            case 100 ... 199:
                return .informational
            case 200 ... 299:
                return .successful
            case 300 ... 399:
                return .redirection
            case 400 ... 499:
                return .clientError
            case 500 ... 599:
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
            String([
                Character(Unicode.Scalar(UInt8(self.code / 100) + 48)),
                Character(Unicode.Scalar(UInt8((self.code / 10) % 10) + 48)),
                Character(Unicode.Scalar(UInt8(self.code % 10) + 48)),
            ])
        }

        static func isValidStatus(_ status: String) -> Bool {
            status.count == 3 && status.utf8.allSatisfy { (0x30 ... 0x39).contains($0) }
        }

        static func isValidReasonPhrase(_ reasonPhrase: String) -> Bool {
            reasonPhrase.utf8.allSatisfy {
                switch $0 {
                case 0x09, 0x20:
                    return true
                case 0x21 ... 0x7E, 0x80 ... 0xFF:
                    return true
                default:
                    return false
                }
            }
        }

        static func legalizingReasonPhrase(_ reasonPhrase: String) -> String {
            if Self.isValidReasonPhrase(reasonPhrase) {
                return reasonPhrase
            } else {
                let scalars = reasonPhrase.unicodeScalars.lazy.map { scala -> UnicodeScalar in
                    switch scala.value {
                    case 0x09, 0x20:
                        return scala
                    case 0x21 ... 0x7E, 0x80 ... 0xFF:
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
            Status(uncheckedCode: Int(self.pseudoHeaderFields.status.rawValue._storage)!, reasonPhrase: self.reasonPhrase)
        }
        set {
            self.pseudoHeaderFields.status.rawValue = ISOLatin1String(unchecked: newValue.fieldValue)
            self.reasonPhrase = newValue.reasonPhrase
        }
    }

    /// The pseudo header fields of a response.
    public struct PseudoHeaderFields: Sendable, Hashable, Codable {
        /// The underlying ":status" pseudo header field.
        ///
        /// The value of this field must be 3 ASCII decimal digits.
        public var status: HTTPField {
            willSet {
                precondition(newValue.name == .status, "Cannot change pseudo-header field name")
                precondition(Status.isValidStatus(newValue.rawValue._storage), "Invalid status code")
            }
        }
    }

    /// The pseudo header fields.
    public var pseudoHeaderFields: PseudoHeaderFields

    private var reasonPhrase: String

    /// The response header fields.
    public var headerFields: HTTPFields

    /// Create an HTTP response with a status and header fields.
    /// - Parameters:
    ///   - status: The status code and an optional reason phrase.
    ///   - headerFields: The response header fields.
    public init(status: Status, headerFields: HTTPFields = [:]) {
        let statusField = HTTPField(name: .status, uncheckedValue: ISOLatin1String(unchecked: status.fieldValue))
        self.pseudoHeaderFields = .init(status: statusField)
        self.reasonPhrase = status.reasonPhrase
        self.headerFields = headerFields
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.pseudoHeaderFields)
        hasher.combine(self.headerFields)
    }

    public static func == (lhs: HTTPResponse, rhs: HTTPResponse) -> Bool {
        lhs.pseudoHeaderFields == rhs.pseudoHeaderFields && lhs.headerFields == lhs.headerFields
    }
}

extension HTTPResponse: CustomDebugStringConvertible {
    public var debugDescription: String {
        "\(self.status)"
    }
}

extension HTTPResponse.Status {
    // MARK: 1xx

    /// 100 Continue
    public static var `continue`: Self { .init(uncheckedCode: 100, reasonPhrase: "Continue") }
    /// 101 Switching Protocols
    public static var switchingProtocols: Self { .init(uncheckedCode: 101, reasonPhrase: "Switching Protocols") }
    /// 103 Early Hints
    public static var earlyHints: Self { .init(uncheckedCode: 103, reasonPhrase: "Early Hints") }

    // MARK: 2xx

    /// 200 OK
    public static var ok: Self { .init(uncheckedCode: 200, reasonPhrase: "OK") }
    /// 201 Created
    public static var created: Self { .init(uncheckedCode: 201, reasonPhrase: "Created") }
    /// 202 Accepted
    public static var accepted: Self { .init(uncheckedCode: 202, reasonPhrase: "Accepted") }
    /// 203 Non-Authoritative Information
    public static var nonAuthoritativeInformation: Self { .init(uncheckedCode: 203, reasonPhrase: "Non-Authoritative Information") }
    /// 204 No Content
    public static var noContent: Self { .init(uncheckedCode: 204, reasonPhrase: "No Content") }
    /// 205 Reset Content
    public static var resetContent: Self { .init(uncheckedCode: 205, reasonPhrase: "Reset Content") }
    /// 206 Partial Content
    public static var partialContent: Self { .init(uncheckedCode: 206, reasonPhrase: "Partial Content") }

    // MARK: 3xx

    /// 300 Multiple Choices
    public static var multipleChoices: Self { .init(uncheckedCode: 300, reasonPhrase: "Multiple Choices") }
    /// 301 Moved Permanently
    public static var movedPermanently: Self { .init(uncheckedCode: 301, reasonPhrase: "Moved Permanently") }
    /// 302 Found
    public static var found: Self { .init(uncheckedCode: 302, reasonPhrase: "Found") }
    /// 303 See Other
    public static var seeOther: Self { .init(uncheckedCode: 303, reasonPhrase: "See Other") }
    /// 304 Not Modified
    public static var notModified: Self { .init(uncheckedCode: 304, reasonPhrase: "Not Modified") }
    /// 307 Temporary Redirect
    public static var temporaryRedirect: Self { .init(uncheckedCode: 307, reasonPhrase: "Temporary Redirect") }
    /// 308 Permanent Redirect
    public static var permanentRedirect: Self { .init(uncheckedCode: 308, reasonPhrase: "Permanent Redirect") }

    // MARK: 4xx

    /// 400 Bad Request
    public static var badRequest: Self { .init(uncheckedCode: 400, reasonPhrase: "Bad Request") }
    /// 401 Unauthorized
    public static var unauthorized: Self { .init(uncheckedCode: 401, reasonPhrase: "Unauthorized") }
    /// 403 Forbidden
    public static var forbidden: Self { .init(uncheckedCode: 403, reasonPhrase: "Forbidden") }
    /// 404 Not Found
    public static var notFound: Self { .init(uncheckedCode: 404, reasonPhrase: "Not Found") }
    /// 405 Method Not Allowed
    public static var methodNotAllowed: Self { .init(uncheckedCode: 405, reasonPhrase: "Method Not Allowed") }
    /// 406 Not Acceptable
    public static var notAcceptable: Self { .init(uncheckedCode: 406, reasonPhrase: "Not Acceptable") }
    /// 407 Proxy Authentication Required
    public static var proxyAuthenticationRequired: Self { .init(uncheckedCode: 407, reasonPhrase: "Proxy Authentication Required") }
    /// 408 Request Timeout
    public static var requestTimeout: Self { .init(uncheckedCode: 408, reasonPhrase: "Request Timeout") }
    /// 409 Conflict
    public static var conflict: Self { .init(uncheckedCode: 409, reasonPhrase: "Conflict") }
    /// 410 Gone
    public static var gone: Self { .init(uncheckedCode: 410, reasonPhrase: "Gone") }
    /// 411 Length Required
    public static var lengthRequired: Self { .init(uncheckedCode: 411, reasonPhrase: "Length Required") }
    /// 412 Precondition Failed
    public static var preconditionFailed: Self { .init(uncheckedCode: 412, reasonPhrase: "Precondition Failed") }
    /// 413 Content Too Large
    public static var contentTooLarge: Self { .init(uncheckedCode: 413, reasonPhrase: "Content Too Large") }
    /// 414 URI Too Long
    public static var uriTooLong: Self { .init(uncheckedCode: 414, reasonPhrase: "URI Too Long") }
    /// 415 Unsupported Media Type
    public static var unsupportedMediaType: Self { .init(uncheckedCode: 415, reasonPhrase: "Unsupported Media Type") }
    /// 416 Range Not Satisfiable
    public static var rangeNotSatisfiable: Self { .init(uncheckedCode: 416, reasonPhrase: "Range Not Satisfiable") }
    /// 417 Expectation Failed
    public static var expectationFailed: Self { .init(uncheckedCode: 417, reasonPhrase: "Expectation Failed") }
    /// 421 Misdirected Request
    public static var misdirectedRequest: Self { .init(uncheckedCode: 421, reasonPhrase: "Misdirected Request") }
    /// 422 Unprocessable Content
    public static var unprocessableContent: Self { .init(uncheckedCode: 422, reasonPhrase: "Unprocessable Content") }
    /// 425 Too Early
    public static var tooEarly: Self { .init(uncheckedCode: 425, reasonPhrase: "Too Early") }
    /// 426 Upgrade Required
    public static var upgradeRequired: Self { .init(uncheckedCode: 426, reasonPhrase: "Upgrade Required") }
    /// 428 Precondition Required
    public static var preconditionRequired: Self { .init(uncheckedCode: 428, reasonPhrase: "Precondition Required") }
    /// 429 Too Many Requests
    public static var tooManyRequests: Self { .init(uncheckedCode: 429, reasonPhrase: "Too Many Requests") }
    /// 431 Request Header Fields Too Large
    public static var requestHeaderFieldsTooLarge: Self { .init(uncheckedCode: 431, reasonPhrase: "Request Header Fields Too Large") }
    /// 451 Unavailable For Legal Reasons
    public static var unavailableForLegalReasons: Self { .init(uncheckedCode: 451, reasonPhrase: "Unavailable For Legal Reasons") }

    // MARK: 5xx

    /// 500 Internal Server Error
    public static var internalServerError: Self { .init(uncheckedCode: 500, reasonPhrase: "Internal Server Error") }
    /// 501 Not Implemented
    public static var notImplemented: Self { .init(uncheckedCode: 501, reasonPhrase: "Not Implemented") }
    /// 502 Bad Gateway
    public static var badGateway: Self { .init(uncheckedCode: 502, reasonPhrase: "Bad Gateway") }
    /// 503 Service Unavailable
    public static var serviceUnavailable: Self { .init(uncheckedCode: 503, reasonPhrase: "Service Unavailable") }
    /// 504 Gateway Timeout
    public static var gatewayTimeout: Self { .init(uncheckedCode: 504, reasonPhrase: "Gateway Timeout") }
    /// 505 HTTP Version Not Supported
    public static var httpVersionNotSupported: Self { .init(uncheckedCode: 505, reasonPhrase: "HTTP Version Not Supported") }
    /// 511 Network Authentication Required
    public static var networkAuthenticationRequired: Self { .init(uncheckedCode: 511, reasonPhrase: "Network Authentication Required") }
}
