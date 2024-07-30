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
import HTTPTypesFoundation
import Testing
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

@Suite("HTTPTypesFoundationTests")
struct HTTPTypesFoundationTests {
    @Test("Request URL parses correctly")
    func requestURLParsing() {
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
        #expect(request5.path == "/")
        #expect(request5.url == nil)
    }

    @Test("Request converts to Foundation")
    func requestToFoundation() throws {
        let request = HTTPRequest(
            method: .get, scheme: "https", authority: "www.example.com", path: "/",
            headerFields: [
                .accept: "*/*",
                .acceptEncoding: "gzip",
                .acceptEncoding: "br",
                .cookie: "a=b",
                .cookie: "c=d",
            ]
        )

        let urlRequest = try #require(URLRequest(httpRequest: request))
        #expect(urlRequest.url == URL(string: "https://www.example.com/")!)
        #expect(urlRequest.value(forHTTPHeaderField: "aCcEpT") == "*/*")
        #expect(urlRequest.value(forHTTPHeaderField: "Accept-Encoding") == "gzip, br")
        #expect(urlRequest.value(forHTTPHeaderField: "cookie") == "a=b; c=d")
    }

    @Test("Request creates from Foundation")
    func requestFromFoundation() throws {
        var urlRequest = URLRequest(url: URL(string: "https://www.example.com/")!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bar", forHTTPHeaderField: "X-Foo")

        let request = try #require(urlRequest.httpRequest)
        #expect(request.method == .post)
        #expect(request.scheme == "https")
        #expect(request.authority == "www.example.com")
        #expect(request.path == "/")
        #expect(request.headerFields[.init("x-foo")!] == "Bar")
    }

    @Test("Response converts to Foundation")
    func responseToFoundation() throws {
        let response = HTTPResponse(
            status: .ok,
            headerFields: [
                .server: "HTTPServer/1.0",
            ]
        )

        let urlResponse = try #require(HTTPURLResponse(httpResponse: response, url: URL(string: "https://www.example.com/")!))
        #expect(urlResponse.statusCode == 200)
        #expect(urlResponse.value(forHTTPHeaderField: "Server") == "HTTPServer/1.0")
    }

    @Test("Response creates from Foundation")
    func responseFromFoundation() throws {
        let urlResponse = HTTPURLResponse(
            url: URL(string: "https://www.example.com/")!, statusCode: 204, httpVersion: nil,
            headerFields: [
                "X-Emoji": "ð",
            ]
        )!

        let response = try #require(urlResponse.httpResponse)
        #expect(response.status == .noContent)
        #expect(response.headerFields[.init("X-EMOJI")!] == "😀")
    }
}
