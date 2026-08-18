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
@_spi(HTTPTypesBenchmarking) import HTTPTypes

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

        // Measured with a `kilo` scaling factor because a single call is too cheap to resolve against
        // the measurement overhead. Note that package-benchmark divides the reported numbers by the
        // scaling factor, so they stay comparable to the benchmarks below.
        Benchmark(
            "HTTPFields.contains-hit-N=\(n)",
            configuration: makeDefaultConfiguration(scalingFactor: .kilo)
        ) { benchmark in
            for _ in benchmark.scaledIterations {
                blackHole(fields.contains(scalingPresentName))
            }
        }

        Benchmark(
            "HTTPFields.contains-miss-N=\(n)",
            configuration: makeDefaultConfiguration(scalingFactor: .kilo)
        ) { benchmark in
            for _ in benchmark.scaledIterations {
                blackHole(fields.contains(scalingAbsentName))
            }
        }

        // MARK: Lookup

        // Exactly one field carries this name at every size.
        Benchmark(
            "HTTPFields[name]-singleValuedField-N=\(n)",
            configuration: makeDefaultConfiguration()
        ) { benchmark in
            for _ in benchmark.scaledIterations {
                blackHole(fields[scalingPresentName])
            }
        }

        Benchmark(
            "HTTPFields[name]-miss-N=\(n)",
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
            "HTTPFields[name]-allCookieFieldsJoined-N=\(n)",
            configuration: makeDefaultConfiguration()
        ) { benchmark in
            for _ in benchmark.scaledIterations {
                blackHole(fields[.cookie])
            }
        }

        Benchmark(
            "HTTPFields[values]-allCookieFields-N=\(n)",
            configuration: makeDefaultConfiguration()
        ) { benchmark in
            for _ in benchmark.scaledIterations {
                blackHole(fields[values: .cookie])
            }
        }

        Benchmark(
            "HTTPFields[fields]-allCookieFields-N=\(n)",
            configuration: makeDefaultConfiguration()
        ) { benchmark in
            for _ in benchmark.scaledIterations {
                blackHole(fields[fields: .cookie])
            }
        }

        // MARK: Equality

        let equalSameOrder = scalingCase.equalSameOrder
        Benchmark(
            "HTTPFields.==-equal-sameOrder-N=\(n)",
            configuration: makeDefaultConfiguration()
        ) { benchmark in
            for _ in benchmark.scaledIterations {
                blackHole(equalSameOrder.lhs == equalSameOrder.rhs)
            }
        }

        // The uniquely named fields appended in the opposite order, so each of them sits far from
        // its partner. The cookies stay put, which keeps most of the walk cheap.
        let equalDifferentOrder = scalingCase.equalDifferentOrder
        Benchmark(
            "HTTPFields.==-equal-differentOrder-N=\(n)",
            configuration: makeDefaultConfiguration()
        ) { benchmark in
            for _ in benchmark.scaledIterations {
                blackHole(equalDifferentOrder.lhs == equalDifferentOrder.rhs)
            }
        }

        // One field a few slots off its partner and everything else in place: the cheapest kind of
        // disorder, and the case the lock step walk exists for.
        let equalLocallyDisplaced = scalingCase.equalLocallyDisplaced
        Benchmark(
            "HTTPFields.==-equal-locallyDisplaced-N=\(n)",
            configuration: makeDefaultConfiguration()
        ) { benchmark in
            for _ in benchmark.scaledIterations {
                blackHole(equalLocallyDisplaced.lhs == equalLocallyDisplaced.rhs)
            }
        }

        let mismatchSameOrder = scalingCase.mismatchSameOrder
        Benchmark(
            "HTTPFields.==-differsAt80%-sameOrder-N=\(n)",
            configuration: makeDefaultConfiguration()
        ) { benchmark in
            for _ in benchmark.scaledIterations {
                blackHole(mismatchSameOrder.lhs == mismatchSameOrder.rhs)
            }
        }

        let mismatchDifferentOrder = scalingCase.mismatchDifferentOrder
        Benchmark(
            "HTTPFields.==-differsAt80%-differentOrder-N=\(n)",
            configuration: makeDefaultConfiguration()
        ) { benchmark in
            for _ in benchmark.scaledIterations {
                blackHole(mismatchDifferentOrder.lhs == mismatchDifferentOrder.rhs)
            }
        }

        // MARK: Building

        let sourceFields = scalingCase.fields
        Benchmark(
            "HTTPFields.append-buildFromNFields-N=\(n)",
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
            "HTTPFields(parsedTrailerFields)-decodeNFields-N=\(n)",
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
            "HTTPFields-copyThenOverwriteExistingField-N=\(n)",
            configuration: makeDefaultConfiguration()
        ) { benchmark in
            for _ in benchmark.scaledIterations {
                var copy = fields
                copy[scalingPresentName] = "benchmark"
                blackHole(copy)
            }
        }

        Benchmark(
            "HTTPFields-copyThenInsertNewField-N=\(n)",
            configuration: makeDefaultConfiguration()
        ) { benchmark in
            for _ in benchmark.scaledIterations {
                var copy = fields
                copy[scalingAbsentName] = "chunked"
                blackHole(copy)
            }
        }
    }

    // MARK: - All distinct names, reversed

    // Every name unique and the list reversed, so no field is near its partner and none of the walk
    // is cheap. This is where `==` hands off to the by-name index; running the two against each
    // other here is what the handoff thresholds come from.
    for distinctNameCase in distinctNameCases {
        let n = distinctNameCase.n
        let pair = distinctNameCase.sortedAgainstReversed

        Benchmark(
            "HTTPFields.==-equal-allDistinctNamesReversed-N=\(n)",
            configuration: makeDefaultConfiguration()
        ) { benchmark in
            for _ in benchmark.scaledIterations {
                blackHole(pair.lhs == pair.rhs)
            }
        }

        Benchmark(
            "HTTPFields.isEqualByNameIndex-equal-allDistinctNamesReversed-N=\(n)",
            configuration: makeDefaultConfiguration()
        ) { benchmark in
            for _ in benchmark.scaledIterations {
                blackHole(HTTPFields.isEqualByNameIndex(pair.lhs, pair.rhs))
            }
        }
    }
}
