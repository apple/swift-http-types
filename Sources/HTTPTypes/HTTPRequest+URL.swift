//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift open source project
//
// Copyright (c) 2023-2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else  // canImport(FoundationEssentials)
import Foundation
#if canImport(CoreFoundation)
import CoreFoundation
#endif  // canImport(CoreFoundation)
#endif  // canImport(FoundationEssentials)

extension HTTPRequest {
    /// The URL of the request synthesized from the scheme, authority, and path pseudo header
    /// fields.
    public var url: URL? {
        get {
            if (self.method == .connect && self.extendedConnectProtocol == nil)
                || (self.method == .options && self.path == "*")
            {
                return nil
            }
            if let schemeField = self.pseudoHeaderFields.scheme,
                let authorityField = self.pseudoHeaderFields.authority,
                let pathField = self.pseudoHeaderFields.path
            {
                return schemeField.withUnsafeBytesOfValue { scheme in
                    authorityField.withUnsafeBytesOfValue { authority in
                        pathField.withUnsafeBytesOfValue { path in
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
                self.pseudoHeaderFields.scheme = nil
                self.pseudoHeaderFields.authority = nil
                self.pseudoHeaderFields.path = nil
            }
        }
    }

    /// Create an HTTP request with a method, a URL, and header fields.
    /// - Parameters:
    ///   - method: The request method, defaults to GET.
    ///   - url: The URL to populate the scheme, authority, and path pseudo header fields.
    ///   - headerFields: The request header fields.
    public init(method: Method = .get, url: URL, headerFields: HTTPFields = [:]) {
        let (scheme, authority, path) = url.httpRequestComponents
        let schemeString = String(decoding: scheme, as: UTF8.self)
        let authorityString = authority.map { String(decoding: $0, as: UTF8.self) }
        let pathString = String(decoding: path, as: UTF8.self)

        self.init(
            method: method,
            scheme: schemeString,
            authority: authorityString,
            path: pathString,
            headerFields: headerFields
        )
    }
}

extension URL {
    fileprivate init?(scheme: some Collection<UInt8>, authority: some Collection<UInt8>, path: some Collection<UInt8>) {
        var buffer = [UInt8]()
        buffer.reserveCapacity(scheme.count + 3 + authority.count + path.count)
        buffer.append(contentsOf: scheme)
        buffer.append(contentsOf: "://".utf8)
        buffer.append(contentsOf: authority)
        buffer.append(contentsOf: path)

        #if !canImport(FoundationEssentials) && canImport(CoreFoundation)
        if let url = buffer.withUnsafeBytes({ buffer in
            CFURLCreateAbsoluteURLWithBytes(
                kCFAllocatorDefault,
                buffer.baseAddress,
                buffer.count,
                CFStringBuiltInEncodings.ASCII.rawValue,
                nil,
                false
            ).map { unsafeBitCast($0, to: NSURL.self) as URL }
        }) {
            self = url
        } else {
            return nil
        }
        #else  // !canImport(FoundationEssentials) && canImport(CoreFoundation)
        // This initializer does not preserve WHATWG URLs
        self.init(string: String(decoding: buffer, as: UTF8.self))
        #endif  // !canImport(FoundationEssentials) && canImport(CoreFoundation)
    }

    fileprivate var httpRequestComponents: (scheme: [UInt8], authority: [UInt8]?, path: [UInt8]) {
        #if !canImport(FoundationEssentials) && canImport(CoreFoundation)
        // CFURL parser based on byte ranges does not unnecessarily percent-encode WHATWG URL
        let url = unsafeBitCast(self.absoluteURL as NSURL, to: CFURL.self)
        let length = CFURLGetBytes(url, nil, 0)
        return withUnsafeTemporaryAllocation(of: UInt8.self, capacity: length) { buffer in
            CFURLGetBytes(url, buffer.baseAddress, buffer.count)

            func unionRange(_ first: CFRange, _ second: CFRange) -> CFRange {
                if first.location == kCFNotFound { return second }
                if second.location == kCFNotFound { return first }
                return CFRange(location: first.location, length: second.location + second.length - first.location)
            }

            func bufferSlice(_ range: CFRange) -> UnsafeMutableBufferPointer<UInt8> {
                UnsafeMutableBufferPointer(rebasing: buffer[range.location..<range.location + range.length])
            }

            let schemeRange = CFURLGetByteRangeForComponent(url, .scheme, nil)
            precondition(schemeRange.location != kCFNotFound, "Schemeless URL is not supported")
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
                    path = [UInt8(ascii: "/")]
                } else {
                    let pathBuffer = bufferSlice(requestPathRange)
                    path = [UInt8](unsafeUninitializedCapacity: pathBuffer.count + 1) { buffer, initializedCount in
                        buffer[0] = UInt8(ascii: "/")
                        UnsafeMutableRawBufferPointer(UnsafeMutableBufferPointer(rebasing: buffer[1...])).copyMemory(
                            from: UnsafeRawBufferPointer(pathBuffer)
                        )
                        initializedCount = pathBuffer.count + 1
                    }
                }
            } else {
                path = Array(bufferSlice(requestPathRange))
            }
            return (scheme, authority, path)
        }
        #else  // !canImport(FoundationEssentials) && canImport(CoreFoundation)
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: true),
            let urlString = components.string
        else {
            fatalError("Invalid URL")
        }

        guard let schemeRange = components.rangeOfScheme else {
            fatalError("Schemeless URL is not supported")
        }
        let scheme = Array(urlString[schemeRange].utf8)

        let authority: [UInt8]?
        if let hostRange = components.rangeOfHost {
            let authorityRange =
                if let portRange = components.rangeOfPort {
                    hostRange.lowerBound..<portRange.upperBound
                } else {
                    hostRange
                }
            authority = Array(urlString[authorityRange].utf8)
        } else {
            authority = nil
        }

        let pathRange = components.rangeOfPath
        let queryRange = components.rangeOfQuery
        let requestPathRange: Range<String.Index>?
        if let lowerBound = pathRange?.lowerBound ?? queryRange?.lowerBound,
            let upperBound = queryRange?.upperBound ?? pathRange?.upperBound
        {
            requestPathRange = lowerBound..<upperBound
        } else {
            requestPathRange = nil
        }
        let path: [UInt8]
        if let pathRange, !pathRange.isEmpty, let requestPathRange {
            path = Array(urlString[requestPathRange].utf8)
        } else {
            if let requestPathRange, !requestPathRange.isEmpty {
                path = [UInt8(ascii: "/")] + Array(urlString[requestPathRange].utf8)
            } else {
                path = [UInt8(ascii: "/")]
            }
        }
        return (scheme, authority, path)
        #endif  // !canImport(FoundationEssentials) && canImport(CoreFoundation)
    }
}
