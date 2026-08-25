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
    @ValidatedField(.singular, error: .multiplePseudo)
    private var method
    @ValidatedField(.singular, error: .multiplePseudo)
    private var scheme
    @ValidatedField(.singular, error: .multiplePseudo)
    private var authority
    @ValidatedField(.singular, error: .multiplePseudo)
    private var path
    @ValidatedField(.singular, error: .multiplePseudo)
    private var extendedConnectProtocol
    @ValidatedField(.singular, error: .multiplePseudo)
    private var status

    @ValidatedField(.distinct, error: .multipleContentLength)
    private var contentLength
    @ValidatedField(.distinct, error: .multipleContentDisposition)
    private var contentDisposition
    @ValidatedField(.distinct, error: .multipleLocation)
    private var location

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

            guard let validatedFieldPath = self.validatedField(for: field.name) else {
                throw ParsingError.invalidPseudoName
            }

            try self[keyPath: validatedFieldPath].validateAndSetIfPossible(field.rawValue)
        } else {
            if let validatedFieldPath = self.validatedField(for: field.name) {
                try self[keyPath: validatedFieldPath].validateAndSetIfPossible(field.rawValue)
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

    private func validatedField(for name: HTTPField.Name) -> WritableKeyPath<HTTPParsedFields, ValidatedField>? {
        switch name {
        case .method:
            return \._method
        case .scheme:
            return \._scheme
        case .authority:
            return \._authority
        case .path:
            return \._path
        case .protocol:
            return \._extendedConnectProtocol
        case .status:
            return \._status
        case .contentLength:
            return \._contentLength
        case .contentDisposition:
            return \._contentDisposition
        case .location:
            return \._location
        default:
            return nil
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

extension HTTPParsedFields {
    @propertyWrapper
    fileprivate struct ValidatedField {
        enum Validation {
            case singular, distinct
        }

        private let validation: Validation
        private let error: HTTPParsedFields.ParsingError
        private var currentValue: ISOLatin1String?

        var wrappedValue: ISOLatin1String? {
            get {
                return self.currentValue
            }
        }

        init(_ validation: Validation, error: HTTPParsedFields.ParsingError) {
            self.validation = validation
            self.error = error
        }

        mutating func validateAndSetIfPossible(_ value: ISOLatin1String) throws {
            switch self.validation {
            case .singular:
                if self.currentValue != nil {
                    throw self.error
                }

                self.currentValue = value
            case .distinct:
                guard let currentValue = self.currentValue else {
                    self.currentValue = value
                    return
                }

                if currentValue.string != value.string {
                    throw self.error
                }
            }
        }
    }
}

#endif
