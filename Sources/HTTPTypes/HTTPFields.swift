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

/// A collection of HTTP fields. It is used in `HTTPRequest` and `HTTPResponse`, and can also be
/// used as HTTP trailer fields.
///
/// HTTP fields are an ordered list of name-value pairs. Each field is represented as an instance
/// of `HTTPField` struct. `HTTPFields` also offers conveniences to look up fields by their names.
///
/// `HTTPFields` adheres to modern HTTP semantics. In particular, the "Cookie" request header field
/// is split into separate header fields by default.
@available(HTTPTypes 1.0, *)
public struct HTTPFields: Sendable {
    /// The fields, in the order they were added.
    private var fields: [HTTPField] = []

    /// Create an empty list of HTTP fields
    public init() {}

    /// The position of the first field at or after `start` whose canonical name is `name`, or
    /// `nil` if there is none.
    private func firstIndex(ofCanonicalName name: String, from start: [HTTPField].Index = 0) -> Int? {
        self.fields[start...].firstIndex(where: { $0.name.canonicalName == name })
    }

    private mutating func append(field: HTTPField) {
        precondition(!field.name.isPseudo, "Pseudo header field \"\(field.name)\" disallowed")
        self.fields.append(field)
        precondition(self.fields.count < UInt16.max, "Too many fields")
    }

    /// Access the field value string by name.
    ///
    /// Example:
    /// ```swift
    /// // Set a header field in the request.
    /// request.headerFields[.accept] = "*/*"
    ///
    /// // Access a header field value from the response.
    /// let contentTypeValue = response.headerFields[.contentType]
    /// ```
    ///
    /// If multiple fields with the same name exist, they are concatenated with commas (or
    /// semicolons in the case of the "Cookie" header field).
    ///
    /// When setting a "Cookie" header field value, it is split into multiple "Cookie" fields by
    /// semicolon.
    public subscript(name: HTTPField.Name) -> String? {
        get {
            let fields = self.fields(for: name)
            if fields.first(where: { _ in true }) != nil {
                let separator = name == .cookie ? "; " : ", "
                return fields.lazy.map { $0.value }.joined(separator: separator)
            } else {
                return nil
            }
        }
        set {
            if let newValue {
                #if !hasFeature(Embedded)
                if #available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *),
                    name == .cookie
                {
                    self.setFields(
                        newValue.split(separator: "; ", omittingEmptySubsequences: false).lazy.map {
                            HTTPField(name: name, value: String($0))
                        },
                        for: name
                    )
                    return
                }
                #endif
                self.setFields(CollectionOfOne(HTTPField(name: name, value: newValue)), for: name)
            } else {
                self.setFields(EmptyCollection(), for: name)
            }
        }
    }

    /// Access the field values by name as an array of strings. The order of fields is preserved.
    public subscript(values name: HTTPField.Name) -> [String] {
        get {
            self.fields(for: name).map { $0.value }
        }
        set {
            self.setFields(newValue.lazy.map { HTTPField(name: name, value: $0) }, for: name)
        }
    }

    /// Access the fields by name as an array. The order of fields is preserved.
    public subscript(fields name: HTTPField.Name) -> [HTTPField] {
        get {
            Array(self.fields(for: name))
        }
        set {
            self.setFields(newValue, for: name)
        }
    }

    private struct HTTPFieldSequence: Sequence {
        let fields: HTTPFields
        let name: HTTPField.Name

        struct Iterator: IteratorProtocol {
            let fields: HTTPFields
            let name: HTTPField.Name
            /// The position to resume scanning at. Keeping it in the iterator makes reading all
            /// the fields with one name a single pass over `fields`.
            var index: Int

            init(fields: HTTPFields, name: HTTPField.Name) {
                self.fields = fields
                self.name = name
                self.index = fields.startIndex
            }

            mutating func next() -> HTTPField? {
                if let index = self.fields.firstIndex(ofCanonicalName: self.name.canonicalName, from: self.index) {
                    defer { self.index = self.fields.index(after: index) }
                    return self.fields[index]
                }
                return nil
            }
        }

        func makeIterator() -> Iterator {
            Iterator(fields: self.fields, name: self.name)
        }
    }

    private func fields(for name: HTTPField.Name) -> HTTPFieldSequence {
        HTTPFieldSequence(fields: self, name: name)
    }

    private mutating func setFields(_ fieldSequence: some Sequence<HTTPField>, for name: HTTPField.Name) {
        let canonicalName = name.canonicalName
        var existingIndex = self.firstIndex(ofCanonicalName: canonicalName)
        var newFieldIterator = fieldSequence.makeIterator()
        var toDelete = [Int]()
        // A single pass over the fields: the existing fields with this name are overwritten in
        // place while new fields last, and the leftovers are collected for removal.
        while let index = existingIndex {
            if let field = newFieldIterator.next() {
                self.fields[index] = field
            } else {
                toDelete.append(index)
            }
            existingIndex = self.firstIndex(ofCanonicalName: canonicalName, from: index + 1)
        }
        if !toDelete.isEmpty {
            self.fields.remove(at: toDelete)
        }
        while let field = newFieldIterator.next() {
            self.append(field: field)
        }
    }

    /// Whether one or more field with this name exists in the fields.
    /// - Parameter name: The field name.
    /// - Returns: Whether a field exists.
    public func contains(_ name: HTTPField.Name) -> Bool {
        self.firstIndex(ofCanonicalName: name.canonicalName) != nil
    }
}

extension HTTPFields: Equatable {
    public static func == (lhs: HTTPFields, rhs: HTTPFields) -> Bool {
        // Two field lists are equal when, for every name, they hold the same fields in the same
        // order. Fields with different names may be interleaved differently.

        // Note:
        // Within the code comments here, the following names are used:
        //  `Element` -> a `HTTPField` inside the `HTTPFields`
        //  `Fields` -> a `HTTPFields`

        // When checking for equality we try two approaches:
        //  1. We walk both fields' elements in lock-step. To support ordering differences within the
        //     fields, we use `pending` arrays, to store elements that have not appeared in the other.
        //     This approach is very fast if the two candidates have mostly the same order, however
        //     if the orders are vastly different, this approach can scale quadratic. Because of this,
        //     if the `pending` arrays grows too large (>= `maxFieldsToScan`) and there are enough fields
        //     remaining (>=`minFieldsToIndexByName`), we will stop the lockstep approach and instead
        //     fallback to:
        //  2. An approach in which we build a dictionary from one field list and then remove items
        //     from it based on the other one. This scales linear but has significant build costs,
        //     since it needs to hash every field name twice.

        if lhs.fields.count != rhs.fields.count {
            return false
        }

        // The index of the fields on either side whose equivalent on the other side has not
        // turned up yet. Indexes are stored instead of fields, as this reduces ARC traffic.
        // Both arrays remain empty for as long as the two fields hold the same elements in exactly
        // the same order. After each iteration both arrays have the same length.
        var pendingLeft = [Int]()
        var pendingRight = [Int]()
        for index in lhs.fields.indices {
            // A direct element comparison can only be done if there are no elements in the pending
            // arrays. This because to ensure correct ordering, all the other sides' unpaired
            // elements have to be considered before the current element of the other side can be
            // considered.
            if pendingLeft.isEmpty {
                if lhs.fields[index].name == rhs.fields[index].name {
                    if lhs.fields[index].value == rhs.fields[index].value {
                        // name and values match. check the next elements
                        continue
                    } else {
                        // if the elements' names are equal but the elements are unequal, the elements must
                        // have different values -> early exit here, since the fields have no pending
                        // candidates, that need to be checked first.
                        return false
                    }
                } else {
                    // If the elements' names are unequal, we are dealing with different elements.
                    // Because of that, we have to compare them against later candidates. In order to reduce
                    // allocations, reserve array capacity first.
                    let remaining = lhs.fields.count - index
                    pendingLeft.reserveCapacity(remaining)
                    pendingRight.reserveCapacity(remaining)
                }
            }

            let leftName = lhs.fields[index].name
            if let match = pendingRight.firstIndex(where: { rhs.fields[$0].name == leftName }) {
                // The n-th value for a name on one side can only ever pair with the n-th value of that
                // same name on the other, so a disagreement means the order of values is different,
                // which means the http fields are different.
                if rhs.fields[pendingRight[match]] != lhs.fields[index] {
                    return false
                }
                pendingRight.remove(at: match)
            } else {
                pendingLeft.append(index)
            }
            let rightName = rhs.fields[index].name
            if let match = pendingLeft.firstIndex(where: { lhs.fields[$0].name == rightName }) {
                if lhs.fields[pendingLeft[match]] != rhs.fields[index] {
                    return false
                }
                pendingLeft.remove(at: match)
            } else {
                pendingRight.append(index)
            }

            if pendingLeft.count >= Self.maxFieldsToScan,
                lhs.fields.count - index >= Self.minFieldsToIndexByName
            {
                return Self.isEqualByNameIndex(lhs, rhs)
            }
        }
        // Both arrays hold the same count here, so one being empty means both are. If both are
        // empty, all elements found a partner.
        return pendingLeft.isEmpty
    }

    /// How many fields can be unresolved before the lock-step algorithm falls back to the `is`
    /// them by name instead. Set from measurement, and reached only by a list far more disordered than
    /// a real message: it needs this many distinctly named fields displaced at once, where real
    /// messages carry 16 to 30 distinct names in total.
    private static var maxFieldsToScan: Int { 32 }

    /// How much of the list has to be left for indexing the set aside fields to be worth what the
    /// index costs to build. Below this, scanning finishes sooner even when it is scanning a lot.
    private static var minFieldsToIndexByName: Int { 64 }

    /// Answers the same question as `==` by indexing one side by name up front and then draining
    /// that index while walking the other.
    ///
    /// This is linear, but it hashes every name twice and allocates per name, which costs roughly two
    /// orders of magnitude more per field than a lock step pass.
    static func isEqualByNameIndex(_ lhs: HTTPFields, _ rhs: HTTPFields) -> Bool {
        if lhs.fields.count != rhs.fields.count {
            return false
        }
        // The fields of `rhs`, grouped by name. Fields sharing a name have to appear in the same
        // order on both sides. Since we don't want to import swift-collections' Deque, we need
        // another way to create a FIFO structure: By adding the fields to the dictionary in reverse
        // order, we'll add later values first to the name array. This is great as it allows us,
        // when iterating the lhs fields, to remove values from the end of the values array for a
        // given name.
        var remaining = [String: [HTTPField]](minimumCapacity: lhs.fields.count)
        for field in rhs.fields.reversed() {
            remaining[field.name.canonicalName, default: []].append(field)
        }
        for field in lhs.fields {
            // One hash lookup, then the group is drained in place through its index.
            guard let group = remaining.index(forKey: field.name.canonicalName),
                let candidate = remaining.values[group].last
            else {
                // `other` has no field of this name left to pair with this one.
                return false
            }
            if candidate != field {
                return false
            }
            remaining.values[group].removeLast()
        }
        // The groups held as many fields as this list has, and each of them just gave one up, so
        // they are all drained and every field of `other` was paired off.
        return true
    }
}

extension HTTPFields: Hashable {
    public func hash(into hasher: inout Hasher) {
        for field in self.fields {
            hasher.combine(field)
        }
    }
}

@available(HTTPTypes 1.0, *)
extension HTTPFields: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (HTTPField.Name, String)...) {
        self.reserveCapacity(elements.count)
        for (name, value) in elements {
            precondition(!name.isPseudo, "Pseudo header field \"\(name)\" disallowed")
            self.append(field: HTTPField(name: name, value: value))
        }
        precondition(self.count < UInt16.max, "Too many fields")
    }
}

@available(HTTPTypes 1.0, *)
extension HTTPFields: RangeReplaceableCollection, RandomAccessCollection, MutableCollection {
    public typealias Element = HTTPField
    public typealias Index = Int

    public var startIndex: Int {
        self.fields.startIndex
    }

    public var endIndex: Int {
        self.fields.endIndex
    }

    public var isEmpty: Bool {
        self.fields.isEmpty
    }

    public subscript(position: Int) -> HTTPField {
        get {
            guard position >= self.startIndex, position < self.endIndex else {
                preconditionFailure("getter position: \(position) out of range in HTTPFields")
            }
            return self.fields[position]
        }
        set {
            guard position >= self.startIndex, position < self.endIndex else {
                preconditionFailure("setter position: \(position) out of range in HTTPFields")
            }
            if self.fields[position] == newValue {
                return
            }
            if newValue.name != self.fields[position].name {
                precondition(!newValue.name.isPseudo, "Pseudo header field \"\(newValue.name)\" disallowed")
            }
            self.fields[position] = newValue
        }
    }

    public mutating func replaceSubrange<C>(_ subrange: Range<Int>, with newElements: C)
    where C: Collection, Element == C.Element {
        if subrange.startIndex == self.count {
            for field in newElements {
                precondition(!field.name.isPseudo, "Pseudo header field \"\(field.name)\" disallowed")
                self.append(field: field)
            }
        } else {
            self.fields.replaceSubrange(
                subrange,
                with: newElements.lazy.map { field in
                    precondition(!field.name.isPseudo, "Pseudo header field \"\(field.name)\" disallowed")
                    return field
                }
            )
            precondition(self.count < UInt16.max, "Too many fields")
        }
    }

    public mutating func reserveCapacity(_ capacity: Int) {
        self.fields.reserveCapacity(capacity)
    }
}

#if !hasFeature(Embedded)

@available(HTTPTypes 1.0, *)
extension HTTPFields: CustomDebugStringConvertible {
    public var debugDescription: String {
        self.fields.description
    }
}

@available(HTTPTypes 1.0, *)
extension HTTPFields: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(contentsOf: self)
    }

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        if let count = container.count {
            self.reserveCapacity(count)
        }
        while !container.isAtEnd {
            let field = try container.decode(HTTPField.self)
            guard !field.name.isPseudo else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Pseudo header field \"\(field)\" disallowed"
                )
            }
            self.append(field)
        }
    }
}

#endif

extension Array {
    // `removalIndices` must be ordered.
    mutating func remove(at removalIndices: some Sequence<Index>) {
        var offset = 0
        var iterator = removalIndices.makeIterator()
        var nextToRemoveOptional = iterator.next()
        for index in self.indices {
            while let nextToRemove = nextToRemoveOptional, self.index(index, offsetBy: offset) == nextToRemove {
                offset += 1
                nextToRemoveOptional = iterator.next()
            }
            let toKeep = self.index(index, offsetBy: offset)
            if toKeep < self.endIndex {
                self.swapAt(index, toKeep)
            } else {
                break
            }
        }
        removeLast(offset)
    }
}
