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

#if compiler(>=6.0)
import Synchronization
#endif  // compiler(>=6.0)

/// A collection of HTTP fields. It is used in `HTTPRequest` and `HTTPResponse`, and can also be
/// used as HTTP trailer fields.
///
/// HTTP fields are an ordered list of name-value pairs. Each field is represented as an instance
/// of `HTTPField` struct. `HTTPFields` also offers conveniences to look up fields by their names.
///
/// `HTTPFields` adheres to modern HTTP semantics. In particular, the "Cookie" request header field
/// is split into separate header fields by default.
public struct HTTPFields: Sendable, Hashable {
    private class _Storage: @unchecked Sendable, Hashable {
        var fields: [(field: HTTPField, next: UInt16)] = []
        var index: [String: (first: UInt16, last: UInt16)]? = [:]

        required init() {
        }

        func withLock<Result>(_ body: () throws -> Result) rethrows -> Result {
            fatalError()
        }

        var ensureIndex: [String: (first: UInt16, last: UInt16)] {
            self.withLock {
                if let index = self.index {
                    return index
                }
                var newIndex = [String: (first: UInt16, last: UInt16)]()
                for index in self.fields.indices {
                    let name = self.fields[index].field.name.canonicalName
                    self.fields[index].next = .max
                    if let lastIndex = newIndex[name]?.last {
                        self.fields[Int(lastIndex)].next = UInt16(index)
                    }
                    newIndex[name, default: (first: UInt16(index), last: 0)].last = UInt16(index)
                }
                self.index = newIndex
                return newIndex
            }
        }

        func copy() -> Self {
            let newStorage = Self()
            newStorage.fields = self.fields
            self.withLock {
                newStorage.index = self.index
            }
            return newStorage
        }

        func hash(into hasher: inout Hasher) {
            for (field, _) in self.fields {
                hasher.combine(field)
            }
        }

        static func == (lhs: _Storage, rhs: _Storage) -> Bool {
            let leftFieldsIndex = lhs.ensureIndex
            let rightFieldsIndex = rhs.ensureIndex
            if leftFieldsIndex.count != rightFieldsIndex.count {
                return false
            }
            for (name, (var leftIndex, _)) in leftFieldsIndex {
                guard var rightIndex = rightFieldsIndex[name]?.first else {
                    return false
                }
                while leftIndex != .max && rightIndex != .max {
                    let (leftField, leftNext) = lhs.fields[Int(leftIndex)]
                    let (rightField, rightNext) = rhs.fields[Int(rightIndex)]
                    if leftField != rightField {
                        return false
                    }
                    leftIndex = leftNext
                    rightIndex = rightNext
                }
                if leftIndex != rightIndex {
                    return false
                }
            }
            return true
        }

        func append(field: HTTPField) {
            precondition(!field.name.isPseudo, "Pseudo header field \"\(field.name)\" disallowed")
            let name = field.name.canonicalName
            let location = UInt16(self.fields.count)
            if let index = self.index?[name] {
                self.fields[Int(index.last)].next = location
            }
            self.index?[name, default: (first: location, last: 0)].last = location
            self.fields.append((field, .max))
            precondition(self.fields.count < UInt16.max, "Too many fields")
        }
    }

    #if compiler(>=6.0)
    @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    private final class _StorageWithMutex: _Storage, @unchecked Sendable {
        let mutex = Mutex<Void>(())

        override func withLock<Result>(_ body: () throws -> Result) rethrows -> Result {
            try self.mutex.withLock { _ in
                try body()
            }
        }
    }
    #endif  // compiler(>=6.0)

    private final class _StorageWithNIOLock: _Storage, @unchecked Sendable {
        let lock = LockStorage.create(value: ())

        override func withLock<Result>(_ body: () throws -> Result) rethrows -> Result {
            try self.lock.withLockedValue { _ in
                try body()
            }
        }
    }

    private var _storage = {
        #if compiler(>=6.0)
        if #available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *) {
            _StorageWithMutex()
        } else {
            _StorageWithNIOLock()
        }
        #else  // compiler(>=6.0)
        _StorageWithNIOLock()
        #endif  // compiler(>=6.0)
    }()

    /// Create an empty list of HTTP fields
    public init() {}

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
                return fields.lazy.map(\.value).joined(separator: separator)
            } else {
                return nil
            }
        }
        set {
            if let newValue {
                if #available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *),
                    name == .cookie
                {
                    self.setFields(
                        newValue.split(separator: "; ", omittingEmptySubsequences: false).lazy.map {
                            HTTPField(name: name, value: String($0))
                        },
                        for: name
                    )
                } else {
                    self.setFields(CollectionOfOne(HTTPField(name: name, value: newValue)), for: name)
                }
            } else {
                self.setFields(EmptyCollection(), for: name)
            }
        }
    }

    /// Access the field values by name as an array of strings. The order of fields is preserved.
    public subscript(values name: HTTPField.Name) -> [String] {
        get {
            self.fields(for: name).map(\.value)
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
        let fields: [(field: HTTPField, next: UInt16)]
        let index: UInt16

        struct Iterator: IteratorProtocol {
            let fields: [(field: HTTPField, next: UInt16)]
            var index: UInt16

            mutating func next() -> HTTPField? {
                if self.index == .max {
                    return nil
                }
                let (field, next) = self.fields[Int(self.index)]
                self.index = next
                return field
            }
        }

        func makeIterator() -> Iterator {
            Iterator(fields: self.fields, index: self.index)
        }
    }

    private func fields(for name: HTTPField.Name) -> HTTPFieldSequence {
        let index = self._storage.ensureIndex[name.canonicalName]?.first ?? .max
        return HTTPFieldSequence(fields: self._storage.fields, index: index)
    }

    private mutating func setFields(_ fieldSequence: some Sequence<HTTPField>, for name: HTTPField.Name) {
        if !isKnownUniquelyReferenced(&self._storage) {
            self._storage = self._storage.copy()
        }
        var existingIndex = self._storage.ensureIndex[name.canonicalName]?.first ?? .max
        var newFieldIterator = fieldSequence.makeIterator()
        var toDelete = [Int]()
        while existingIndex != .max {
            if let field = newFieldIterator.next() {
                self._storage.fields[Int(existingIndex)].field = field
            } else {
                toDelete.append(Int(existingIndex))
            }
            existingIndex = self._storage.fields[Int(existingIndex)].next
        }
        if !toDelete.isEmpty {
            self._storage.fields.remove(at: toDelete)
            self._storage.index = nil
        }
        while let field = newFieldIterator.next() {
            self._storage.append(field: field)
        }
    }

    /// Whether one or more field with this name exists in the fields.
    /// - Parameter name: The field name.
    /// - Returns: Whether a field exists.
    public func contains(_ name: HTTPField.Name) -> Bool {
        self._storage.ensureIndex[name.canonicalName] != nil
    }
}

extension HTTPFields: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (HTTPField.Name, String)...) {
        self.reserveCapacity(elements.count)
        for (name, value) in elements {
            precondition(!name.isPseudo, "Pseudo header field \"\(name)\" disallowed")
            self._storage.append(field: HTTPField(name: name, value: value))
        }
        precondition(self.count < UInt16.max, "Too many fields")
    }
}

extension HTTPFields: RangeReplaceableCollection, RandomAccessCollection, MutableCollection {
    public typealias Element = HTTPField
    public typealias Index = Int

    public var startIndex: Int {
        self._storage.fields.startIndex
    }

    public var endIndex: Int {
        self._storage.fields.endIndex
    }

    public var isEmpty: Bool {
        self._storage.fields.isEmpty
    }

    public subscript(position: Int) -> HTTPField {
        get {
            guard position >= self.startIndex, position < self.endIndex else {
                preconditionFailure("getter position: \(position) out of range in HTTPFields")
            }
            return self._storage.fields[position].field
        }
        set {
            guard position >= self.startIndex, position < self.endIndex else {
                preconditionFailure("setter position: \(position) out of range in HTTPFields")
            }
            if self._storage.fields[position].field == newValue {
                return
            }
            if !isKnownUniquelyReferenced(&self._storage) {
                self._storage = self._storage.copy()
            }
            if newValue.name != self._storage.fields[position].field.name {
                precondition(!newValue.name.isPseudo, "Pseudo header field \"\(newValue.name)\" disallowed")
                self._storage.index = nil
            }
            self._storage.fields[position].field = newValue
        }
    }

    public mutating func replaceSubrange<C>(_ subrange: Range<Int>, with newElements: C)
    where C: Collection, Element == C.Element {
        if !isKnownUniquelyReferenced(&self._storage) {
            self._storage = self._storage.copy()
        }
        if subrange.startIndex == self.count {
            for field in newElements {
                precondition(!field.name.isPseudo, "Pseudo header field \"\(field.name)\" disallowed")
                self._storage.append(field: field)
            }
        } else {
            self._storage.index = nil
            self._storage.fields.replaceSubrange(
                subrange,
                with: newElements.lazy.map { field in
                    precondition(!field.name.isPseudo, "Pseudo header field \"\(field.name)\" disallowed")
                    return (field, 0)
                }
            )
            precondition(self.count < UInt16.max, "Too many fields")
        }
    }

    public mutating func reserveCapacity(_ capacity: Int) {
        if !isKnownUniquelyReferenced(&self._storage) {
            self._storage = self._storage.copy()
        }
        self._storage.index?.reserveCapacity(capacity)
        self._storage.fields.reserveCapacity(capacity)
    }
}

extension HTTPFields: CustomDebugStringConvertible {
    public var debugDescription: String {
        self._storage.fields.description
    }
}

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
