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

import Foundation
import HTTPTypesFoundation
import Testing

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

@Suite struct HTTPTypesFoundationTests {
    @Test func requestToFoundation() throws {
        let request = HTTPRequest(
            method: .get,
            scheme: "https",
            authority: "www.example.com",
            path: "/",
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

    @Test func requestFromFoundation() throws {
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

    @Test func webSocketRequest() throws {
        let urlRequest = URLRequest(url: URL(string: "wss://www.example.com/")!)

        let request = try #require(urlRequest.httpRequest)
        #expect(request.method == .connect)
        #expect(request.scheme == "https")
        #expect(request.authority == "www.example.com")
        #expect(request.path == "/")
        #expect(request.extendedConnectProtocol == "websocket")

        let urlRequestConverted = try #require(URLRequest(httpRequest: request))
        #expect(urlRequestConverted.httpMethod == "GET")
        #expect(urlRequestConverted.url == URL(string: "wss://www.example.com/"))
        #expect(urlRequest == urlRequestConverted)
    }

    @Test func responseToFoundation() throws {
        let response = HTTPResponse(
            status: .ok,
            headerFields: [
                .server: "HTTPServer/1.0"
            ]
        )

        let urlResponse = try #require(
            HTTPURLResponse(httpResponse: response, url: URL(string: "https://www.example.com/")!)
        )
        #expect(urlResponse.statusCode == 200)
        #expect(urlResponse.value(forHTTPHeaderField: "Server") == "HTTPServer/1.0")
    }

    @Test func responseFromFoundation() throws {
        let urlResponse = HTTPURLResponse(
            url: URL(string: "https://www.example.com/")!,
            statusCode: 204,
            httpVersion: nil,
            headerFields: [
                "X-Emoji": "ð"
            ]
        )!

        let response = try #require(urlResponse.httpResponse)
        #expect(response.status == .noContent)
        #expect(response.headerFields[.init("X-EMOJI")!] == "😀")
    }
}
