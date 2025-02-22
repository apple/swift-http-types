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
import XCTest

extension HTTPField.Name {
    static let acceptEncodingLower = HTTPField.Name("accept-encoding")!
    static let acceptEncodingMixed = HTTPField.Name("aCcEpT-eNcOdInG")!
    static let acceptEncodingUpper = HTTPField.Name("ACCEPT-ENCODING")!
    static let acceptLanguageUpper = HTTPField.Name("ACCEPT-LANGUAGE")!
}

final class HTTPTypesTests: XCTestCase {
    func testFields() {
        var fields = HTTPFields()
        fields[.acceptEncoding] = "gzip"
        fields.append(HTTPField(name: .acceptEncodingLower, value: "br"))
        fields.insert(HTTPField(name: .acceptEncodingMixed, value: "deflate"), at: 1)

        XCTAssertEqual(fields[.acceptEncoding], "gzip, deflate, br")
        XCTAssertEqual(fields[values: .acceptEncodingUpper].count, 3)
    }

    func testFieldValue() {
        XCTAssertEqual(HTTPField(name: .accept, value: "   \n 😀 \t ").value, "😀")
        XCTAssertEqual(HTTPField(name: .accept, value: " a 😀 \t\n b \t \r ").value, "a 😀 \t  b")
        XCTAssertEqual(HTTPField(name: .accept, value: "").value, "")
        XCTAssertFalse(HTTPField.isValidValue(" "))
        XCTAssertEqual(HTTPField(name: .accept, lenientValue: "  \r\n\0\t ".utf8).value, "     \t ")
    }

    func testRequest() {
        var request1 = HTTPRequest(method: .get, scheme: "https", authority: "www.example.com", path: "/")
        request1.headerFields = [
            .acceptLanguage: "en"
        ]
        var request2 = HTTPRequest(
            method: HTTPRequest.Method("GET")!,
            scheme: "https",
            authority: "www.example.com",
            path: "/"
        )
        request2.headerFields.append(HTTPField(name: .acceptLanguageUpper, value: "en"))

        XCTAssertEqual(request2.method, .get)
        XCTAssertEqual(request1, request2)
    }

    func testResponse() {
        var response1 = HTTPResponse(status: 200)
        response1.headerFields = [
            .server: "HTTPServer/1.0",
            .contentLength: "0",
        ]

        var response2 = response1
        response2.status = .movedPermanently
        response2.headerFields.append(HTTPField(name: .location, value: "https://www.example.com/new"))

        XCTAssertEqual(response1.status, .ok)
        XCTAssertEqual(response1.status.kind, .successful)
        XCTAssertEqual(response1.headerFields.count, 2)

        XCTAssertEqual(response2.status, 301)
        XCTAssertEqual(response2.status.kind, .redirection)
        XCTAssertEqual(response2.headerFields.count, 3)
        XCTAssertEqual(response2.headerFields[.server], "HTTPServer/1.0")
    }

    func testComparison() {
        let fields1: HTTPFields = [
            .acceptEncoding: "br",
            .acceptEncoding: "gzip",
            .accept: "*/*",
        ]
        XCTAssertNotEqual(fields1, [:])

        let fields2: HTTPFields = [
            .acceptEncoding: "br",
            .acceptEncoding: "gzip",
            .accept: "*/*",
        ]
        XCTAssertEqual(fields1, fields2)

        let fields3: HTTPFields = [
            .acceptEncoding: "br",
            .accept: "*/*",
            .acceptEncoding: "gzip",
        ]
        XCTAssertEqual(fields1, fields3)

        let fields4: HTTPFields = [
            .acceptEncoding: "br",
            .accept: "*/*",
        ]
        XCTAssertNotEqual(fields1, fields4)

        let fields5: HTTPFields = [
            .acceptEncoding: "gzip",
            .acceptEncoding: "br",
            .accept: "*/*",
        ]
        XCTAssertNotEqual(fields1, fields5)

        let fields6: HTTPFields = [
            .acceptEncoding: "gzip",
            .acceptEncoding: "br",
            .acceptLanguage: "en",
        ]
        XCTAssertNotEqual(fields1, fields6)
    }

    func testSendable() {
        func isSendable(_ value: some Sendable) -> Bool { true }
        func isSendable(_ value: Any) -> Bool { false }

        let field: HTTPField = .init(name: .userAgent, value: "")
        let indexingStrategy: HTTPField.DynamicTableIndexingStrategy = field.indexingStrategy
        let name: HTTPField.Name = field.name
        let fields: HTTPFields = [:]
        let request: HTTPRequest = .init(method: .post, scheme: nil, authority: nil, path: nil)
        let method: HTTPRequest.Method = request.method
        let requestPseudoHeaderFields: HTTPRequest.PseudoHeaderFields = request.pseudoHeaderFields
        let response: HTTPResponse = .init(status: .ok)
        let status: HTTPResponse.Status = response.status
        let responsePseudoHeaderFields: HTTPResponse.PseudoHeaderFields = response.pseudoHeaderFields

        XCTAssertTrue(isSendable(field))
        XCTAssertTrue(isSendable(indexingStrategy))
        XCTAssertTrue(isSendable(name))
        XCTAssertTrue(isSendable(fields))
        XCTAssertTrue(isSendable(request))
        XCTAssertTrue(isSendable(method))
        XCTAssertTrue(isSendable(requestPseudoHeaderFields))
        XCTAssertTrue(isSendable(response))
        XCTAssertTrue(isSendable(status))
        XCTAssertTrue(isSendable(responsePseudoHeaderFields))
    }

    func testRequestCoding() throws {
        let request = HTTPRequest(
            method: .put,
            scheme: "https",
            authority: "www.example.com",
            path: "/upload",
            headerFields: [
                .acceptEncoding: "br",
                .acceptEncoding: "gzip",
                .contentLength: "1024",
            ]
        )
        let encoded = try JSONEncoder().encode(request)

        let json = try JSONSerialization.jsonObject(with: encoded)
        XCTAssertEqual(
            json as? NSDictionary,
            [
                "pseudoHeaderFields": [
                    ["name": ":method", "value": "PUT"],
                    ["name": ":scheme", "value": "https"],
                    ["name": ":authority", "value": "www.example.com"],
                    ["name": ":path", "value": "/upload"],
                ],
                "headerFields": [
                    ["name": "Accept-Encoding", "value": "br"],
                    ["name": "Accept-Encoding", "value": "gzip"],
                    ["name": "Content-Length", "value": "1024"],
                ],
            ]
        )

        let decoded = try JSONDecoder().decode(HTTPRequest.self, from: encoded)
        XCTAssertEqual(request, decoded)
    }

    func testResponseCoding() throws {
        var response = HTTPResponse(
            status: .noContent,
            headerFields: [
                .server: "HTTPServer/1.0"
            ]
        )
        response.headerFields[0].indexingStrategy = .prefer
        let encoded = try JSONEncoder().encode(response)

        let json = try JSONSerialization.jsonObject(with: encoded)
        XCTAssertEqual(
            json as? NSDictionary,
            [
                "pseudoHeaderFields": [
                    ["name": ":status", "value": "204"]
                ],
                "reasonPhrase": "No Content",
                "headerFields": [
                    ["name": "Server", "value": "HTTPServer/1.0", "indexingStrategy": 1]
                ],
            ]
        )

        let decoded = try JSONDecoder().decode(HTTPResponse.self, from: encoded)
        XCTAssertEqual(response, decoded)
    }

    func testRequestParsing() throws {
        let fields = [
            HTTPField(name: HTTPField.Name(parsed: ":method")!, lenientValue: "PUT".utf8),
            HTTPField(name: HTTPField.Name(parsed: ":scheme")!, lenientValue: "https".utf8),
            HTTPField(name: HTTPField.Name(parsed: ":authority")!, lenientValue: "www.example.com".utf8),
            HTTPField(name: HTTPField.Name(parsed: ":path")!, lenientValue: "/upload".utf8),
            HTTPField(name: HTTPField.Name(parsed: "content-length")!, lenientValue: "1024".utf8),
        ]
        let request = try HTTPRequest(parsed: fields)
        XCTAssertEqual(request.method, .put)
        XCTAssertEqual(request.scheme, "https")
        XCTAssertEqual(request.authority, "www.example.com")
        XCTAssertEqual(request.path, "/upload")
        XCTAssertEqual(request.headerFields[.contentLength], "1024")
    }

    func testResponseParsing() throws {
        let fields = [
            HTTPField(name: HTTPField.Name(parsed: ":status")!, lenientValue: "204".utf8),
            HTTPField(name: HTTPField.Name(parsed: "server")!, lenientValue: "HTTPServer/1.0".utf8),
        ]
        let response = try HTTPResponse(parsed: fields)
        XCTAssertEqual(response.status, .noContent)
        XCTAssertEqual(response.headerFields[.server], "HTTPServer/1.0")
    }

    func testTrailerFieldsParsing() throws {
        let fields = [
            HTTPField(name: HTTPField.Name(parsed: "trailer1")!, lenientValue: "value1".utf8),
            HTTPField(name: HTTPField.Name(parsed: "trailer2")!, lenientValue: "value2".utf8),
        ]
        let trailerFields = try HTTPFields(parsedTrailerFields: fields)
        XCTAssertEqual(trailerFields[HTTPField.Name("trailer1")!], "value1")
        XCTAssertEqual(trailerFields[HTTPField.Name("trailer2")!], "value2")
    }

    func testTypeLayoutSize() {
        XCTAssertEqual(MemoryLayout<HTTPRequest>.size, MemoryLayout<AnyObject>.size * 2)
        XCTAssertEqual(MemoryLayout<HTTPResponse>.size, MemoryLayout<AnyObject>.size * 2)
        XCTAssertEqual(MemoryLayout<HTTPFields>.size, MemoryLayout<AnyObject>.size)
    }
}
