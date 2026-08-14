//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Benchmark
import Foundation
import HTTPTypes

/// Metrics used by every benchmark in this suite.
///
/// Allocation count is the primary signal: it is deterministic, so it can be asserted on in
/// CI without flakiness, and it is the dominant cost in this library.
let defaultMetrics: [BenchmarkMetric] = [
    .mallocCountTotal,
    .instructions,
]

func makeDefaultConfiguration(
    metrics: [BenchmarkMetric] = defaultMetrics,
    scalingFactor: BenchmarkScalingFactor = .one,
    maxDuration: Duration = .seconds(3),
    maxIterations: Int = 10_000
) -> Benchmark.Configuration {
    Benchmark.Configuration(
        metrics: metrics,
        scalingFactor: scalingFactor,
        maxDuration: maxDuration,
        maxIterations: maxIterations
    )
}

// MARK: - Fixtures

/// A field list as an HPACK/QPACK decoder would hand it over for a typical browser request.
let parsedRequestFields: [HTTPField] = [
    HTTPField(name: HTTPField.Name(parsed: ":method")!, value: "GET"),
    HTTPField(name: HTTPField.Name(parsed: ":scheme")!, value: "https"),
    HTTPField(name: HTTPField.Name(parsed: ":authority")!, value: "www.example.com"),
    HTTPField(name: HTTPField.Name(parsed: ":path")!, value: "/api/v1/items?page=2&limit=50"),
    HTTPField(name: .userAgent, value: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)"),
    HTTPField(name: .accept, value: "text/html,application/xhtml+xml,application/xml;q=0.9"),
    HTTPField(name: .acceptEncoding, value: "gzip, deflate, br"),
    HTTPField(name: .acceptLanguage, value: "en-US,en;q=0.9"),
    HTTPField(name: .cacheControl, value: "no-cache"),
    HTTPField(name: .cookie, value: "session=abc123"),
    HTTPField(name: .cookie, value: "theme=dark"),
    HTTPField(name: .referer, value: "https://www.example.com/home"),
]

/// A field list as an HPACK/QPACK decoder would hand it over for a typical response.
let parsedResponseFields: [HTTPField] = [
    HTTPField(name: HTTPField.Name(parsed: ":status")!, value: "200"),
    HTTPField(name: .contentType, value: "application/json; charset=utf-8"),
    HTTPField(name: .contentLength, value: "14523"),
    HTTPField(name: .date, value: "Mon, 03 Aug 2026 12:00:00 GMT"),
    HTTPField(name: .server, value: "nginx/1.25.3"),
    HTTPField(name: .cacheControl, value: "max-age=3600, public"),
    HTTPField(name: .eTag, value: "\"686897696a7c876b7e\""),
    HTTPField(name: .vary, value: "Accept-Encoding"),
    HTTPField(name: .strictTransportSecurity, value: "max-age=31536000"),
    HTTPField(name: .setCookie, value: "session=abc123; Path=/; HttpOnly"),
    HTTPField(name: .setCookie, value: "theme=dark; Path=/; Max-Age=31536000"),
    HTTPField(name: .setCookie, value: "csrf=xyz789; Path=/; Secure"),
]

let parsedTrailerFieldList: [HTTPField] = [
    HTTPField(name: HTTPField.Name(parsed: "grpc-status")!, value: "0"),
    HTTPField(name: HTTPField.Name(parsed: "grpc-message")!, value: "OK"),
]

/// Header field names as they arrive off the wire in HTTP/1, i.e. mixed case.
let rawFieldNames: [String] = [
    "Content-Type", "Content-Length", "Date", "Server", "Cache-Control",
    "ETag", "Vary", "Strict-Transport-Security", "Set-Cookie", "Connection",
]

/// The same names already lowercased, as HTTP/2 and HTTP/3 require.
let lowercaseFieldNames: [String] = rawFieldNames.map { $0.lowercased() }

let sampleResponseFields: HTTPFields = {
    var fields = HTTPFields()
    for field in parsedResponseFields where !field.name.isPseudoName {
        fields.append(field)
    }
    return fields
}()

let sampleRequestFields: HTTPFields = {
    var fields = HTTPFields()
    for field in parsedRequestFields where !field.name.isPseudoName {
        fields.append(field)
    }
    return fields
}()

let sampleURL = URL(string: "https://www.example.com/api/v1/items?page=2&limit=50")!

let sampleRequest = HTTPRequest(method: .get, url: sampleURL, headerFields: sampleRequestFields)

/// A field value that is not representable as ASCII, exercising the ISO-Latin-1 slow paths.
let latin1FieldValue = "attachment; filename=\"Übergrößenträger-Prüfbericht-2026.pdf\""

extension HTTPField.Name {
    /// `isPseudo` is internal to HTTPTypes, so recompute it here.
    fileprivate var isPseudoName: Bool {
        self.rawName.utf8.first == UInt8(ascii: ":")
    }
}

// MARK: - Benchmarks

let benchmarks: @Sendable () -> Void = {
    // MARK: Field names

    Benchmark(
        "HTTPField.Name.init - mixed case names",
        configuration: makeDefaultConfiguration(scalingFactor: .kilo)
    ) { benchmark in
        for _ in benchmark.scaledIterations {
            for name in rawFieldNames {
                blackHole(HTTPField.Name(name))
            }
        }
    }

    Benchmark(
        "HTTPField.Name.init - already lowercase names",
        configuration: makeDefaultConfiguration(scalingFactor: .kilo)
    ) { benchmark in
        for _ in benchmark.scaledIterations {
            for name in lowercaseFieldNames {
                blackHole(HTTPField.Name(name))
            }
        }
    }

    // MARK: ISO-Latin-1 values

    Benchmark("HTTPField - non-ASCII value round trip", configuration: makeDefaultConfiguration()) { benchmark in
        for _ in benchmark.scaledIterations {
            let field = HTTPField(name: .contentDisposition, value: latin1FieldValue)
            blackHole(field.value)
            field.withUnsafeBytesOfValue { blackHole($0.count) }
        }
    }

    // MARK: URL conversion

    Benchmark("HTTPRequest(method, url) - request from URL", configuration: makeDefaultConfiguration()) { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(HTTPRequest(method: .get, url: sampleURL, headerFields: sampleRequestFields))
        }
    }

    Benchmark("HTTPRequest.url - synthesize URL from pseudo fields", configuration: makeDefaultConfiguration()) {
        benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(sampleRequest.url)
        }
    }

    // MARK: Scaling

    // The same operations over field lists of 8, 16, 32, 64 and 128 fields. See
    // `HTTPFieldsScalingBenchmarks.swift`.
    registerHTTPFieldsScalingBenchmarks()
}
