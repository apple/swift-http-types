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

import HTTPTypes
import Foundation
@_implementationOnly import CoreFoundation

public extension HTTPRequest {
    /// The URL of the request synthesized from the scheme, authority, and path pseudo header
    /// fields.
    var url: URL? {
        get {
            if let schemeField,
               let authorityField,
               let pathField {
                return schemeField.withUnsafeValueBytes { scheme in
                    authorityField.withUnsafeValueBytes { authority in
                        pathField.withUnsafeValueBytes { path in
                            URL(scheme: scheme, authority: authority, path: path)
                        }
                    }
                }
            } else {
                return nil
            }
        }
        set {
            if let newValue {
                let (scheme, authority, path) = newValue.httpRequestComponents
                self.scheme = String(decoding: scheme, as: UTF8.self)
                self.authority = authority.map { String(decoding: $0, as: UTF8.self) }
                self.path = String(decoding: path, as: UTF8.self)
            } else {
                schemeField = nil
                authorityField = nil
                pathField = nil
            }
        }
    }

    /// Create an HTTP request with a method, a URL, and header fields.
    /// - Parameters:
    ///   - method: The request method, defaults to GET.
    ///   - url: The URL to populate the scheme, authority, and path pseudo header fields.
    ///   - headerFields: The request header fields.
    init(method: Method = .get, url: URL, headerFields: HTTPFields = [:]) {
        let (scheme, authority, path) = url.httpRequestComponents
        let schemeString = String(decoding: scheme, as: UTF8.self)
        let authorityString = authority.map { String(decoding: $0, as: UTF8.self) }
        let pathString = String(decoding: path, as: UTF8.self)

        self.init(method: method, scheme: schemeString, authority: authorityString, path: pathString, headerFields: headerFields)
    }
}

private extension URL {
    init?(scheme: some Collection<UInt8>, authority: some Collection<UInt8>, path: some Collection<UInt8>) {
        var buffer = [UInt8]()
        buffer.reserveCapacity(scheme.count + 3 + authority.count + path.count)
        buffer.append(contentsOf: scheme)
        buffer.append(contentsOf: "://".utf8)
        buffer.append(contentsOf: authority)
        buffer.append(contentsOf: path)

        if let url = buffer.withUnsafeBytes({ buffer in
            CFURLCreateAbsoluteURLWithBytes(kCFAllocatorDefault, buffer.baseAddress, buffer.count, CFStringBuiltInEncodings.ASCII.rawValue, nil, false).map { unsafeBitCast($0, to: NSURL.self) as URL }
        }) {
            self = url
        } else {
            return nil
        }
    }

    var httpRequestComponents: (scheme: [UInt8], authority: [UInt8]?, path: [UInt8]) {
        // CFURL parser based on byte ranges does not unnecessarily percent-encode WHATWG URL
        let url = unsafeBitCast(self as NSURL, to: CFURL.self)
        let length = CFURLGetBytes(url, nil, 0)
        return withUnsafeTemporaryAllocation(of: UInt8.self, capacity: length) { buffer in
            CFURLGetBytes(url, buffer.baseAddress, buffer.count)

            func unionRange(_ a: CFRange, _ b: CFRange) -> CFRange {
                if a.location == kCFNotFound { return b }
                if b.location == kCFNotFound { return a }
                return CFRange(location: a.location, length: b.location + b.length - a.location )
            }

            func bufferSlice(_ range: CFRange) -> some Collection<UInt8> {
                buffer[range.location..<range.location + range.length]
            }

            let schemeRange = CFURLGetByteRangeForComponent(url, .scheme, nil)
            precondition(schemeRange.location != kCFNotFound, "")
            let scheme = Array(bufferSlice(schemeRange))

            let authority: [UInt8]?
            let hostRange = CFURLGetByteRangeForComponent(url, .host, nil)
            if hostRange.location != kCFNotFound {
                let portRange = CFURLGetByteRangeForComponent(url, .port, nil)
                let authorityRange = unionRange(hostRange, portRange)
                authority = Array(bufferSlice(authorityRange))
            } else {
                authority = nil
            }

            let path: [UInt8]
            let pathRange = CFURLGetByteRangeForComponent(url, .path, nil)
            let queryRange = CFURLGetByteRangeForComponent(url, .query, nil)
            let requestPathRange = unionRange(pathRange, queryRange)
            if pathRange.length == 0 {
                if requestPathRange.length == 0 {
                    path = Array("/".utf8)
                } else {
                    let pathBuffer = bufferSlice(requestPathRange)
                    path = [UInt8](unsafeUninitializedCapacity: pathBuffer.count + 1) { buffer, initializedCount in
                        buffer.initializeElement(at: 0, to: 0x2F)
                        let endIndex = buffer[1...].initialize(fromContentsOf: pathBuffer)
                        initializedCount = buffer.distance(from: buffer.startIndex, to: endIndex)
                    }
                }
            } else {
                path = Array(bufferSlice(requestPathRange))
            }
            return (scheme, authority, path)
        }
    }
}
