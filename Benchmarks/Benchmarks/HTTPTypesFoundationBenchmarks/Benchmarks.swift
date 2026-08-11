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
import Foundation
import HTTPTypes
import HTTPTypesFoundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

let defaultMetrics: [BenchmarkMetric] = [
    .mallocCountTotal,
    .instructions,
]

var defaultConfiguration: Benchmark.Configuration {
    .init(
        metrics: defaultMetrics,
        scalingFactor: .kilo,
        maxDuration: .seconds(10),
        maxIterations: 10_000
    )
}

// MARK: - Fixtures

let sampleURL = URL(string: "https://www.example.com/api/v1/items?page=2&limit=50")!

let requestHeaderFields: HTTPFields = [
    .userAgent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)",
    .accept: "text/html,application/xhtml+xml,application/xml;q=0.9",
    .acceptEncoding: "gzip, deflate, br",
    .acceptLanguage: "en-US,en;q=0.9",
    .cacheControl: "no-cache",
    .referer: "https://www.example.com/home",
]

/// A request carrying repeated `Cookie` fields, which the bridge has to merge.
let sampleHTTPRequest: HTTPRequest = {
    var request = HTTPRequest(method: .get, url: sampleURL, headerFields: requestHeaderFields)
    request.headerFields.append(HTTPField(name: .cookie, value: "session=abc123"))
    request.headerFields.append(HTTPField(name: .cookie, value: "theme=dark"))
    request.headerFields.append(HTTPField(name: .cookie, value: "locale=en_US"))
    return request
}()

/// A response carrying repeated `Set-Cookie` fields, which the bridge has to merge.
let sampleHTTPResponse: HTTPResponse = {
    var response = HTTPResponse(status: .ok)
    response.headerFields = [
        .contentType: "application/json; charset=utf-8",
        .contentLength: "14523",
        .server: "nginx/1.25.3",
        .cacheControl: "max-age=3600, public",
        .eTag: "\"686897696a7c876b7e\"",
        .vary: "Accept-Encoding",
    ]
    response.headerFields.append(HTTPField(name: .setCookie, value: "session=abc123; Path=/; HttpOnly"))
    response.headerFields.append(HTTPField(name: .setCookie, value: "theme=dark; Path=/; Max-Age=31536000"))
    response.headerFields.append(HTTPField(name: .setCookie, value: "csrf=xyz789; Path=/; Secure"))
    return response
}()

let sampleURLRequest = URLRequest(httpRequest: sampleHTTPRequest)!

let sampleHTTPURLResponse = HTTPURLResponse(httpResponse: sampleHTTPResponse, url: sampleURL)!

// MARK: - Benchmarks

let benchmarks: @Sendable () -> Void = {

    Benchmark("URLRequest(httpRequest:) - HTTPRequest to URLRequest", configuration: defaultConfiguration) {
        benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(URLRequest(httpRequest: sampleHTTPRequest))
        }
    }

    Benchmark("URLRequest.httpRequest - URLRequest to HTTPRequest", configuration: defaultConfiguration) {
        benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(sampleURLRequest.httpRequest)
        }
    }

    Benchmark(
        "HTTPURLResponse(httpResponse:url:) - HTTPResponse to HTTPURLResponse",
        configuration: defaultConfiguration
    ) {
        benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(HTTPURLResponse(httpResponse: sampleHTTPResponse, url: sampleURL))
        }
    }

    Benchmark("HTTPURLResponse.httpResponse - HTTPURLResponse to HTTPResponse", configuration: defaultConfiguration) {
        benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(sampleHTTPURLResponse.httpResponse)
        }
    }
}
