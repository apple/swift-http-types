//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

#if !hasFeature(Embedded) || compiler(>=6.4)

struct HTTPParsedFields {
    private var method: ISOLatin1String?
    private var scheme: ISOLatin1String?
    private var authority: ISOLatin1String?
    private var path: ISOLatin1String?
    private var extendedConnectProtocol: ISOLatin1String?
    private var status: ISOLatin1String?

    private var contentLength: ISOLatin1String?
    private var contentDisposition: ISOLatin1String?
    private var location: ISOLatin1String?

    private var fields: HTTPFields

    enum ParsingError: Error {
        case invalidName
        case invalidPseudoName
        case invalidPseudoValue
        case multiplePseudo
        case pseudoNotFirst

        case requestWithoutMethod
        case invalidMethod
        case requestWithResponsePseudo

        case responseWithoutStatus
        case invalidStatus
        case responseWithRequestPseudo

        case trailerFieldsWithPseudo

        case multipleContentLength
        case multipleContentDisposition
        case multipleLocation
    }

    init() {
        self.fields = .init()
    }

    init(parsed: [HTTPFields.Element]) throws {
        self.fields = .init()
        self.fields.reserveCapacity(parsed.count)
        for field in parsed {
            try self.add(field: field)
        }
    }

    mutating func add(field: HTTPField) throws {
        if field.name.isPseudo {
            if !self.fields.isEmpty {
                throw ParsingError.pseudoNotFirst
            }
            switch field.name {
            case .method:
                if self.method != nil {
                    throw ParsingError.multiplePseudo
                }
                self.method = field.rawValue
            case .scheme:
                if self.scheme != nil {
                    throw ParsingError.multiplePseudo
                }
                self.scheme = field.rawValue
            case .authority:
                if self.authority != nil {
                    throw ParsingError.multiplePseudo
                }
                self.authority = field.rawValue
            case .path:
                if self.path != nil {
                    throw ParsingError.multiplePseudo
                }
                self.path = field.rawValue
            case .protocol:
                if self.extendedConnectProtocol != nil {
                    throw ParsingError.multiplePseudo
                }
                self.extendedConnectProtocol = field.rawValue
            case .status:
                if self.status != nil {
                    throw ParsingError.multiplePseudo
                }
                self.status = field.rawValue
            default:
                throw ParsingError.invalidPseudoName
            }
        } else {
            switch field.name {
            case .contentLength:
                if let contentLength = self.contentLength, contentLength != field.rawValue {
                    throw ParsingError.multipleContentLength
                }
                self.contentLength = field.rawValue
            case .contentDisposition:
                if let contentDisposition = self.contentDisposition, contentDisposition != field.rawValue {
                    throw ParsingError.multipleContentDisposition
                }
                self.contentDisposition = field.rawValue
            case .location:
                if let location = self.location, location != field.rawValue {
                    throw ParsingError.multipleLocation
                }
                self.location = field.rawValue
            default:
                break
            }
            self.fields.append(field)
        }
    }

    var request: HTTPRequest {
        get throws {
            guard let method = self.method else {
                throw ParsingError.requestWithoutMethod
            }
            guard let requestMethod = HTTPRequest.Method(method._storage) else {
                throw ParsingError.invalidMethod
            }
            if self.status != nil {
                throw ParsingError.requestWithResponsePseudo
            }
            var request = HTTPRequest(
                method: requestMethod,
                scheme: self.scheme,
                authority: self.authority,
                path: self.path,
                headerFields: self.fields
            )
            if let extendedConnectProtocol = self.extendedConnectProtocol {
                request.pseudoHeaderFields.extendedConnectProtocol = HTTPField(
                    name: .protocol,
                    uncheckedValue: extendedConnectProtocol
                )
            }
            return request
        }
    }

    var response: HTTPResponse {
        get throws {
            guard let statusString = self.status?._storage else {
                throw ParsingError.responseWithoutStatus
            }
            if self.method != nil || self.scheme != nil || self.authority != nil || self.path != nil
                || self.extendedConnectProtocol != nil
            {
                throw ParsingError.responseWithRequestPseudo
            }
            if !HTTPResponse.Status.isValidStatus(statusString) {
                throw ParsingError.invalidStatus
            }
            return HTTPResponse(status: .init(code: Int(statusString)!), headerFields: self.fields)
        }
    }

    var trailerFields: HTTPFields {
        get throws {
            if self.method != nil || self.scheme != nil || self.authority != nil || self.path != nil
                || self.extendedConnectProtocol != nil || self.status != nil
            {
                throw ParsingError.trailerFieldsWithPseudo
            }
            return self.fields
        }
    }
}

extension HTTPRequest {
    fileprivate init(
        method: Method,
        scheme: ISOLatin1String?,
        authority: ISOLatin1String?,
        path: ISOLatin1String?,
        headerFields: HTTPFields
    ) {
        let methodField = HTTPField(name: .method, uncheckedValue: ISOLatin1String(unchecked: method.rawValue))
        let schemeField = scheme.map { HTTPField(name: .scheme, uncheckedValue: $0) }
        let authorityField = authority.map { HTTPField(name: .authority, uncheckedValue: $0) }
        let pathField = path.map { HTTPField(name: .path, uncheckedValue: $0) }
        self.pseudoHeaderFields = .init(
            method: methodField,
            scheme: schemeField,
            authority: authorityField,
            path: pathField
        )
        self.headerFields = headerFields
    }
}

@available(HTTPTypes 1.2, *)
extension HTTPRequest {
    /// Create an HTTP request with an array of parsed `HTTPField`. The fields must include the
    /// necessary request pseudo header fields.
    ///
    /// - Parameter fields: The array of parsed `HTTPField` produced by HPACK or QPACK decoders
    ///                     used in modern HTTP versions.
    public init(parsed fields: [HTTPField]) throws {
        let parsedFields = try HTTPParsedFields(parsed: fields)
        self = try parsedFields.request
    }
}

@available(HTTPTypes 1.2, *)
extension HTTPResponse {
    /// Create an HTTP response with an array of parsed `HTTPField`. The fields must include the
    /// necessary response pseudo header fields.
    ///
    /// - Parameter fields: The array of parsed `HTTPField` produced by HPACK or QPACK decoders
    ///                     used in modern HTTP versions.
    public init(parsed fields: [HTTPField]) throws {
        let parsedFields = try HTTPParsedFields(parsed: fields)
        self = try parsedFields.response
    }
}

@available(HTTPTypes 1.2, *)
extension HTTPFields {
    /// Create an HTTP trailer fields with an array of parsed `HTTPField`. The fields must not
    /// include any pseudo header fields.
    ///
    /// - Parameter fields: The array of parsed `HTTPField` produced by HPACK or QPACK decoders
    ///                     used in modern HTTP versions.
    public init(parsedTrailerFields fields: [HTTPField]) throws {
        let parsedFields = try HTTPParsedFields(parsed: fields)
        self = try parsedFields.trailerFields
    }
}

#endif
