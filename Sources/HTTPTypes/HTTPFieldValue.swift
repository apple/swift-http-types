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
    struct Value: Sendable {
        fileprivate enum Storage: Equatable {
            case string(String)
            case bytes([UInt8])
        }

        private let _storage: Storage

        init(unchecked: String) {
            self._storage = .string(unchecked)
        }

        var string: String {
            switch self._storage {
            case .string(let string):
                return string
            case .bytes(let bytes):
                return String(decoding: bytes, as: UTF8.self)
            }
        }

        func withUnsafeBytes<Return, Failure: Error>(
            _ body: (UnsafeBufferPointer<UInt8>) throws(Failure) -> Return
        ) throws(Failure) -> Return {
            switch self._storage {
            case .string(var string):
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

extension HTTPField.Value: Hashable {

    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs._storage, rhs._storage) {
        case (.string(let lhs), .string(let rhs)):
            return lhs == rhs
        case (.bytes(let lhs), .bytes(let rhs)):
            return lhs == rhs
        default:
            return lhs.withUnsafeBytes { lhsBytes in
                rhs.withUnsafeBytes { rhsBytes in
                    lhsBytes.elementsEqual(rhsBytes)
                }
            }
        }
    }

    func hash(into hasher: inout Hasher) {
        self.withUnsafeBytes { buffer in
            for byte in buffer {
                hasher.combine(byte)
            }
        }
    }

}

extension HTTPField.Value {

    init(legalize value: String) {
        if Self.isValid(value) {
            self._storage = .string(value)
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

    init(legalize bytes: some Collection<UInt8>) {
        if Self.isValid(bytes) {
            self._storage = .init(from: bytes)
        } else {
            self._storage = Self.legalize(from: bytes)
        }
    }

    init(lenient bytes: some Collection<UInt8>) {
        if Self.isLenient(bytes) {
            self._storage = .init(from: bytes)
        } else {
            self._storage = Self.cleanUpAsLenient(from: bytes)
        }
    }
}

extension HTTPField.Value {

    #if compiler(>=6.2) && !(os(watchOS) && _pointerBitWidth(_32))
    static func isValid(_ string: String) -> Bool {
        #if canImport(Darwin)
        if #available(macOS 26.0, iOS 26.0, watchOS 26.0, tvOS 26.0, visionOS 26.0, *) {
            return isLegal(string.utf8.span)
        }
        return isLegal(string.utf8)
        #else
        return isLegal(string.utf8.span)
        #endif
    }
    #else
    static func isValid(_ string: String) -> Bool {
        isLegal(string.utf8)
    }
    #endif

    static func isValid(_ bytes: some Collection<UInt8>) -> Bool {
        isLegal(bytes)
    }

    var isValidToken: Bool {
        switch self._storage {
        case .string(let string):
            return HTTPField.isValidToken(string)
        case .bytes(let bytes):
            return HTTPField.isValidToken(bytes)
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

        guard isoLatin1.unicodeScalars.allSatisfy({ $0.value <= UInt8.max }) && Self.isValid(isoLatin1) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "HTTP field value \"\(isoLatin1)\" contains invalid characters"
            )
        }

        self.init(fromISOLatin1: isoLatin1)
    }
}

#endif

extension HTTPField.Value {
    fileprivate static func isLegal(_ bytes: some Sequence<UInt8>) -> Bool {
        #if compiler(>=6.2)
        #if canImport(Darwin)
        if #available(macOS 26.0, iOS 26.0, watchOS 26.0, tvOS 26.0, visionOS 26.0, *) {
            let optimized = bytes.withContiguousStorageIfAvailable { isLegal($0.span) }
            if let optimized {
                return optimized
            }
        }
        #else
        let optimized = bytes.withContiguousStorageIfAvailable { isLegal($0.span) }
        if let optimized {
            return optimized
        }
        #endif
        #endif

        var iterator = bytes.makeIterator()
        guard var byte = iterator.next() else {
            // Empty string is allowed.
            return true
        }
        if byte == 0x09 || byte == 0x20 {
            // First character cannot be a space or a tab.
            return false
        }
        while true {
            switch byte {
            case 0x09, 0x20:
                break
            case 0x21...0x7E, 0x80...0xFF:
                break
            default:
                return false
            }
            if let next = iterator.next() {
                byte = next
            } else {
                break
            }
        }

        if byte == 0x09 || byte == 0x20 {
            // Last character cannot be a space or a tab.
            return false
        }

        return true
    }

    #if compiler(>=6.2)
    @available(macOS 26.0, iOS 26.0, watchOS 26.0, tvOS 26.0, visionOS 26.0, *)
    fileprivate static func isLegal(_ bytes: borrowing Span<UInt8>) -> Bool {
        for index in bytes.indices {
            switch bytes[index] {
            case 0x09, 0x20:
                if index == 0 || index == bytes.count - 1 {
                    return false
                }

                break
            case 0x21...0x7E, 0x80...0xFF:
                break
            default:
                return false
            }
        }

        return true
    }
    #endif

    fileprivate static func isLenient(_ bytes: some Sequence<UInt8>) -> Bool {
        #if compiler(>=6.2)
        #if canImport(Darwin)
        if #available(macOS 26.0, iOS 26.0, watchOS 26.0, tvOS 26.0, visionOS 26.0, *) {
            let optimized = bytes.withContiguousStorageIfAvailable { isLenient($0.span) }
            if let optimized {
                return optimized
            }
        }
        #else
        let optimized = bytes.withContiguousStorageIfAvailable { isLenient($0.span) }
        if let optimized {
            return optimized
        }
        #endif
        #endif

        return bytes.allSatisfy { $0 != 0x00 && $0 != 0x0A && $0 != 0x0D }
    }

    #if compiler(>=6.2)
    @available(macOS 26.0, iOS 26.0, watchOS 26.0, tvOS 26.0, visionOS 26.0, *)
    fileprivate static func isLenient(_ bytes: Span<UInt8>) -> Bool {
        for index in bytes.indices {
            switch bytes[index] {
            case 0x00, 0x0A, 0x0D:
                return false
            default:
                continue
            }
        }
        return true
    }
    #endif
}

extension HTTPField.Value {
    private static func legalize(from bytes: some Collection<UInt8>) -> Storage {
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
                return .string("")
            }

            return .init(from: buffer[...lastValidIndex])
        }
    }

    #if compiler(>=6.2)
    @available(macOS 26.0, iOS 26.0, watchOS 26.0, tvOS 26.0, visionOS 26.0, *)
    private static func legalize(from bytes: Span<UInt8>) -> Storage {
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
                return .string("")
            }

            return .init(from: buffer[...lastValidIndex])
        }
    }
    #endif

    private static func cleanUpAsLenient(from bytes: some Collection<UInt8>) -> Storage {
        #if compiler(>=6.2)
        #if canImport(Darwin)
        if #available(macOS 26.0, iOS 26.0, watchOS 26.0, tvOS 26.0, visionOS 26.0, *) {
            let optimized = bytes.withContiguousStorageIfAvailable { cleanUpAsLenient(from: $0.span) }
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

            return .init(from: buffer)
        }
    }

    #if compiler(>=6.2)
    @available(macOS 26.0, iOS 26.0, watchOS 26.0, tvOS 26.0, visionOS 26.0, *)
    private static func cleanUpAsLenient(from bytes: Span<UInt8>) -> Storage {
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

            return .init(from: buffer)
        }
    }
    #endif
}

extension HTTPField.Value.Storage {
    init(from bytes: some Sequence<UInt8>) {
        #if canImport(Darwin)
        if #available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *) {
            if let string = String(validating: bytes, as: UTF8.self) {
                self = .string(string)
                return
            }
        }
        #else
        if let string = String(validating: bytes, as: UTF8.self) {
            self = .string(string)
            return
        }
        #endif
        self = .bytes(Array(bytes))
    }
}

extension Sequence where Element == UInt8 {
    fileprivate var isASCII: Bool {
        allSatisfy { $0 & 0x80 == 0 }
    }
}

extension HTTPField.Value {
    var isoLatin1: String {
        switch self._storage {
        case .string(let string):
            if string.utf8.isASCII {
                return string
            }

            return Self.transcodeToISOLatin1SlowPath(from: string.utf8)
        case .bytes(let bytes):
            if bytes.isASCII {
                return self.string
            }

            return Self.transcodeToISOLatin1SlowPath(from: bytes)
        }
    }

    init(fromISOLatin1 string: String) {
        if string.utf8.isASCII {
            self._storage = .string(string)
            return
        }

        let bytes = string.unicodeScalars.lazy.map { scalar in
            assert(scalar.value <= UInt8.max)
            return UInt8(truncatingIfNeeded: scalar.value)
        }

        self._storage = .init(from: bytes)
    }

    private static func transcodeToISOLatin1SlowPath(from bytes: some Collection<UInt8>) -> String {
        let scalars = bytes.lazy.map { UnicodeScalar(UInt32($0))! }
        var string = ""
        string.unicodeScalars.append(contentsOf: scalars)
        return string
    }
}
