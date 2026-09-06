//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
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

@Suite struct HTTPFieldNameTests {
    @Test func initRejectsInvalidCharacters() {
        #expect(HTTPField.Name("") == nil)
        #expect(HTTPField.Name("content type") == nil)
        #expect(HTTPField.Name("content:type") == nil)
        #expect(HTTPField.Name("cöntent-type") == nil)
        // `init(_:)` does not know about pseudo header fields, so the colon is just an illegal character.
        #expect(HTTPField.Name(":method") == nil)
    }

    @Test func initCanonicalisesMixedCase() {
        let name = HTTPField.Name("Content-Type")
        #expect(name?.rawName == "Content-Type")
        #expect(name?.canonicalName == "content-type")
        #expect(name == HTTPField.Name("content-type"))
    }

    @Test func parsedAcceptsLowercasedNames() {
        let name = HTTPField.Name(parsed: "content-type")
        #expect(name?.rawName == "content-type")
        #expect(name?.canonicalName == "content-type")
        #expect(name == HTTPField.Name("content-type"))

        // The symbols RFC 9110 allows in a token, plus digits.
        #expect(HTTPField.Name(parsed: "!#$%&'*+-.^_`|~09az") != nil)
    }

    @Test func parsedAcceptsPseudoHeaderFields() {
        let name = HTTPField.Name(parsed: ":method")
        #expect(name?.rawName == ":method")
        #expect(name?.canonicalName == ":method")
    }

    @Test func parsedRejectsInvalidCharacters() {
        #expect(HTTPField.Name(parsed: "") == nil)
        #expect(HTTPField.Name(parsed: ":") == nil)
        #expect(HTTPField.Name(parsed: "content type") == nil)
        #expect(HTTPField.Name(parsed: "content:type") == nil)
        #expect(HTTPField.Name(parsed: "cöntent-type") == nil)
    }

    @Test func parsedRejectsUppercasedNames() {
        #expect(HTTPField.Name(parsed: "A") == nil)
        #expect(HTTPField.Name(parsed: "Content-Type") == nil)
        #expect(HTTPField.Name(parsed: "content-typE") == nil)
        #expect(HTTPField.Name(parsed: ":Method") == nil)
    }
}
