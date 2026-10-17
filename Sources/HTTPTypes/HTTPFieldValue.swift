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

extension HTTPField {
    @usableFromInline
    struct Value: Hashable, Sendable {
        @usableFromInline
        enum Storage: Hashable, Sendable {
            case ascii(String)
            case bytes([UInt8])
        }

        @usableFromInline
        let _storage: Storage

        @inlinable
        init(uncheckedASCII string: String) {
            assert(string.utf8.isASCII && Self.isValid(string))
            self._storage = .ascii(string)
        }

        @inlinable
        var string: String {
            switch self._storage {
            case .ascii(let string):
                return string
            case .bytes(let bytes):
                return String(decoding: bytes, as: UTF8.self)
            }
        }

        @inlinable
        func withUnsafeBytes<Return, Failure: Error>(
            _ body: (UnsafeBufferPointer<UInt8>) throws(Failure) -> Return
        ) throws(Failure) -> Return {
            switch self._storage {
            case .ascii(var string):
                return try string.withUTF8 { buffer in
                    Result { () throws(Failure) in
                        try body(buffer)
                    }
                }.get()
            case .bytes(let array):
                return try array.withUnsafeBufferPointer { buffer throws(Failure) in
                    try Result { () throws(Failure) in
                        try body(buffer)
                    }.get()
                }
            }
        }
    }
}

extension HTTPField.Value {

    @inlinable
    init(legalize value: String) {
        let (valid, isASCII) = Self.validity(value)
        if valid {
            self._storage = isASCII ? .ascii(value) : .bytes(Array(value.utf8))
        } else {
            #if compiler(>=6.2) && !(os(watchOS) && _pointerBitWidth(_32))
            #if canImport(Darwin)
            if #available(macOS 26.0, iOS 26.0, watchOS 26.0, tvOS 26.0, visionOS 26.0, *) {
                self._storage = Self.legalize(from: value.utf8.span)
                return
            }
            self._storage = Self.legalize(from: value.utf8)
            #else
            self._storage = Self.legalize(from: value.utf8.span)
            #endif
            #else
            self._storage = Self.legalize(from: value.utf8)
            #endif
        }
    }

    @inlinable
    init(legalize bytes: some Collection<UInt8>) {
        let (valid, isASCII) = Self.legality(bytes)
        if valid {
            self._storage = isASCII ? .ascii(String(decoding: bytes, as: UTF8.self)) : .bytes(Array(bytes))
        } else {
            self._storage = Self.legalize(from: bytes)
        }
    }

    @inlinable
    init(lenient bytes: some Collection<UInt8>) {
        let (valid, isASCII) = Self.lenience(bytes)
        if valid {
            self._storage = isASCII ? .ascii(String(decoding: bytes, as: UTF8.self)) : .bytes(Array(bytes))
        } else {
            self._storage = Self.cleanUpAsLenient(from: bytes)
        }
    }
}

extension HTTPField.Value {
    #if compiler(>=6.2) && !(os(watchOS) && _pointerBitWidth(_32))
    @inlinable
    static func validity(_ string: String) -> (valid: Bool, isASCII: Bool) {
        #if canImport(Darwin)
        if #available(macOS 26.0, iOS 26.0, watchOS 26.0, tvOS 26.0, visionOS 26.0, *) {
            return Self.legality(string.utf8.span)
        }
        return Self.legality(string.utf8)
        #else
        return Self.legality(string.utf8.span)
        #endif
    }
    #else
    @inlinable
    static func validity(_ string: String) -> (valid: Bool, isASCII: Bool) {
        Self.legality(string.utf8)
    }
    #endif

    @inlinable
    static func isValid(_ string: String) -> Bool {
        Self.validity(string).valid
    }

    @inlinable
    static func isValid(_ bytes: some Collection<UInt8>) -> Bool {
        Self.legality(bytes).valid
    }

    @inlinable
    static func isLenient(_ bytes: some Sequence<UInt8>) -> Bool {
        Self.lenience(bytes).valid
    }

    @inlinable
    var isValidToken: Bool {
        switch self._storage {
        case .ascii(let string):
            return HTTPField.isValidToken(string)
        case .bytes:
            return false
        }
    }
}

#if !hasFeature(Embedded)

extension HTTPField.Value: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(isoLatin1)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let isoLatin1 = try container.decode(String.self)

        guard let value = Self(validatingISOLatin1: isoLatin1) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "HTTP field value \"\(isoLatin1)\" contains invalid characters"
            )
        }

        self = value
    }
}

#endif

extension HTTPField.Value {
    @inlinable
    static func legality(_ bytes: some Sequence<UInt8>) -> (valid: Bool, isASCII: Bool) {
        #if compiler(>=6.2)
        #if canImport(Darwin)
        if #available(macOS 26.0, iOS 26.0, watchOS 26.0, tvOS 26.0, visionOS 26.0, *) {
            let optimized = bytes.withContiguousStorageIfAvailable { Self.legality($0.span) }
            if let optimized {
                return optimized
            }
        }
        #else
        let optimized = bytes.withContiguousStorageIfAvailable { Self.legality($0.span) }
        if let optimized {
            return optimized
        }
        #endif
        #endif

        var iterator = bytes.makeIterator()
        guard var byte = iterator.next() else {
            // Empty string is allowed.
            return (valid: true, isASCII: true)
        }
        if byte == 0x09 || byte == 0x20 {
            // First character cannot be a space or a tab.
            return (valid: false, isASCII: false)
        }
        var combined: UInt8 = 0
        while true {
            combined |= byte
            switch byte {
            case 0x09, 0x20:
                break
            case 0x21...0x7E, 0x80...0xFF:
                break
            default:
                return (valid: false, isASCII: false)
            }
            if let next = iterator.next() {
                byte = next
            } else {
                break
            }
        }

        if byte == 0x09 || byte == 0x20 {
            // Last character cannot be a space or a tab.
            return (valid: false, isASCII: false)
        }

        return (valid: true, isASCII: combined & 0x80 == 0)
    }

    #if compiler(>=6.2)
    @available(macOS 26.0, iOS 26.0, watchOS 26.0, tvOS 26.0, visionOS 26.0, *)
    @inlinable
    static func legality(_ bytes: borrowing Span<UInt8>) -> (valid: Bool, isASCII: Bool) {
        var combined: UInt8 = 0
        for index in bytes.indices {
            let byte = bytes[index]
            combined |= byte
            switch byte {
            case 0x09, 0x20:
                if index == 0 || index == bytes.count - 1 {
                    return (valid: false, isASCII: false)
                }

                break
            case 0x21...0x7E, 0x80...0xFF:
                break
            default:
                return (valid: false, isASCII: false)
            }
        }

        return (valid: true, isASCII: combined & 0x80 == 0)
    }
    #endif

    @inlinable
    static func lenience(_ bytes: some Sequence<UInt8>) -> (valid: Bool, isASCII: Bool) {
        #if compiler(>=6.2)
        #if canImport(Darwin)
        if #available(macOS 26.0, iOS 26.0, watchOS 26.0, tvOS 26.0, visionOS 26.0, *) {
            let optimized = bytes.withContiguousStorageIfAvailable { Self.lenience($0.span) }
            if let optimized {
                return optimized
            }
        }
        #else
        let optimized = bytes.withContiguousStorageIfAvailable { lenience($0.span) }
        if let optimized {
            return optimized
        }
        #endif
        #endif

        var combined: UInt8 = 0
        for byte in bytes {
            combined |= byte
            switch byte {
            case 0x00, 0x0A, 0x0D:
                return (valid: false, isASCII: false)
            default:
                continue
            }
        }
        return (valid: true, isASCII: combined & 0x80 == 0)
    }

    #if compiler(>=6.2)
    @available(macOS 26.0, iOS 26.0, watchOS 26.0, tvOS 26.0, visionOS 26.0, *)
    @inlinable
    static func lenience(_ bytes: Span<UInt8>) -> (valid: Bool, isASCII: Bool) {
        var combined: UInt8 = 0
        for index in bytes.indices {
            let byte = bytes[index]
            combined |= byte
            switch byte {
            case 0x00, 0x0A, 0x0D:
                return (valid: false, isASCII: false)
            default:
                continue
            }
        }
        return (valid: true, isASCII: combined & 0x80 == 0)
    }
    #endif
}

extension HTTPField.Value {
    @inlinable
    static func legalize(from bytes: some Collection<UInt8>) -> Storage {
        #if compiler(>=6.2)
        #if canImport(Darwin)
        if #available(macOS 26.0, iOS 26.0, watchOS 26.0, tvOS 26.0, visionOS 26.0, *) {
            let optimized = bytes.withContiguousStorageIfAvailable { legalize(from: $0.span) }
            if let optimized {
                return optimized
            }
        }
        #else
        let optimized = bytes.withContiguousStorageIfAvailable { legalize(from: $0.span) }
        if let optimized {
            return optimized
        }
        #endif
        #endif

        return withUnsafeTemporaryAllocation(of: UInt8.self, capacity: bytes.count) { buffer in
            var index = 0
            var lastValidIndex = 0
            for byte in bytes {
                switch byte {
                case 0x21...0x7E, 0x80...0xFF:
                    buffer[index] = byte
                    lastValidIndex = index
                    index += 1
                case 0x09, 0x20:
                    if index > 0 {
                        buffer[index] = byte
                        index += 1
                    }
                default:
                    if index > 0 {
                        buffer[index] = 0x20
                        index += 1
                    }
                }
            }

            if index == 0 {
                return .ascii("")
            }

            return .init(validated: buffer[...lastValidIndex])
        }
    }

    #if compiler(>=6.2)
    @available(macOS 26.0, iOS 26.0, watchOS 26.0, tvOS 26.0, visionOS 26.0, *)
    @inlinable
    static func legalize(from bytes: Span<UInt8>) -> Storage {
        withUnsafeTemporaryAllocation(of: UInt8.self, capacity: bytes.count) { buffer in
            var index = 0
            var lastValidIndex = 0
            for spanIndex in bytes.indices {
                let byte = bytes[spanIndex]
                switch byte {
                case 0x21...0x7E, 0x80...0xFF:
                    buffer[index] = byte
                    lastValidIndex = index
                    index += 1
                case 0x09, 0x20:
                    if index > 0 {
                        buffer[index] = byte
                        index += 1
                    }
                default:
                    if index > 0 {
                        buffer[index] = 0x20
                        index += 1
                    }
                }
            }

            if index == 0 {
                return .ascii("")
            }

            return .init(validated: buffer[...lastValidIndex])
        }
    }
    #endif

    @inlinable
    static func cleanUpAsLenient(from bytes: some Collection<UInt8>) -> Storage {
        #if compiler(>=6.2)
        #if canImport(Darwin)
        if #available(macOS 26.0, iOS 26.0, watchOS 26.0, tvOS 26.0, visionOS 26.0, *) {
            let optimized = bytes.withContiguousStorageIfAvailable { Self.cleanUpAsLenient(from: $0.span) }
            if let optimized {
                return optimized
            }
        }
        #else
        let optimized = bytes.withContiguousStorageIfAvailable { cleanUpAsLenient(from: $0.span) }
        if let optimized {
            return optimized
        }
        #endif
        #endif

        return withUnsafeTemporaryAllocation(of: UInt8.self, capacity: bytes.count) { buffer in
            var index = 0
            for byte in bytes {
                switch byte {
                case 0x00, 0x0A, 0x0D:
                    buffer[index] = 0x20
                default:
                    buffer[index] = byte
                }
                index += 1
            }

            return .init(validated: buffer)
        }
    }

    #if compiler(>=6.2)
    @available(macOS 26.0, iOS 26.0, watchOS 26.0, tvOS 26.0, visionOS 26.0, *)
    @inlinable
    static func cleanUpAsLenient(from bytes: Span<UInt8>) -> Storage {
        withUnsafeTemporaryAllocation(of: UInt8.self, capacity: bytes.count) { buffer in
            for index in bytes.indices {
                let byte = bytes[index]
                switch byte {
                case 0x00, 0x0A, 0x0D:
                    buffer[index] = 0x20
                default:
                    buffer[index] = byte
                }
            }

            return .init(validated: buffer)
        }
    }
    #endif
}

extension HTTPField.Value.Storage {
    @inlinable
    init(validated bytes: some Collection<UInt8>) {
        assert(HTTPField.Value.isLenient(bytes))
        if bytes.isASCII {
            self = .ascii(String(decoding: bytes, as: UTF8.self))
        } else {
            self = .bytes(Array(bytes))
        }
    }
}

extension Sequence where Element == UInt8 {
    @inlinable
    var isASCII: Bool {
        allSatisfy { $0 & 0x80 == 0 }
    }
}

extension HTTPField.Value {
    @inlinable
    var isoLatin1: String {
        switch self._storage {
        case .ascii(let string):
            return string
        case .bytes(let bytes):
            return Self.transcodeToISOLatin1SlowPath(from: bytes)
        }
    }

    init?(validatingISOLatin1 string: String) {
        let (valid, isASCII) = Self.validity(string)
        guard valid else {
            return nil
        }
        if isASCII {
            self._storage = .ascii(string)
            return
        }

        var bytes: [UInt8] = []
        for scalar in string.unicodeScalars {
            guard scalar.value <= UInt8.max else {
                return nil
            }
            bytes.append(UInt8(truncatingIfNeeded: scalar.value))
        }
        assert(Self.isValid(bytes))
        self._storage = .bytes(bytes)
    }

    @inlinable
    static func transcodeToISOLatin1SlowPath(from bytes: some Collection<UInt8>) -> String {
        let scalars = bytes.lazy.map { UnicodeScalar(UInt32($0))! }
        var string = ""
        string.unicodeScalars.append(contentsOf: scalars)
        return string
    }
}
