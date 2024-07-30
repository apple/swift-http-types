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
import Testing

extension HTTPField.Name {
    static let acceptEncodingLower = HTTPField.Name("accept-encoding")!
    static let acceptEncodingMixed = HTTPField.Name("aCcEpT-eNcOdInG")!
    static let acceptEncodingUpper = HTTPField.Name("ACCEPT-ENCODING")!
    static let acceptLanguageUpper = HTTPField.Name("ACCEPT-LANGUAGE")!
}

@Suite("HTTPTypesTests")
struct HTTPTypesTests {
    @Test("Fields behave correctly")
    func fields() {
        var fields = HTTPFields()
        fields[.acceptEncoding] = "gzip"
        fields.append(HTTPField(name: .acceptEncodingLower, value: "br"))
        fields.insert(HTTPField(name: .acceptEncodingMixed, value: "deflate"), at: 1)

        #expect(fields[.acceptEncoding] == "gzip, deflate, br")
        #expect(fields[values: .acceptEncodingUpper].count == 3)
    }

    @Test("Field values are processed correctly")
    func fieldValue() {
        #expect(HTTPField(name: .accept, value: "   \n 😀 \t ").value == "😀")
        #expect(HTTPField(name: .accept, value: " a 😀 \t\n b \t \r ").value == "a 😀 \t  b")
        #expect(HTTPField(name: .accept, value: "").value == "")
        #expect(!HTTPField.isValidValue(" "))
        #expect(HTTPField(name: .accept, lenientValue: "  \r\n\0\t ".utf8).value == "     \t ")
    }

    @Test("Requests are created and compared correctly")
    func request() {
        var request1 = HTTPRequest(method: .get, scheme: "https", authority: "www.example.com", path: "/")
        request1.headerFields = [
            .acceptLanguage: "en",
        ]
        var request2 = HTTPRequest(method: HTTPRequest.Method("GET")!, scheme: "https", authority: "www.example.com", path: "/")
        request2.headerFields.append(HTTPField(name: .acceptLanguageUpper, value: "en"))

        #expect(request2.method == .get)
        #expect(request1 == request2)
    }

    @Test("Responses are created and modified correctly")
    func response() {
        var response1 = HTTPResponse(status: 200)
        response1.headerFields = [
            .server: "HTTPServer/1.0",
            .contentLength: "0",
        ]

        var response2 = response1
        response2.status = .movedPermanently
        response2.headerFields.append(HTTPField(name: .location, value: "https://www.example.com/new"))

        #expect(response1.status == .ok)
        #expect(response1.status.kind == .successful)
        #expect(response1.headerFields.count == 2)

        #expect(response2.status == 301)
        #expect(response2.status.kind == .redirection)
        #expect(response2.headerFields.count == 3)
        #expect(response2.headerFields[.server] == "HTTPServer/1.0")
    }

    @Test("HTTP fields are compared correctly")
    func comparison() {
        let fields1: HTTPFields = [
            .acceptEncoding: "br",
            .acceptEncoding: "gzip",
            .accept: "*/*",
        ]
        #expect(fields1 != [:])

        let fields2: HTTPFields = [
            .acceptEncoding: "br",
            .acceptEncoding: "gzip",
            .accept: "*/*",
        ]
        #expect(fields1 == fields2)

        let fields3: HTTPFields = [
            .acceptEncoding: "br",
            .accept: "*/*",
            .acceptEncoding: "gzip",
        ]
        #expect(fields1 == fields3)

        let fields4: HTTPFields = [
            .acceptEncoding: "br",
            .accept: "*/*",
        ]
        #expect(fields1 != fields4)

        let fields5: HTTPFields = [
            .acceptEncoding: "gzip",
            .acceptEncoding: "br",
            .accept: "*/*",
        ]
        #expect(fields1 != fields5)

        let fields6: HTTPFields = [
            .acceptEncoding: "gzip",
            .acceptEncoding: "br",
            .acceptLanguage: "en",
        ]
        #expect(fields1 != fields6)
    }

    @Test("Types conform to Sendable protocol")
    func sendable() {
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

        #expect(isSendable(field))
        #expect(isSendable(indexingStrategy))
        #expect(isSendable(name))
        #expect(isSendable(fields))
        #expect(isSendable(request))
        #expect(isSendable(method))
        #expect(isSendable(requestPseudoHeaderFields))
        #expect(isSendable(response))
        #expect(isSendable(status))
        #expect(isSendable(responsePseudoHeaderFields))
    }

    @Test("Requests are encoded and decoded correctly")
    func requestCoding() throws {
        let request = HTTPRequest(method: .put, scheme: "https", authority: "www.example.com", path: "/upload", headerFields: [
            .acceptEncoding: "br",
            .acceptEncoding: "gzip",
            .contentLength: "1024",
        ])
        let encoded = try JSONEncoder().encode(request)

        let json = try JSONSerialization.jsonObject(with: encoded)
        #expect(json as? NSDictionary == [
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
        ])

        let decoded = try JSONDecoder().decode(HTTPRequest.self, from: encoded)
        #expect(request == decoded)
    }

    @Test("Responses are encoded and decoded correctly")
    func responseCoding() throws {
        var response = HTTPResponse(status: .noContent, headerFields: [
            .server: "HTTPServer/1.0",
        ])
        response.headerFields[0].indexingStrategy = .prefer
        let encoded = try JSONEncoder().encode(response)

        let json = try JSONSerialization.jsonObject(with: encoded)
        #expect(json as? NSDictionary == [
            "pseudoHeaderFields": [
                ["name": ":status", "value": "204"],
            ],
            "reasonPhrase": "No Content",
            "headerFields": [
                ["name": "Server", "value": "HTTPServer/1.0", "indexingStrategy": 1],
            ],
        ])

        let decoded = try JSONDecoder().decode(HTTPResponse.self, from: encoded)
        #expect(response == decoded)
    }

    @Test("Requests are parsed correctly")
    func requestParsing() throws {
        let fields = [
            HTTPField(name: HTTPField.Name(parsed: ":method")!, lenientValue: "PUT".utf8),
            HTTPField(name: HTTPField.Name(parsed: ":scheme")!, lenientValue: "https".utf8),
            HTTPField(name: HTTPField.Name(parsed: ":authority")!, lenientValue: "www.example.com".utf8),
            HTTPField(name: HTTPField.Name(parsed: ":path")!, lenientValue: "/upload".utf8),
            HTTPField(name: HTTPField.Name(parsed: "content-length")!, lenientValue: "1024".utf8),
        ]
        let request = try HTTPRequest(parsed: fields)
        #expect(request.method == .put)
        #expect(request.scheme == "https")
        #expect(request.authority == "www.example.com")
        #expect(request.path == "/upload")
        #expect(request.headerFields[.contentLength] == "1024")
    }

    @Test("Responses are parsed correctly")
    func responseParsing() throws {
        let fields = [
            HTTPField(name: HTTPField.Name(parsed: ":status")!, lenientValue: "204".utf8),
            HTTPField(name: HTTPField.Name(parsed: "server")!, lenientValue: "HTTPServer/1.0".utf8),
        ]
        let response = try HTTPResponse(parsed: fields)
        #expect(response.status == .noContent)
        #expect(response.headerFields[.server] == "HTTPServer/1.0")
    }

    @Test("Trailer fields are parsed correctly")
    func trailerFieldsParsing() throws {
        let fields = [
            HTTPField(name: HTTPField.Name(parsed: "trailer1")!, lenientValue: "value1".utf8),
            HTTPField(name: HTTPField.Name(parsed: "trailer2")!, lenientValue: "value2".utf8),
        ]
        let trailerFields = try HTTPFields(parsedTrailerFields: fields)
        #expect(trailerFields[HTTPField.Name("trailer1")!] == "value1")
        #expect(trailerFields[HTTPField.Name("trailer2")!] == "value2")
    }
}
