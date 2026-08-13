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
import Testing

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

@Suite struct HTTPTypesURLTests {
    @Test func requestURLParsing() {
        let request1 = HTTPRequest(url: URL(string: "h://a")!)
        #expect(request1.scheme == "h")
        #expect(request1.authority == "a")
        #expect(request1.path == "/")
        #expect(request1.url?.absoluteString == "h://a/")

        let request2 = HTTPRequest(url: URL(string: "h://a:4?")!)
        #expect(request2.scheme == "h")
        #expect(request2.authority == "a:4")
        #expect(request2.path == "/?")
        #expect(request2.url?.absoluteString == "h://a:4/?")

        let request3 = HTTPRequest(url: URL(string: "h://a/")!)
        #expect(request3.scheme == "h")
        #expect(request3.authority == "a")
        #expect(request3.path == "/")
        #expect(request3.url?.absoluteString == "h://a/")

        let request4 = HTTPRequest(url: URL(string: "h://a/p?q#1")!)
        #expect(request4.scheme == "h")
        #expect(request4.authority == "a")
        #expect(request4.path == "/p?q")
        #expect(request4.url?.absoluteString == "h://a/p?q")

        let request5 = HTTPRequest(url: URL(string: "data:,Hello%2C%20World%21")!)
        #expect(request5.scheme == "data")
        #expect(request5.authority == nil)
        #if !canImport(FoundationEssentials)
        #expect(request5.path == "/")
        #else  // !canImport(FoundationEssentials)
        #expect(request5.path == ",Hello%2C%20World%21")
        #endif  // !canImport(FoundationEssentials)
        #expect(request5.url == nil)
    }

    @Test func requestURLAuthorityParsing() {
        let request1 = HTTPRequest(url: URL(string: "https://[::1]")!)
        #expect(request1.scheme == "https")
        #expect(request1.authority == "[::1]")
        #expect(request1.path == "/")
        #expect(request1.url?.absoluteString == "https://[::1]/")

        let request2 = HTTPRequest(url: URL(string: "https://[::1]:443")!)
        #expect(request2.scheme == "https")
        #expect(request2.authority == "[::1]:443")
        #expect(request2.path == "/")
        #expect(request2.url?.absoluteString == "https://[::1]:443/")

        let request3 = HTTPRequest(url: URL(string: "https://127.0.0.1")!)
        #expect(request3.scheme == "https")
        #expect(request3.authority == "127.0.0.1")
        #expect(request3.path == "/")
        #expect(request3.url?.absoluteString == "https://127.0.0.1/")

        let request4 = HTTPRequest(url: URL(string: "https://127.0.0.1:443")!)
        #expect(request4.scheme == "https")
        #expect(request4.authority == "127.0.0.1:443")
        #expect(request4.path == "/")
        #expect(request4.url?.absoluteString == "https://127.0.0.1:443/")
    }

    @Test func nilRequestURL() {
        let request1 = HTTPRequest(
            method: .connect,
            scheme: "https",
            authority: "www.example.com:443",
            path: "www.example.com:443"
        )
        #expect(request1.url == nil)

        var request2 = HTTPRequest(
            method: .connect,
            scheme: "https",
            authority: "www.example.com",
            path: "/"
        )
        request2.extendedConnectProtocol = "websocket"
        #expect(request2.url?.absoluteString == "https://www.example.com/")

        let request3 = HTTPRequest(method: .options, scheme: "https", authority: "www.example.com", path: "*")
        #expect(request3.url == nil)

        let request4 = HTTPRequest(method: .options, scheme: "https", authority: "www.example.com", path: "/")
        #expect(request4.url?.absoluteString == "https://www.example.com/")
    }
}
