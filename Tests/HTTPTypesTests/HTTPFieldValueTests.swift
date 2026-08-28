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

import Foundation
@_spi(HTTPTypesBenchmarking) import HTTPTypes
import Testing

extension HTTPField.Name {
    fileprivate static var foo: HTTPField.Name { .init(parsed: "foo")! }
}

@Suite struct HTTPFieldValueTests {
    @Test func empty() {
        let field = HTTPField(name: .foo, value: "")
        #expect(field.value == "")

        field.withUnsafeBytesOfValue { buffer in
            #expect(buffer.count == 0)
        }
    }

    @Test func pureAscii() {
        let field = HTTPField(name: .foo, value: "bar")
        #expect(field.value == "bar")

        field.withUnsafeBytesOfValue { buffer in
            #expect(buffer.count == 3)
            #expect(String(decoding: buffer, as: UTF8.self) == "bar")
        }
    }

    @Test func pureAsciiAsBytes() {
        let value = "bar"
        let field = HTTPField(name: .foo, value: value.utf8)
        #expect(field.value == "bar")

        field.withUnsafeBytesOfValue { buffer in
            #expect(buffer.count == 3)
            #expect(String(decoding: buffer, as: UTF8.self) == "bar")
        }
    }

    @Test func pureAsciiWithLeadingAndTrailingSpacesAndTabs() {
        let field = HTTPField(name: .foo, value: " \t \t bar and baz \t \t ")
        #expect(field.value == "bar and baz")

        field.withUnsafeBytesOfValue { buffer in
            #expect(buffer.count == 11)
            #expect(String(decoding: buffer, as: UTF8.self) == "bar and baz")
        }
    }

    @Test func pureAsciiLenient() {
        let value = "bar"
        let field = HTTPField(name: .foo, lenientValue: value.utf8)
        field.withUnsafeBytesOfValue { buffer in
            #expect(buffer.count == 3)
            #expect(String(decoding: buffer, as: UTF8.self) == "bar")
        }
    }

    @Test func emoji() {
        let field = HTTPField(name: .foo, value: "👍")
        #expect(field.value == "👍")

        field.withUnsafeBytesOfValue { buffer in
            #expect(buffer.count == 4)
            #expect(String(decoding: buffer, as: UTF8.self) == "👍")
        }
    }

    @Test func zeroWidthJoiner() {
        let field = HTTPField(name: .foo, value: "🏳️‍🌈")
        #expect(field.value == "🏳️‍🌈")

        field.withUnsafeBytesOfValue { buffer in
            #expect(buffer.count == 14)
            #expect(String(decoding: buffer, as: UTF8.self) == "🏳️‍🌈")
        }
    }

    @Test func asciiWithControlBytesLegalized() {
        let bytes: [UInt8] = [0x00, 0x62, 0x61, 0x00, 0x72, 0x00]
        let field = HTTPField(name: .foo, value: bytes)

        #expect(field.value == "ba r")

        field.withUnsafeBytesOfValue { buffer in
            #expect(Array(buffer) == [0x62, 0x61, 0x20, 0x72])
        }
    }

    @Test func asciiWithControlBytesLenient() {
        let bytes: [UInt8] = [0x00, 0x62, 0x61, 0x00, 0x72, 0x00]
        let field = HTTPField(name: .foo, lenientValue: bytes)

        #expect(field.value == " ba r ")

        field.withUnsafeBytesOfValue { buffer in
            #expect(Array(buffer) == [0x20, 0x62, 0x61, 0x20, 0x72, 0x20])
        }
    }

    @Test func nonUTF8WithControlBytesLegalized() {
        let bytes: [UInt8] = [
            0xC0,  // not valid UTF8. will be changed with replacement character in string representation
            0x41,  // simple ASCII
            0xFF,  // not valid UTF8. will be changed with replacement character in string representation
            0x0A,  // random control character which should be trimmed
        ]
        let field = HTTPField(name: .foo, value: bytes)

        #expect(field.value == "\u{FFFD}A\u{FFFD}")

        field.withUnsafeBytesOfValue { buffer in
            #expect(buffer.count == 3)
            #expect(buffer[0] == 0xC0)
            #expect(buffer[1] == 0x41)
            #expect(buffer[2] == 0xFF)
        }
    }

    @Test func nonUTF8WithControlBytesLenient() {
        let bytes: [UInt8] = [
            0xC0,  // not valid UTF8. will be changed with replacement character in string representation
            0x41,  // simple ASCII
            0xFF,  // not valid UTF8. will be changed with replacement character in string representation
            0x0A,  // random control character which should be swapped with a space
        ]
        let field = HTTPField(name: .foo, lenientValue: bytes)

        #expect(field.value == "\u{FFFD}A\u{FFFD} ")

        field.withUnsafeBytesOfValue { buffer in
            #expect(buffer.count == 4)
            #expect(buffer[0] == 0xC0)
            #expect(buffer[1] == 0x41)
            #expect(buffer[2] == 0xFF)
            #expect(buffer[3] == 0x20)
        }
    }
}
