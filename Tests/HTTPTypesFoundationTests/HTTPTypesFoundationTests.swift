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

import HTTPTypes
import HTTPTypesFoundation
import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class HTTPTypesFoundationTests: XCTestCase {
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
        XCTAssertEqual(request5.path, "/")
        XCTAssertNil(request5.url)
    }

    func testRequestToFoundation() throws {
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

        let urlRequest = try XCTUnwrap(URLRequest(httpRequest: request))
        XCTAssertEqual(urlRequest.url, URL(string: "https://www.example.com/")!)
        XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "aCcEpT"), "*/*")
        XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "Accept-Encoding"), "gzip, br")
        XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "cookie"), "a=b; c=d")
    }

    func testRequestFromFoundation() throws {
        var urlRequest = URLRequest(url: URL(string: "https://www.example.com/")!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bar", forHTTPHeaderField: "X-Foo")

        let request = try XCTUnwrap(urlRequest.httpRequest)
        XCTAssertEqual(request.method, .post)
        XCTAssertEqual(request.scheme, "https")
        XCTAssertEqual(request.authority, "www.example.com")
        XCTAssertEqual(request.path, "/")
        XCTAssertEqual(request.headerFields[.init("x-foo")!], "Bar")
    }

    func testResponseToFoundation() throws {
        let response = HTTPResponse(
            status: .ok,
            headerFields: [
                .server: "HTTPServer/1.0",
            ]
        )

        let urlResponse = try XCTUnwrap(HTTPURLResponse(httpResponse: response, url: URL(string: "https://www.example.com/")!))
        XCTAssertEqual(urlResponse.statusCode, 200)
        XCTAssertEqual(urlResponse.value(forHTTPHeaderField: "Server"), "HTTPServer/1.0")
    }

    func testResponseFromFoundation() throws {
        let urlResponse = HTTPURLResponse(
            url: URL(string: "https://www.example.com/")!, statusCode: 204, httpVersion: nil,
            headerFields: [
                "X-Emoji": "ð",
            ]
        )!

        let response = try XCTUnwrap(urlResponse.httpResponse)
        XCTAssertEqual(response.status, .noContent)
        XCTAssertEqual(response.headerFields[.init("X-EMOJI")!], "😀")
    }
}
