//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift HTTP Types open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift HTTP Types project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift HTTP Types project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

#if canImport(os.lock)
@_implementationOnly import os.lock
#else
@_implementationOnly import Glibc
#endif

/// A collection of HTTP fields. It is used in `HTTPRequest` and `HTTPResponse`, and also used for
/// HTTP trailer fields.
///
/// HTTP fields are an ordered list of name-value pairs. Each field is represented as an instance
/// of `HTTPField` struct. `HTTPFields` also offers conveniences to look up fields by their names.
///
/// `HTTPFields` adheres to modern HTTP semantics. In particular, the "Cookie" request header field
/// is split into separate header fields by default.
public struct HTTPFields: Sendable, Hashable {
    private final class _Storage: @unchecked Sendable, Hashable {
        var fields: [(HTTPField, UInt16)] = []
        var index: [String: UInt16]? = [:]
#if canImport(os.lock)
        let lock = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)
#else
        let lock = UnsafeMutablePointer<pthread_mutex_t>.allocate(capacity: 1)
#endif

        init() {
#if canImport(os.lock)
            lock.initialize(to: os_unfair_lock())
#else
            let err = pthread_mutex_init(lock, nil)
            precondition(err == 0, "pthread_mutex_init failed with error \(err)")
#endif
        }

        deinit {
#if !canImport(os.lock)
            let err = pthread_mutex_destroy(lock)
            precondition(err == 0, "pthread_mutex_destroy failed with error \(err)")
#endif
            lock.deallocate()
        }

        var ensureIndex: [String: UInt16] {
#if canImport(os.lock)
            os_unfair_lock_lock(lock)
            defer { os_unfair_lock_unlock(lock) }
#else
            let err = pthread_mutex_lock(lock)
            precondition(err == 0, "pthread_mutex_lock failed with error \(err)")
            defer {
                let err = pthread_mutex_unlock(lock)
                precondition(err == 0, "pthread_mutex_unlock failed with error \(err)")
            }
#endif
            if let index = index {
                return index
            }
            var newIndex = [String: UInt16]()
            for i in fields.indices.reversed() {
                let name = fields[i].0.name.canonicalName
                fields[i].1 = newIndex[name] ?? .max
                newIndex[name] = UInt16(i)
            }
            index = newIndex
            return newIndex
        }

        func copy() -> _Storage {
            let newStorage = _Storage()
            newStorage.fields = fields
#if canImport(os.lock)
            os_unfair_lock_lock(lock)
#else
            do {
                let err = pthread_mutex_lock(lock)
                precondition(err == 0, "pthread_mutex_lock failed with error \(err)")
            }
#endif
            newStorage.index = index
#if canImport(os.lock)
            os_unfair_lock_unlock(lock)
#else
            do {
                let err = pthread_mutex_unlock(lock)
                precondition(err == 0, "pthread_mutex_unlock failed with error \(err)")
            }
#endif
            return newStorage
        }

        func hash(into hasher: inout Hasher) {
            for (field, _) in fields {
                hasher.combine(field)
            }
        }

        static func == (lhs: _Storage, rhs: _Storage) -> Bool {
            lhs.fields.lazy.map(\.0) == rhs.fields.lazy.map(\.0)
        }

        func append(field: HTTPField) {
            let name = field.name.canonicalName
            if var index = index?[name] {
                while true {
                    let next = fields[Int(index)].1
                    if next == .max { break }
                    index = next
                }
                fields[Int(index)].1 = UInt16(fields.count)
            } else {
                index?[name] = UInt16(fields.count)
            }
            fields.append((field, .max))
        }
    }

    private var _storage = _Storage()

    /// Create an empty list of HTTP fields
    public init() {
    }

    /// Access the field value string by name.
    ///
    /// If multiple fields with the same name exist, they are concatenated with commas (or
    /// semicolons in the case of the "Cookie" header field).
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
                        HTTPField(name: name, value: $0)
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
            var index = _storage.ensureIndex[name.canonicalName] ?? .max
            while index != .max {
                let (field, next) = _storage.fields[Int(index)]
                fields.append(field)
                index = next
            }
            return fields
        }
        set {
            if !isKnownUniquelyReferenced(&_storage) {
                _storage = _storage.copy()
            }
            var existingIndex = _storage.ensureIndex[name.canonicalName] ?? .max
            var newFieldIterator = newValue.makeIterator()
            var toDelete = [Int]()
            while existingIndex != .max {
                if let field = newFieldIterator.next() {
                    _storage.fields[Int(existingIndex)].0 = field
                } else {
                    toDelete.append(Int(existingIndex))
                }
                existingIndex = _storage.fields[Int(existingIndex)].1
            }
            if !toDelete.isEmpty {
                _storage.fields.remove(at: toDelete)
                _storage.index = nil
            }
            while let field = newFieldIterator.next() {
                _storage.append(field: field)
            }
        }
    }

    /// Whether one or more field with this name exists in the fields.
    /// - Parameter name: The field name.
    /// - Returns: Whether a field exists.
    public func contains(_ name: HTTPField.Name) -> Bool {
        _storage.ensureIndex[name.canonicalName] != nil
    }
}

extension HTTPFields: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (HTTPField.Name, String)...) {
        for (name, value) in elements {
            _storage.append(field: HTTPField(name: name, value: value))
        }
    }
}

extension HTTPFields: RangeReplaceableCollection, RandomAccessCollection, MutableCollection {
    public typealias Element = HTTPField
    public typealias Index = Int

    public var startIndex: Int {
        _storage.fields.startIndex
    }

    public var endIndex: Int {
        _storage.fields.endIndex
    }

    public var isEmpty: Bool {
        _storage.fields.isEmpty
    }

    public subscript(position: Int) -> HTTPField {
        get {
            guard position >= self.startIndex && position < self.endIndex else {
                preconditionFailure("getter position: \(position) out of range in HTTPFields")
            }
            return _storage.fields[position].0
        }
        set {
            guard position >= self.startIndex && position < self.endIndex else {
                preconditionFailure("setter position: \(position) out of range in HTTPFields")
            }
            if _storage.fields[position].0 == newValue {
                return
            }
            if !isKnownUniquelyReferenced(&_storage) {
                _storage = _storage.copy()
            }
            if newValue.name != _storage.fields[position].0.name {
                _storage.index = nil
            }
            _storage.fields[position].0 = newValue
        }
    }

    public mutating func replaceSubrange<C>(_ subrange: Range<Int>, with newElements: C) where C: Collection, Element == C.Element {
        if !isKnownUniquelyReferenced(&_storage) {
            _storage = _storage.copy()
        }
        if subrange.startIndex == count {
            for field in newElements {
                _storage.append(field: field)
            }
        } else {
            _storage.index = nil
            _storage.fields.replaceSubrange(subrange, with: newElements.lazy.map { ($0, 0) })
        }
    }

    public mutating func reserveCapacity(_ n: Int) {
        if !isKnownUniquelyReferenced(&_storage) {
            _storage = _storage.copy()
        }
        _storage.index?.reserveCapacity(n)
        _storage.fields.reserveCapacity(n)
    }
}

extension HTTPFields: CustomDebugStringConvertible {
    public var debugDescription: String {
        _storage.fields.description
    }
}

extension Array {
    // `removalIndices` must be ordered.
    mutating func remove<S: Sequence>(at removalIndices: S) where S.Element == Index {
        var offset = 0
        var iterator = removalIndices.makeIterator()
        var nextToRemoveOptional = iterator.next()
        for i in indices {
            while let nextToRemove = nextToRemoveOptional, index(i, offsetBy: offset) == nextToRemove {
                offset += 1
                nextToRemoveOptional = iterator.next()
            }
            let toKeep = index(i, offsetBy: offset)
            if toKeep < endIndex {
                swapAt(i, toKeep)
            } else {
                break
            }
        }
        removeLast(offset)
    }
}
