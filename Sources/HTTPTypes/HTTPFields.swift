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

#if canImport(os.lock)
@_implementationOnly import os.lock
#else
@_implementationOnly import Glibc
#endif

/// A collection of HTTP fields. It is used in `HTTPRequest` and `HTTPResponse`, and can also be
/// used as HTTP trailer fields.
///
/// HTTP fields are an ordered list of name-value pairs. Each field is represented as an instance
/// of `HTTPField` struct. `HTTPFields` also offers conveniences to look up fields by their names.
///
/// `HTTPFields` adheres to modern HTTP semantics. In particular, the "Cookie" request header field
/// is split into separate header fields by default.
public struct HTTPFields: Sendable, Hashable, Codable {
    private final class _Storage: @unchecked Sendable, Hashable, Codable {
        var fields: [(HTTPField, UInt16)] = []
        var index: [String: UInt16]? = [:]
        #if canImport(os.lock)
        let lock = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)
        #else
        let lock = UnsafeMutablePointer<pthread_mutex_t>.allocate(capacity: 1)
        #endif

        init() {
            #if canImport(os.lock)
            self.lock.initialize(to: os_unfair_lock())
            #else
            let err = pthread_mutex_init(self.lock, nil)
            precondition(err == 0, "pthread_mutex_init failed with error \(err)")
            #endif
        }

        deinit {
            #if !canImport(os.lock)
            let err = pthread_mutex_destroy(self.lock)
            precondition(err == 0, "pthread_mutex_destroy failed with error \(err)")
            #endif
            self.lock.deallocate()
        }

        var ensureIndex: [String: UInt16] {
            #if canImport(os.lock)
            os_unfair_lock_lock(self.lock)
            defer { os_unfair_lock_unlock(self.lock) }
            #else
            let err = pthread_mutex_lock(self.lock)
            precondition(err == 0, "pthread_mutex_lock failed with error \(err)")
            defer {
                let err = pthread_mutex_unlock(self.lock)
                precondition(err == 0, "pthread_mutex_unlock failed with error \(err)")
            }
            #endif
            if let index = self.index {
                return index
            }
            var newIndex = [String: UInt16]()
            for index in self.fields.indices.reversed() {
                let name = self.fields[index].0.name.canonicalName
                self.fields[index].1 = newIndex[name] ?? .max
                newIndex[name] = UInt16(index)
            }
            self.index = newIndex
            return newIndex
        }

        func copy() -> _Storage {
            let newStorage = _Storage()
            newStorage.fields = self.fields
            #if canImport(os.lock)
            os_unfair_lock_lock(self.lock)
            #else
            do {
                let err = pthread_mutex_lock(self.lock)
                precondition(err == 0, "pthread_mutex_lock failed with error \(err)")
            }
            #endif
            newStorage.index = self.index
            #if canImport(os.lock)
            os_unfair_lock_unlock(self.lock)
            #else
            do {
                let err = pthread_mutex_unlock(self.lock)
                precondition(err == 0, "pthread_mutex_unlock failed with error \(err)")
            }
            #endif
            return newStorage
        }

        func hash(into hasher: inout Hasher) {
            for (field, _) in self.fields {
                hasher.combine(field)
            }
        }

        static func == (lhs: _Storage, rhs: _Storage) -> Bool {
            lhs.fields.lazy.map(\.0) == rhs.fields.lazy.map(\.0)
        }

        func append(field: HTTPField) {
            let name = field.name.canonicalName
            if var index = self.index?[name] {
                while true {
                    let next = self.fields[Int(index)].1
                    if next == .max { break }
                    index = next
                }
                self.fields[Int(index)].1 = UInt16(self.fields.count)
            } else {
                self.index?[name] = UInt16(self.fields.count)
            }
            self.fields.append((field, .max))
        }

        private enum CodingKeys: String, CodingKey {
            case fields0
            case fields1
            case index
        }

        convenience init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let fields0 = try container.decode([HTTPField].self, forKey: .fields0)
            let fields1 = try container.decode([UInt16].self, forKey: .fields1)
            let index = try container.decodeIfPresent([String: UInt16].self, forKey: .index)
            self.init()
            self.fields = zip(fields0, fields1).map { ($0, $1) }
            self.index = index
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(fields.map(\.0), forKey: .fields0)
            try container.encode(fields.map(\.1), forKey: .fields1)
            try container.encodeIfPresent(index, forKey: .index)
        }
    }

    private var _storage = _Storage()

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
            let values = self[raw: name]
            if !values.isEmpty {
                let separator = name == .cookie ? "; " : ", "
                return values.joined(separator: separator)
            } else {
                return nil
            }
        }
        set {
            if let newValue {
                if #available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *),
                   name == .cookie {
                    self[fields: name] = newValue.split(separator: "; ", omittingEmptySubsequences: false).map {
                        HTTPField(name: name, value: String($0))
                    }
                } else {
                    self[raw: name] = [newValue]
                }
            } else {
                self[raw: name] = []
            }
        }
    }

    /// Access the field values by name as an array of strings. The order of fields is preserved.
    public subscript(raw name: HTTPField.Name) -> [String] {
        get {
            self[fields: name].map(\.value)
        }
        set {
            self[fields: name] = newValue.map { HTTPField(name: name, value: $0) }
        }
    }

    /// Access the fields by name as an array. The order of fields is preserved.
    public subscript(fields name: HTTPField.Name) -> [HTTPField] {
        get {
            var fields = [HTTPField]()
            var index = self._storage.ensureIndex[name.canonicalName] ?? .max
            while index != .max {
                let (field, next) = self._storage.fields[Int(index)]
                fields.append(field)
                index = next
            }
            return fields
        }
        set {
            if !isKnownUniquelyReferenced(&self._storage) {
                self._storage = self._storage.copy()
            }
            var existingIndex = self._storage.ensureIndex[name.canonicalName] ?? .max
            var newFieldIterator = newValue.makeIterator()
            var toDelete = [Int]()
            while existingIndex != .max {
                if let field = newFieldIterator.next() {
                    self._storage.fields[Int(existingIndex)].0 = field
                } else {
                    toDelete.append(Int(existingIndex))
                }
                existingIndex = self._storage.fields[Int(existingIndex)].1
            }
            if !toDelete.isEmpty {
                self._storage.fields.remove(at: toDelete)
                self._storage.index = nil
            }
            while let field = newFieldIterator.next() {
                self._storage.append(field: field)
            }
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
        for (name, value) in elements {
            self._storage.append(field: HTTPField(name: name, value: value))
        }
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
            return self._storage.fields[position].0
        }
        set {
            guard position >= self.startIndex, position < self.endIndex else {
                preconditionFailure("setter position: \(position) out of range in HTTPFields")
            }
            if self._storage.fields[position].0 == newValue {
                return
            }
            if !isKnownUniquelyReferenced(&self._storage) {
                self._storage = self._storage.copy()
            }
            if newValue.name != self._storage.fields[position].0.name {
                self._storage.index = nil
            }
            self._storage.fields[position].0 = newValue
        }
    }

    public mutating func replaceSubrange<C>(_ subrange: Range<Int>, with newElements: C) where C: Collection, Element == C.Element {
        if !isKnownUniquelyReferenced(&self._storage) {
            self._storage = self._storage.copy()
        }
        if subrange.startIndex == count {
            for field in newElements {
                self._storage.append(field: field)
            }
        } else {
            self._storage.index = nil
            self._storage.fields.replaceSubrange(subrange, with: newElements.lazy.map { ($0, 0) })
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
