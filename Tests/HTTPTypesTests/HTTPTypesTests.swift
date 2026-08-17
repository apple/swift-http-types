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

@Suite struct HTTPTypesTests {
    @Test func fields() {
        var fields = HTTPFields()
        fields[.acceptEncoding] = "gzip"
        fields.append(HTTPField(name: .acceptEncodingLower, value: "br"))
        fields.insert(HTTPField(name: .acceptEncodingMixed, value: "deflate"), at: 1)

        #expect(fields[.acceptEncoding] == "gzip, deflate, br")
        #expect(fields[values: .acceptEncodingUpper].count == 3)
    }

    @Test func contains() {
        var fields = HTTPFields()
        fields[.acceptEncoding] = "gzip"

        #expect(fields.contains(.acceptEncoding))
        #expect(fields.contains(.acceptEncodingMixed))
        #expect(fields.contains(.acceptEncodingUpper))
        #expect(!fields.contains(.accept))
    }

    @Test func fieldValue() {
        #expect(HTTPField(name: .accept, value: "   \n 😀 \t ").value == "😀")
        #expect(HTTPField(name: .accept, value: " a 😀 \t\n b \t \r ").value == "a 😀 \t  b")
        #expect(HTTPField(name: .accept, value: "").value == "")
        #expect(!HTTPField.isValidValue(" "))
        #expect(HTTPField(name: .accept, lenientValue: "  \r\n\0\t ".utf8).value == "     \t ")
    }

    @Test func request() {
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

        #expect(request2.method == .get)
        #expect(request1 == request2)
    }

    @Test func response() {
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

    @Test func comparison() {
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

    /// `==` walks the two field lists in lock step and sets aside the fields that do not line up.
    /// These are the cases where the two sides diverge in the middle of a run of same-named
    /// fields, so that a field has to be paired with one the other list produced at a different
    /// position rather than with the one across from it.
    @Test func equalityWhenSameNamedFieldsAreDisplaced() {
        let a = HTTPField.Name("a")!
        let b = HTTPField.Name("b")!
        func fields(_ pairs: [(HTTPField.Name, String)]) -> HTTPFields {
            var fields = HTTPFields()
            for (name, value) in pairs {
                fields.append(HTTPField(name: name, value: value))
            }
            return fields
        }

        // The leading "a" is identical on both sides, and the remaining "a" is on the far side of
        // the reordered "b" in one of them.
        let dupSplitByReorder = fields([(a, "1"), (b, "9"), (a, "1")])
        #expect(dupSplitByReorder == fields([(a, "1"), (a, "1"), (b, "9")]))

        let distinctValues = fields([(a, "1"), (b, "2"), (a, "3")])
        #expect(distinctValues == fields([(a, "1"), (a, "3"), (b, "2")]))

        // Same names and same total count, but the two "a" fields are swapped, and the relative
        // order of same-named fields is significant.
        #expect(fields([(a, "1"), (a, "2")]) != fields([(a, "2"), (a, "1")]))
        #expect(fields([(a, "1"), (b, "1"), (a, "2")]) != fields([(a, "2"), (a, "1"), (b, "1")]))

        // Equal counts, but one name's run is longer on one side than on the other.
        #expect(fields([(a, "1"), (a, "1"), (b, "2")]) != fields([(a, "1"), (b, "2"), (b, "2")]))
    }

    /// While `==` walks the two lists, the fields it has set aside on one side can briefly outnumber
    /// those on the other: here the second "a" is set aside before the first one is paired off, so
    /// one side holds two and the other one. This is the case to reach for when changing how those
    /// set aside fields are counted.
    @Test func equalityWhenOneSideBrieflyHoldsMoreSetAsideFields() {
        let a = HTTPField.Name("a")!
        let b = HTTPField.Name("b")!
        let c = HTTPField.Name("c")!
        let d = HTTPField.Name("d")!
        func fields(_ pairs: [(HTTPField.Name, String)]) -> HTTPFields {
            var fields = HTTPFields()
            for (name, value) in pairs {
                fields.append(HTTPField(name: name, value: value))
            }
            return fields
        }

        let straight = fields([(a, "1"), (b, "2"), (c, "3"), (a, "4"), (d, "5")])
        #expect(straight == fields([(b, "2"), (c, "3"), (d, "5"), (a, "1"), (a, "4")]))

        // The same reordering with the two "a" fields swapped, which is not equal: the relative
        // order of the fields sharing a name is the one thing that has to match.
        #expect(straight != fields([(b, "2"), (c, "3"), (d, "5"), (a, "4"), (a, "1")]))
    }

    /// `equalAlternative(to:)` is a second implementation of the same question, so it has to give
    /// the same answer as `==` on every case that distinguishes them.
    @Test func equalAlternativeAgreesWithEquality() {
        let a = HTTPField.Name("a")!
        let b = HTTPField.Name("b")!
        func fields(_ pairs: [(HTTPField.Name, String)]) -> HTTPFields {
            var fields = HTTPFields()
            for (name, value) in pairs {
                fields.append(HTTPField(name: name, value: value))
            }
            return fields
        }

        let lists = [
            [] as [(HTTPField.Name, String)],
            [(a, "1")],
            [(a, "1"), (b, "2")],
            [(b, "2"), (a, "1")],
            [(a, "1"), (a, "2")],
            [(a, "2"), (a, "1")],
            [(a, "1"), (b, "9"), (a, "1")],
            [(a, "1"), (a, "1"), (b, "9")],
            [(a, "1"), (a, "1"), (b, "2")],
            [(a, "1"), (b, "2"), (b, "2")],
            [(a, "1"), (b, "1"), (a, "2"), (b, "2")],
            [(a, "1"), (a, "2"), (b, "1"), (b, "2")],
            [(a, "2"), (a, "1"), (b, "1"), (b, "2")],
        ].map(fields)

        for lhs in lists {
            for rhs in lists {
                #expect(lhs.equalAlternative(to: rhs) == (lhs == rhs), "\(Array(lhs)) vs \(Array(rhs))")
            }
        }
    }

    /// Past a certain amount of disorder `==` stops walking the two lists in lock step and indexes
    /// one of them by name instead. The lists here are long enough and reordered enough to cross
    /// that point, which no other test in this file does.
    @Test func equalityOfLongHeavilyReorderedLists() {
        func fields(_ pairs: [(String, String)]) -> HTTPFields {
            var fields = HTTPFields()
            for (name, value) in pairs {
                fields.append(HTTPField(name: HTTPField.Name(name)!, value: value))
            }
            return fields
        }
        let distinct = (1...128).map { ("n\($0)", "value\($0)") }

        // All names distinct, so reversing cannot break the order of any name's fields.
        #expect(fields(distinct) == fields(distinct.reversed()))
        #expect(fields(distinct) == fields(distinct))

        // One value differs, deep inside the reordered region.
        var oneDiffers = distinct
        oneDiffers[64] = (oneDiffers[64].0, "other")
        #expect(fields(distinct) != fields(oneDiffers.reversed()))

        // One name differs, so each list has a name the other does not.
        var oneRenamed = distinct
        oneRenamed[64] = ("other", oneRenamed[64].1)
        #expect(fields(distinct) != fields(oneRenamed.reversed()))

        // Repeated names in a long reordered list: the relative order of the repeats is what
        // matters, and reversing the whole list inverts it.
        let repeated = (1...128).map { ("n\($0 % 8)", "value\($0)") }
        #expect(fields(repeated) == fields(repeated))
        #expect(fields(repeated) != fields(repeated.reversed()))

        // Same fields, but only the differently named ones move: every name's run keeps its order.
        let grouped = (0..<8).flatMap { group in repeated.filter { $0.0 == "n\(group)" } }
        #expect(fields(repeated) == fields(grouped))
    }

    @Test func hashMatchesEqualityForSameOrder() {
        let fields1: HTTPFields = [
            .acceptEncoding: "br",
            .acceptEncoding: "gzip",
            .accept: "*/*",
        ]

        let fields2: HTTPFields = [
            .acceptEncoding: "br",
            .acceptEncoding: "gzip",
            .accept: "*/*",
        ]
        #expect(fields1 == fields2)
        #expect(fields1.hashValue == fields2.hashValue)
    }

    @Test func hashMatchesEqualityForDifferentOrder() {
        let fields1: HTTPFields = [
            .acceptEncoding: "br",
            .acceptEncoding: "gzip",
            .accept: "*/*",
        ]

        // Fields with differently named fields in a different order are equal, since the
        // relative order of same-named fields is preserved.
        let fields2: HTTPFields = [
            .acceptEncoding: "br",
            .accept: "*/*",
            .acceptEncoding: "gzip",
        ]
        #expect(fields1 == fields2)

        // Equal values must therefore hash equally.
        withKnownIssue("HTTPFields.hash(into:) is order sensitive while == is not") {
            #expect(fields1.hashValue == fields2.hashValue)
        }
    }

    @Test func sendable() {
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

    @Test func requestCoding() throws {
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
        #expect(
            json as? NSDictionary
                == [
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
        #expect(request == decoded)
    }

    @Test func responseCoding() throws {
        var response = HTTPResponse(
            status: .noContent,
            headerFields: [
                .server: "HTTPServer/1.0"
            ]
        )
        response.headerFields[0].indexingStrategy = .prefer
        let encoded = try JSONEncoder().encode(response)

        let json = try JSONSerialization.jsonObject(with: encoded)
        #expect(
            json as? NSDictionary
                == [
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
        #expect(response == decoded)
    }

    @Test func requestParsing() throws {
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

    @Test func responseParsing() throws {
        let fields = [
            HTTPField(name: HTTPField.Name(parsed: ":status")!, lenientValue: "204".utf8),
            HTTPField(name: HTTPField.Name(parsed: "server")!, lenientValue: "HTTPServer/1.0".utf8),
        ]
        let response = try HTTPResponse(parsed: fields)
        #expect(response.status == .noContent)
        #expect(response.headerFields[.server] == "HTTPServer/1.0")
    }

    @Test func trailerFieldsParsing() throws {
        let fields = [
            HTTPField(name: HTTPField.Name(parsed: "trailer1")!, lenientValue: "value1".utf8),
            HTTPField(name: HTTPField.Name(parsed: "trailer2")!, lenientValue: "value2".utf8),
        ]
        let trailerFields = try HTTPFields(parsedTrailerFields: fields)
        #expect(trailerFields[HTTPField.Name("trailer1")!] == "value1")
        #expect(trailerFields[HTTPField.Name("trailer2")!] == "value2")
    }

    @Test func typeLayoutSize() {
        #expect(MemoryLayout<HTTPRequest>.size == MemoryLayout<AnyObject>.size * 2)
        #expect(MemoryLayout<HTTPResponse>.size == MemoryLayout<AnyObject>.size * 2)
        #expect(MemoryLayout<HTTPFields>.size == MemoryLayout<AnyObject>.size)
    }
}
