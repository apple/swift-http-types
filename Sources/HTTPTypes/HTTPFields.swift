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
        // Two field lists are equal when, for every name, they hold the same fields in the
        // same order. That implies an equal total field count, so checking it up front also
        // proves that matching every name run of `lhs` leaves no unmatched field in `rhs`.
        if lhs.fields.count != rhs.fields.count {
            return false
        }
        // Fast path: field lists that were built the same way carry their fields in the same
        // order, so a single lock step walk usually settles it. Element wise equality is
        // sufficient, but not necessary, for the definition above, so a mismatch only means the
        // general comparison below has to run.
        if lhs.fields.elementsEqual(rhs.fields) {
            return true
        }
        for position in lhs.fields.indices {
            let name = lhs.fields[position].name.canonicalName
            if lhs.firstIndex(ofCanonicalName: name) != position {
                // Not the first field with this name; its run was compared already.
                continue
            }
            var leftIndex: Int? = position
            var rightIndex = rhs.firstIndex(ofCanonicalName: name)
            while let left = leftIndex, let right = rightIndex {
                if lhs.fields[left] != rhs.fields[right] {
                    return false
                }
                leftIndex = lhs.firstIndex(ofCanonicalName: name, from: left + 1)
                rightIndex = rhs.firstIndex(ofCanonicalName: name, from: right + 1)
            }
            if (leftIndex == nil) != (rightIndex == nil) {
                // One of the two runs of this name is longer than the other.
                return false
            }
        }
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
