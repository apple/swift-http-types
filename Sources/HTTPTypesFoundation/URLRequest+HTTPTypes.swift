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

extension URLRequest {
    /// Create a `URLRequest` from an `HTTPRequest`.
    /// - Parameter httpRequest: The HTTP request to convert from.
    public init?(httpRequest: HTTPRequest) {
        guard let url = httpRequest.url else {
            return nil
        }
        var request = URLRequest(url: url)
        request.httpMethod = httpRequest.method.rawValue
        var combinedFields = [HTTPField.Name: String](minimumCapacity: httpRequest.headerFields.count)
        for field in httpRequest.headerFields {
            if let existingValue = combinedFields[field.name] {
                let separator = field.name == .cookie ? "; " : ", "
                combinedFields[field.name] = "\(existingValue)\(separator)\(field.isoLatin1Value)"
            } else {
                combinedFields[field.name] = field.isoLatin1Value
            }
        }
        var headerFields = [String: String](minimumCapacity: combinedFields.count)
        for (name, value) in combinedFields {
            headerFields[name.rawName] = value
        }
        request.allHTTPHeaderFields = headerFields
        self = request
    }

    /// Convert the `URLRequest` into an `HTTPRequest`.
    public var httpRequest: HTTPRequest? {
        guard let method = HTTPRequest.Method(self.httpMethod ?? "GET"),
            let url
        else {
            return nil
        }
        var request = HTTPRequest(method: method, url: url)
        if let allHTTPHeaderFields = self.allHTTPHeaderFields {
            request.headerFields.reserveCapacity(allHTTPHeaderFields.count)
            for (name, value) in allHTTPHeaderFields {
                if let name = HTTPField.Name(name) {
                    request.headerFields.append(HTTPField(name: name, isoLatin1Value: value))
                }
            }
        }
        return request
    }
}

#endif
