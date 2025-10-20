//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import HTTPTypes
import XCTest

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

final class HTTPTypesURLTests: XCTestCase {
    func testRequestURLParsing() {
        let request1 = HTTPRequest(url: URL(string: "h://a")!)
        XCTAssertEqual(request1.scheme, "h")
        XCTAssertEqual(request1.authority, "a")
        XCTAssertEqual(request1.path, "/")
        XCTAssertEqual(request1.url?.absoluteString, "h://a/")

        let request2 = HTTPRequest(url: URL(string: "h://a:4?")!)
        XCTAssertEqual(request2.scheme, "h")
        XCTAssertEqual(request2.authority, "a:4")
        XCTAssertEqual(request2.path, "/?")
        XCTAssertEqual(request2.url?.absoluteString, "h://a:4/?")

        let request3 = HTTPRequest(url: URL(string: "h://a/")!)
        XCTAssertEqual(request3.scheme, "h")
        XCTAssertEqual(request3.authority, "a")
        XCTAssertEqual(request3.path, "/")
        XCTAssertEqual(request3.url?.absoluteString, "h://a/")

        let request4 = HTTPRequest(url: URL(string: "h://a/p?q#1")!)
        XCTAssertEqual(request4.scheme, "h")
        XCTAssertEqual(request4.authority, "a")
        XCTAssertEqual(request4.path, "/p?q")
        XCTAssertEqual(request4.url?.absoluteString, "h://a/p?q")

        let request5 = HTTPRequest(url: URL(string: "data:,Hello%2C%20World%21")!)
        XCTAssertEqual(request5.scheme, "data")
        XCTAssertNil(request5.authority)
        #if !canImport(FoundationEssentials)
        XCTAssertEqual(request5.path, "/")
        #else  // !canImport(FoundationEssentials)
        XCTAssertEqual(request5.path, ",Hello%2C%20World%21")
        #endif  // !canImport(FoundationEssentials)
        XCTAssertNil(request5.url)
    }

    func testRequestURLAuthorityParsing() {
        let request1 = HTTPRequest(url: URL(string: "https://[::1]")!)
        XCTAssertEqual(request1.scheme, "https")
        XCTAssertEqual(request1.authority, "[::1]")
        XCTAssertEqual(request1.path, "/")
        XCTAssertEqual(request1.url?.absoluteString, "https://[::1]/")

        let request2 = HTTPRequest(url: URL(string: "https://[::1]:443")!)
        XCTAssertEqual(request2.scheme, "https")
        XCTAssertEqual(request2.authority, "[::1]:443")
        XCTAssertEqual(request2.path, "/")
        XCTAssertEqual(request2.url?.absoluteString, "https://[::1]:443/")

        let request3 = HTTPRequest(url: URL(string: "https://127.0.0.1")!)
        XCTAssertEqual(request3.scheme, "https")
        XCTAssertEqual(request3.authority, "127.0.0.1")
        XCTAssertEqual(request3.path, "/")
        XCTAssertEqual(request3.url?.absoluteString, "https://127.0.0.1/")

        let request4 = HTTPRequest(url: URL(string: "https://127.0.0.1:443")!)
        XCTAssertEqual(request4.scheme, "https")
        XCTAssertEqual(request4.authority, "127.0.0.1:443")
        XCTAssertEqual(request4.path, "/")
        XCTAssertEqual(request4.url?.absoluteString, "https://127.0.0.1:443/")
    }

    func testNilRequestURL() {
        let request1 = HTTPRequest(
            method: .connect,
            scheme: "https",
            authority: "www.example.com:443",
            path: "www.example.com:443"
        )
        XCTAssertNil(request1.url)

        var request2 = HTTPRequest(
            method: .connect,
            scheme: "https",
            authority: "www.example.com",
            path: "/"
        )
        request2.extendedConnectProtocol = "websocket"
        XCTAssertEqual(request2.url?.absoluteString, "https://www.example.com/")

        let request3 = HTTPRequest(method: .options, scheme: "https", authority: "www.example.com", path: "*")
        XCTAssertNil(request3.url)

        let request4 = HTTPRequest(method: .options, scheme: "https", authority: "www.example.com", path: "/")
        XCTAssertEqual(request4.url?.absoluteString, "https://www.example.com/")
    }
}
