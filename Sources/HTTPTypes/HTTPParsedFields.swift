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

struct HTTPParsedFields {
    private var method: ISOLatin1String?
    private var scheme: ISOLatin1String?
    private var authority: ISOLatin1String?
    private var path: ISOLatin1String?
    private var extendedConnectProtocol: ISOLatin1String?
    private var status: ISOLatin1String?
    private var fields: HTTPFields = .init()

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
            self.fields.append(field)
        }
    }

    private func validateFields() throws {
        guard self.fields[values: .contentLength].allElementsSame else {
            throw ParsingError.multipleContentLength
        }
        guard self.fields[values: .contentDisposition].allElementsSame else {
            throw ParsingError.multipleContentDisposition
        }
        guard self.fields[values: .location].allElementsSame else {
            throw ParsingError.multipleLocation
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
            try self.validateFields()
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
            try self.validateFields()
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
            try self.validateFields()
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

extension Array where Element: Equatable {
    fileprivate var allElementsSame: Bool {
        guard let first = self.first else {
            return true
        }
        return dropFirst().allSatisfy { $0 == first }
    }
}

extension HTTPRequest {
    /// Create an HTTP request with an array of parsed `HTTPField`. The fields must include the
    /// necessary request pseudo header fields.
    ///
    /// - Parameter fields: The array of parsed `HTTPField` produced by HPACK or QPACK decoders
    ///                     used in modern HTTP versions.
    public init(parsed fields: [HTTPField]) throws {
        var parsedFields = HTTPParsedFields()
        for field in fields {
            try parsedFields.add(field: field)
        }
        self = try parsedFields.request
    }
}

extension HTTPResponse {
    /// Create an HTTP response with an array of parsed `HTTPField`. The fields must include the
    /// necessary response pseudo header fields.
    ///
    /// - Parameter fields: The array of parsed `HTTPField` produced by HPACK or QPACK decoders
    ///                     used in modern HTTP versions.
    public init(parsed fields: [HTTPField]) throws {
        var parsedFields = HTTPParsedFields()
        for field in fields {
            try parsedFields.add(field: field)
        }
        self = try parsedFields.response
    }
}

extension HTTPFields {
    /// Create an HTTP trailer fields with an array of parsed `HTTPField`. The fields must not
    /// include any pseudo header fields.
    ///
    /// - Parameter fields: The array of parsed `HTTPField` produced by HPACK or QPACK decoders
    ///                     used in modern HTTP versions.
    public init(parsedTrailerFields fields: [HTTPField]) throws {
        var parsedFields = HTTPParsedFields()
        for field in fields {
            try parsedFields.add(field: field)
        }
        self = try parsedFields.trailerFields
    }
}
