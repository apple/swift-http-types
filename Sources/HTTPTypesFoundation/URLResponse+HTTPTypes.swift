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

import Foundation
import HTTPTypes

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

#if !os(WASI)

extension HTTPURLResponse {
    /// Create an `HTTPURLResponse` from an `HTTPResponse`.
    /// - Parameter httpResponse: The HTTP response to convert from.
    /// - Parameter url: The URL of the response.
    public convenience init?(httpResponse: HTTPResponse, url: URL) {
        var combinedFields = [HTTPField.Name: String](minimumCapacity: httpResponse.headerFields.count)
        for field in httpResponse.headerFields {
            if let existingValue = combinedFields[field.name] {
                combinedFields[field.name] = "\(existingValue), \(field.isoLatin1Value)"
            } else {
                combinedFields[field.name] = field.isoLatin1Value
            }
        }
        var headerFields = [String: String](minimumCapacity: combinedFields.count)
        for (name, value) in combinedFields {
            headerFields[name.rawName] = value
        }
        self.init(url: url, statusCode: httpResponse.status.code, httpVersion: "HTTP/1.1", headerFields: headerFields)
    }

    /// Convert the `HTTPURLResponse` into an `HTTPResponse`.
    public var httpResponse: HTTPResponse? {
        guard (0...999).contains(self.statusCode) else {
            return nil
        }
        var response = HTTPResponse(status: .init(code: self.statusCode))
        if let fields = self.allHeaderFields as? [String: String] {
            response.headerFields.reserveCapacity(fields.count)
            for (name, value) in fields {
                if let name = HTTPField.Name(name) {
                    response.headerFields.append(HTTPField(name: name, isoLatin1Value: value))
                }
            }
        }
        return response
    }
}

#endif
