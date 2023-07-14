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
        XCTAssertEqual(fields[raw: .acceptEncodingUpper].count, 3)
    }

    func testFieldValue() {
        XCTAssertEqual(HTTPField(name: .accept, value: "   \n 😀 \t ").value, "😀")
        XCTAssertEqual(HTTPField(name: .accept, value: " a 😀 \t\n b \t \r ").value, "a 😀 \t  b")
        XCTAssertEqual(HTTPField(name: .accept, value: "").value, "")
        XCTAssertFalse(HTTPField.isValidValue(" "))
    }

    func testRequest() {
        var request1 = HTTPRequest(method: .get, scheme: "https", authority: "www.example.com", path: "/")
        request1.headerFields = [
            .acceptLanguage: "en",
        ]
        var request2 = HTTPRequest(method: HTTPRequest.Method("GET")!, scheme: "https", authority: "www.example.com", path: "/")
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
}
