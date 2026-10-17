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

import Benchmark
import HTTPTypes

/// A long value, about the size of a large cookie, so that per-byte costs dominate.
let longLatin1FieldValue = String(repeating: latin1FieldValue, count: 32)

/// `longLatin1FieldValue` encoded as ISO Latin 1, which is not valid UTF-8.
let latin1FieldValueBytes: [UInt8] = longLatin1FieldValue.unicodeScalars.map { UInt8($0.value) }

/// `longLatin1FieldValue` encoded as UTF-8, i.e. valid UTF-8 that is not ASCII.
let utf8NonASCIIFieldValueBytes: [UInt8] = Array(longLatin1FieldValue.utf8)

let asciiField = HTTPField(name: .contentDisposition, value: String(repeating: asciiFieldValue, count: 32))

/// Benchmarks for the representation of `HTTPField.Value`, which stores ASCII values as strings and
/// everything else as raw bytes.
///
/// These only touch the raw bytes of a value and never ask for the `value` string, as a proxy or an
/// HPACK/QPACK encoder would.
///
/// Registered from the `benchmarks` closure in `Benchmarks.swift`, because package-benchmark only
/// picks up one such closure per target.
func registerHTTPFieldValueBenchmarks() {
    Benchmark(
        "HTTPField-latin1BytesValuePassthrough",
        configuration: makeDefaultConfiguration()
    ) { benchmark in
        for _ in benchmark.scaledIterations {
            let field = HTTPField(name: .contentDisposition, value: latin1FieldValueBytes)
            field.withUnsafeBytesOfValue { blackHole($0.count) }
            blackHole(field)
        }
    }

    Benchmark(
        "HTTPField-utf8NonASCIIBytesValuePassthrough",
        configuration: makeDefaultConfiguration()
    ) { benchmark in
        for _ in benchmark.scaledIterations {
            let field = HTTPField(name: .contentDisposition, value: utf8NonASCIIFieldValueBytes)
            field.withUnsafeBytesOfValue { blackHole($0.count) }
            blackHole(field)
        }
    }

    Benchmark(
        "HTTPField-latin1BytesValueEquality",
        configuration: makeDefaultConfiguration()
    ) { benchmark in
        let lhs = HTTPField(name: .contentDisposition, value: latin1FieldValueBytes)
        let rhs = HTTPField(name: .contentDisposition, value: latin1FieldValueBytes)
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            blackHole(lhs == rhs)
        }
    }

    Benchmark(
        "HTTPField-asciiValueHash",
        configuration: makeDefaultConfiguration()
    ) { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(asciiField.hashValue)
        }
    }
}
