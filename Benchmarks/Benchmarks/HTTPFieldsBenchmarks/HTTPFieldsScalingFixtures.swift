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

@_spi(HTTPTypesBenchmarking) import HTTPTypes

// MARK: - Field lists

/// Field lists of increasing size, used to measure how `HTTPFields` operations scale.
///
/// The lists are nested: every list is a prefix of the next larger one, so a difference between two
/// sizes is only ever caused by the fields that were added.
///
/// Real field lists grow past ~16 fields almost exclusively because of cookies.

/// `Cookie` fields with distinct values, so that no two fields in a list compare equal.
private func cookieFields(_ range: Range<Int>) -> [HTTPField] {
    range.map { HTTPField(name: .cookie, value: "cookie\($0)=aBcDeF0123456789-\($0)") }
}

/// A name that has no static member on `HTTPField.Name`.
private func name(_ string: String) -> HTTPField.Name {
    HTTPField.Name(string)!
}

/// 6 ordinary headers and 2 cookies.
let scalingFields8: [HTTPField] =
    [
        HTTPField(name: .connection, value: "keep-alive"),
        HTTPField(name: .userAgent, value: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)"),
        HTTPField(name: .accept, value: "text/html,application/xhtml+xml,application/xml;q=0.9"),
        HTTPField(name: .acceptEncoding, value: "gzip, deflate, br"),
        HTTPField(name: .acceptLanguage, value: "en-US,en;q=0.9"),
        HTTPField(name: .referer, value: "https://www.example.com/home"),
    ] + cookieFields(0..<2)

/// 12 ordinary headers and 4 cookies.
let scalingFields16: [HTTPField] =
    scalingFields8 + [
        HTTPField(name: .origin, value: "https://www.example.com"),
        HTTPField(name: .cacheControl, value: "no-cache"),
        HTTPField(name: name("sec-fetch-dest"), value: "document"),
        HTTPField(name: name("sec-fetch-mode"), value: "navigate"),
        HTTPField(name: name("sec-fetch-site"), value: "same-origin"),
        HTTPField(name: .te, value: "trailers"),
    ] + cookieFields(2..<4)

/// 16 ordinary headers and 16 cookies.
let scalingFields32: [HTTPField] =
    scalingFields16 + [
        HTTPField(name: .authorization, value: "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"),
        HTTPField(name: .ifNoneMatch, value: "\"686897696a7c876b7e\""),
        HTTPField(name: .ifModifiedSince, value: "Mon, 03 Aug 2026 12:00:00 GMT"),
        HTTPField(name: .priority, value: "u=0, i"),
    ] + cookieFields(4..<16)

/// 16 ordinary headers and 48 cookies.
let scalingFields64: [HTTPField] = scalingFields32 + cookieFields(16..<48)

/// 16 ordinary headers and 112 cookies.
let scalingFields128: [HTTPField] = scalingFields64 + cookieFields(48..<112)

// MARK: - Building

/// Builds an `HTTPFields` by appending, to ensure the resulting `HTTPFields` backing array
/// is uniquely referenced.
private func makeFieldsByRebuild(_ fields: [HTTPField]) -> HTTPFields {
    var result = HTTPFields()
    result.reserveCapacity(fields.count)
    for field in fields {
        result.append(field)
    }
    return result
}

/// The two sides of an equality benchmark.
struct FieldsPair: Sendable {
    let lhs: HTTPFields
    let rhs: HTTPFields
}

/// Reverses the order of all non-`Cookie` fields, leaving every `Cookie` field in its original slot.
///
/// Two `HTTPFields` are equal regardless of the order of their differently named fields, but *not*
/// regardless of the order of the fields sharing one name. So only the fields with a unique name may
/// be permuted here; permuting the cookies would produce a value that is unequal rather than one
/// that is equal but differently ordered.
private func reorderingUniqueNames(_ fields: [HTTPField]) -> [HTTPField] {
    var reversed = fields.filter { $0.name != .cookie }.reversed().makeIterator()
    return fields.map { $0.name == .cookie ? $0 : reversed.next()! }
}

private let localDisplacementDistance = 3

private func displacingOneField(_ fields: [HTTPField]) -> [HTTPField] {
    precondition(fields.count > localDisplacementDistance, "list too short to displace a field within")
    var fields = fields
    let field = fields.removeFirst()
    fields.insert(field, at: localDisplacementDistance)
    return fields
}

/// The position of the one field that differs between the two sides of a "late mismatch" pair: 80%
/// into the list, so that the leading 80% is identical.
private func lateMismatchIndex(_ count: Int) -> Int {
    count * 4 / 5
}

/// Changes the value of the field 80% into the list, leaving everything else alone.
private func withLateMismatch(_ fields: [HTTPField]) -> [HTTPField] {
    var fields = fields
    let index = lateMismatchIndex(fields.count)
    let field = fields[index]
    fields[index] = HTTPField(name: field.name, value: field.value + "-mismatch")
    return fields
}

// MARK: - Cases

/// Everything the benchmarks need for one field count, precomputed so that no fixture construction
/// is ever measured.
struct ScalingCase: Sendable {
    /// The number of fields, i.e. the N the benchmark names refer to.
    let n: Int
    /// How many of the `n` fields are `Cookie` fields, i.e. how many of them share a single name.
    let cookieCount: Int
    /// The fields as a decoder would hand them over.
    let fields: [HTTPField]
    /// A prebuilt value for the read-only benchmarks.
    let readFields: HTTPFields

    /// Equal, and appended in the same order.
    let equalSameOrder: FieldsPair
    /// Equal, but with the uniquely named fields appended in the opposite order.
    let equalDifferentOrder: FieldsPair
    /// Equal, but with one field appended a few slots away from where the other side has it.
    let equalLocallyDisplaced: FieldsPair
    /// Unequal: the leading 80% is identical and in the same order, the field at 80% differs.
    ///
    /// Note what this does and does not pin down. It guarantees the shape — two field lists that
    /// differ in exactly one field, late in the list — which is the realistic way an inequality
    /// shows up. It does *not* guarantee that only 80% of the comparison work happens before the
    /// difference is found: the order in which `==` looks at fields is not part of its contract, so
    /// how much of the list it gets through first is not something a benchmark can fix.
    let mismatchSameOrder: FieldsPair
    /// Unequal in the same single field as `mismatchSameOrder`, with the uniquely named fields
    /// appended in the opposite order. The same caveat applies.
    let mismatchDifferentOrder: FieldsPair

    init(_ fields: [HTTPField]) {
        self.n = fields.count
        self.cookieCount = fields.filter { $0.name == .cookie }.count
        self.fields = fields
        self.readFields = makeFieldsByRebuild(fields)

        let mismatched = withLateMismatch(fields)
        self.equalSameOrder = FieldsPair(lhs: makeFieldsByRebuild(fields), rhs: makeFieldsByRebuild(fields))
        self.equalDifferentOrder = FieldsPair(
            lhs: makeFieldsByRebuild(fields),
            rhs: makeFieldsByRebuild(reorderingUniqueNames(fields))
        )
        self.equalLocallyDisplaced = FieldsPair(
            lhs: makeFieldsByRebuild(fields),
            rhs: makeFieldsByRebuild(displacingOneField(fields))
        )
        self.mismatchSameOrder = FieldsPair(lhs: makeFieldsByRebuild(fields), rhs: makeFieldsByRebuild(mismatched))
        self.mismatchDifferentOrder = FieldsPair(
            lhs: makeFieldsByRebuild(fields),
            rhs: makeFieldsByRebuild(reorderingUniqueNames(mismatched))
        )
    }
}

let scalingCases: [ScalingCase] = [
    ScalingCase(scalingFields8),
    ScalingCase(scalingFields16),
    ScalingCase(scalingFields32),
    ScalingCase(scalingFields64),
    ScalingCase(scalingFields128),
]

// MARK: - All distinct names

/// A field list of `count` fields whose names are all distinct: `n1` through `n<count>`.
private func distinctNameFields(_ count: Int) -> [HTTPField] {
    (1...count).map { HTTPField(name: name("n\($0)"), value: "value\($0)-aBcDeF0123456789") }
}

struct DistinctNameCase: Sendable {
    /// The number of fields, which is also the number of distinct names.
    let n: Int
    /// One list ordered by name against the same fields reversed.
    let sortedAgainstReversed: FieldsPair

    init(_ count: Int) {
        let fields = distinctNameFields(count)
        self.n = count
        self.sortedAgainstReversed = FieldsPair(
            lhs: makeFieldsByRebuild(fields),
            rhs: makeFieldsByRebuild(fields.reversed())
        )
    }
}

/// Runs past the 128 the other lists stop at, to cover both sides of the point where `==` hands off
/// to the by-name index.
let distinctNameCases: [DistinctNameCase] = [8, 16, 32, 64, 128, 256, 512].map(DistinctNameCase.init)

/// A name that is present in every field list, for the lookup and mutation benchmarks.
let scalingPresentName: HTTPField.Name = .userAgent

/// A name that is present in no field list, for the failing lookup and the insertion benchmarks.
let scalingAbsentName: HTTPField.Name = .transferEncoding

/// Asserts that the fixtures mean what their names claim.
///
/// A fixture that is silently equal when it should be unequal, or that turns out to be a copy of the
/// value it is compared against, produces a plausible-looking but meaningless curve, so this runs on
/// every benchmark invocation rather than being a one-off check.
func validateScalingFixtures() {
    let expectedSizes = [8, 16, 32, 64, 128]
    precondition(scalingCases.map(\.n) == expectedSizes, "unexpected field counts")

    for (smaller, larger) in zip(scalingCases, scalingCases.dropFirst()) {
        precondition(Array(larger.fields.prefix(smaller.n)) == smaller.fields, "N=\(larger.n) is not nested")
    }

    for scalingCase in scalingCases {
        let n = scalingCase.n
        precondition(scalingCase.readFields.count == n, "N=\(n): wrong field count")
        precondition(scalingCase.readFields.contains(scalingPresentName), "N=\(n): missing present name")
        precondition(!scalingCase.readFields.contains(scalingAbsentName), "N=\(n): absent name is present")
        precondition(scalingCase.readFields[values: .cookie].count == scalingCase.cookieCount, "N=\(n): cookie count")

        let pairs = [
            ("equal, same order", scalingCase.equalSameOrder, true),
            ("equal, different order", scalingCase.equalDifferentOrder, true),
            ("equal, locally displaced", scalingCase.equalLocallyDisplaced, true),
            ("differs at 80%, same order", scalingCase.mismatchSameOrder, false),
            ("differs at 80%, different order", scalingCase.mismatchDifferentOrder, false),
        ]
        for (description, pair, expected) in pairs {
            precondition(pair.lhs.count == n && pair.rhs.count == n, "N=\(n): \(description) has wrong field count")
            precondition((pair.lhs == pair.rhs) == expected, "N=\(n): \(description) is not \(expected)")
            precondition(
                HTTPFields.isEqualByNameIndex(pair.lhs, pair.rhs) == expected,
                "N=\(n): \(description): isEqualByNameIndex disagrees with =="
            )
        }

        let reorderedPairs = [
            ("equal, different order", scalingCase.equalDifferentOrder),
            ("equal, locally displaced", scalingCase.equalLocallyDisplaced),
        ]
        for (description, pair) in reorderedPairs {
            precondition(
                n < 2 || !Array(pair.lhs).elementsEqual(pair.rhs),
                "N=\(n): \(description) is actually in the same order"
            )
        }

        let displaced = scalingCase.equalLocallyDisplaced
        let movedPositions = zip(Array(displaced.lhs), Array(displaced.rhs)).enumerated()
            .filter { $0.element.0 != $0.element.1 }
            .map(\.offset)
        precondition(
            movedPositions == Array(0...localDisplacementDistance),
            "N=\(n): locally displaced pair disturbs \(movedPositions.count) positions, not \(localDisplacementDistance + 1)"
        )
    }

    for distinctNameCase in distinctNameCases {
        let n = distinctNameCase.n
        let pair = distinctNameCase.sortedAgainstReversed
        precondition(pair.lhs.count == n && pair.rhs.count == n, "distinct N=\(n): wrong field count")
        precondition(Set(pair.lhs.map(\.name)).count == n, "distinct N=\(n): names are not all distinct")
        precondition(pair.lhs == pair.rhs, "distinct N=\(n): not equal")
        precondition(
            HTTPFields.isEqualByNameIndex(pair.lhs, pair.rhs) == true,
            "distinct N=\(n): isEqualByNameIndex disagrees with =="
        )
        precondition(
            !Array(pair.lhs).elementsEqual(pair.rhs),
            "distinct N=\(n): actually in the same order"
        )
    }
}
