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

/// Benchmarks that run the same operation over field lists of 8, 16, 32, 64 and 128 fields.
///
/// The point of these is the *shape of the curve*, not the individual number: operations that cost
/// the same on a small field list can cost wildly different amounts on a large one, and that
/// difference is what decides whether a change to `HTTPFields` is worth making. A single measurement
/// at a single size cannot show it.
///
/// See `HTTPFieldsScalingFixtures.swift` for the field lists.
///
/// Registered from the `benchmarks` closure in `Benchmarks.swift`, because package-benchmark only
/// picks up one such closure per target.
func registerHTTPFieldsScalingBenchmarks() {
    validateScalingFixtures()

    for scalingCase in scalingCases {
        let n = scalingCase.n
        let fields = scalingCase.readFields

        // MARK: contains

        // Measured with a large scaling factor because a single call is too cheap to resolve against
        // the measurement overhead. Note that package-benchmark divides the reported numbers by the
        // scaling factor, so they stay comparable to the benchmarks below.
        Benchmark(
            "HTTPFields.contains - hit - N=\(n)",
            configuration: makeDefaultConfiguration(scalingFactor: .kilo)
        ) { benchmark in
            for _ in benchmark.scaledIterations {
                blackHole(fields.contains(scalingPresentName))
            }
        }

        Benchmark(
            "HTTPFields.contains - miss - N=\(n)",
            configuration: makeDefaultConfiguration(scalingFactor: .kilo)
        ) { benchmark in
            for _ in benchmark.scaledIterations {
                blackHole(fields.contains(scalingAbsentName))
            }
        }

        // MARK: Lookup

        // Exactly one field carries this name at every size.
        Benchmark(
            "HTTPFields[name] - single-valued field - N=\(n)",
            configuration: makeDefaultConfiguration()
        ) { benchmark in
            for _ in benchmark.scaledIterations {
                blackHole(fields[scalingPresentName])
            }
        }

        Benchmark(
            "HTTPFields[name] - miss - N=\(n)",
            configuration: makeDefaultConfiguration()
        ) { benchmark in
            for _ in benchmark.scaledIterations {
                blackHole(fields[scalingAbsentName])
            }
        }

        // Cookies are what makes a field list large, so these are the lookups that have to retrieve
        // a growing number of fields. The three of them are separate benchmarks rather than one,
        // because they return different things — one joined string, the values, the fields — and a
        // combined number would not say which of them scales.
        Benchmark(
            "HTTPFields[name] - all cookie fields joined - N=\(n)",
            configuration: makeDefaultConfiguration()
        ) { benchmark in
            for _ in benchmark.scaledIterations {
                blackHole(fields[.cookie])
            }
        }

        Benchmark(
            "HTTPFields[values] - all cookie fields - N=\(n)",
            configuration: makeDefaultConfiguration()
        ) { benchmark in
            for _ in benchmark.scaledIterations {
                blackHole(fields[values: .cookie])
            }
        }

        Benchmark(
            "HTTPFields[fields] - all cookie fields - N=\(n)",
            configuration: makeDefaultConfiguration()
        ) { benchmark in
            for _ in benchmark.scaledIterations {
                blackHole(fields[fields: .cookie])
            }
        }

        // MARK: Equality

        // Both sides of every pair were built independently rather than copied from one another, so
        // equality always has to do the real comparison.
        let equalSameOrder = scalingCase.equalSameOrder
        Benchmark(
            "HTTPFields.== - equal, same order - N=\(n)",
            configuration: makeDefaultConfiguration()
        ) { benchmark in
            for _ in benchmark.scaledIterations {
                blackHole(equalSameOrder.lhs == equalSameOrder.rhs)
            }
        }

        let equalDifferentOrder = scalingCase.equalDifferentOrder
        Benchmark(
            "HTTPFields.== - equal, different order - N=\(n)",
            configuration: makeDefaultConfiguration()
        ) { benchmark in
            for _ in benchmark.scaledIterations {
                blackHole(equalDifferentOrder.lhs == equalDifferentOrder.rhs)
            }
        }

        let mismatchSameOrder = scalingCase.mismatchSameOrder
        Benchmark(
            "HTTPFields.== - differs at 80%, same order - N=\(n)",
            configuration: makeDefaultConfiguration()
        ) { benchmark in
            for _ in benchmark.scaledIterations {
                blackHole(mismatchSameOrder.lhs == mismatchSameOrder.rhs)
            }
        }

        let mismatchDifferentOrder = scalingCase.mismatchDifferentOrder
        Benchmark(
            "HTTPFields.== - differs at 80%, different order - N=\(n)",
            configuration: makeDefaultConfiguration()
        ) { benchmark in
            for _ in benchmark.scaledIterations {
                blackHole(mismatchDifferentOrder.lhs == mismatchDifferentOrder.rhs)
            }
        }

        // MARK: Building

        let sourceFields = scalingCase.fields
        Benchmark(
            "HTTPFields.append - build from N fields - N=\(n)",
            configuration: makeDefaultConfiguration()
        ) { benchmark in
            for _ in benchmark.scaledIterations {
                var built = HTTPFields()
                for field in sourceFields {
                    built.append(field)
                }
                blackHole(built)
            }
        }

        Benchmark(
            "HTTPFields(parsedTrailerFields) - decode N fields - N=\(n)",
            configuration: makeDefaultConfiguration()
        ) { benchmark in
            for _ in benchmark.scaledIterations {
                blackHole(try HTTPFields(parsedTrailerFields: sourceFields))
            }
        }

        // MARK: Copy-on-write mutation

        // Writing through a second reference, which is what a middleware that adds or rewrites a
        // header does. Both of these pay for whatever the copy costs; they differ in whether the
        // write then replaces an existing field or adds a new one.
        Benchmark(
            "HTTPFields - copy then overwrite existing field - N=\(n)",
            configuration: makeDefaultConfiguration()
        ) { benchmark in
            for _ in benchmark.scaledIterations {
                var copy = fields
                copy[scalingPresentName] = "benchmark"
                blackHole(copy)
            }
        }

        Benchmark(
            "HTTPFields - copy then insert new field - N=\(n)",
            configuration: makeDefaultConfiguration()
        ) { benchmark in
            for _ in benchmark.scaledIterations {
                var copy = fields
                copy[scalingAbsentName] = "chunked"
                blackHole(copy)
            }
        }
    }
}
