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

extension String {
    var isASCII: Bool {
        self.utf8.allSatisfy { $0 & 0x80 == 0 }
    }
}

extension HTTPField {
    struct Value: Sendable, Hashable {
        let _storage: String

        private static func transcodeSlowPath(from bytes: some Collection<UInt8>) -> String {
            let scalars = bytes.lazy.map { UnicodeScalar(UInt32($0))! }
            var string = ""
            string.unicodeScalars.append(contentsOf: scalars)
            return string
        }

        private func withISOLatin1BytesSlowPath<Return, Failure: Error>(
            _ body: (UnsafeBufferPointer<UInt8>) throws(Failure) -> Return
        ) throws(Failure) -> Return {
            try withUnsafeTemporaryAllocation(of: UInt8.self, capacity: self._storage.unicodeScalars.count) { buffer in
                for (index, scalar) in self._storage.unicodeScalars.enumerated() {
                    assert(scalar.value <= UInt8.max)
                    buffer[index] = UInt8(truncatingIfNeeded: scalar.value)
                }
                return Result { () throws(Failure) in
                    try body(UnsafeBufferPointer(buffer))
                }
            }.get()
        }

        fileprivate init(_ string: String) {
            if string.isASCII {
                self._storage = string
            } else {
                self._storage = Self.transcodeSlowPath(from: string.utf8)
            }
        }

        fileprivate init(_ bytes: some Collection<UInt8>) {
            let ascii = bytes.allSatisfy { $0 & 0x80 == 0 }
            if ascii {
                self._storage = String(decoding: bytes, as: UTF8.self)
            } else {
                self._storage = Self.transcodeSlowPath(from: bytes)
            }
        }

        init(unchecked: String) {
            self._storage = unchecked
        }

        var string: String {
            if self._storage.isASCII {
                return self._storage
            } else {
                return self.withISOLatin1BytesSlowPath {
                    String(decoding: $0, as: UTF8.self)
                }
            }
        }

        func withUnsafeBytes<Return, Failure: Error>(
            _ body: (UnsafeBufferPointer<UInt8>) throws(Failure) -> Return
        ) throws(Failure) -> Return {
            if self._storage.isASCII {
                var string = self._storage
                return try string.withUTF8 { buffer in
                    Result { () throws(Failure) in
                        try body(buffer)
                    }
                }.get()
            } else {
                return try self.withISOLatin1BytesSlowPath(body)
            }
        }
    }
}

extension HTTPField.Value {
    init(legalize value: String) {
        self = .legalizeValue(Self(value))
    }

    init(legalize bytes: some Collection<UInt8>) {
        self = .legalizeValue(Self(bytes))
    }

    init(lenient bytes: some Collection<UInt8>) {
        self = .lenientLegalizeValue(Self(bytes))
    }

    static func isValid(_ string: String) -> Bool {
        _isValidValue(string.utf8)
    }

    static func isValid(_ bytes: some Collection<UInt8>) -> Bool {
        _isValidValue(bytes)
    }

    private static func _isValidValue(_ bytes: some Sequence<UInt8>) -> Bool {
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

    private static func legalizeValue(_ value: HTTPField.Value) -> HTTPField.Value {
        if self._isValidValue(value._storage.utf8) {
            return value
        } else {
            let bytes = value._storage.utf8.lazy.map { byte -> UInt8 in
                switch byte {
                case 0x09, 0x20:
                    return byte
                case 0x21...0x7E, 0x80...0xFF:
                    return byte
                default:
                    return 0x20
                }
            }
            let trimmed = bytes.reversed().drop { $0 == 0x09 || $0 == 0x20 }.reversed().drop {
                $0 == 0x09 || $0 == 0x20
            }
            return HTTPField.Value(unchecked: String(decoding: trimmed, as: UTF8.self))
        }
    }

    private static func lenientLegalizeValue(_ value: HTTPField.Value) -> HTTPField.Value {
        if value._storage.utf8.allSatisfy({ $0 != 0x00 && $0 != 0x0A && $0 != 0x0D }) {
            return value
        } else {
            let bytes = value._storage.utf8.lazy.map { byte -> UInt8 in
                switch byte {
                case 0x00, 0x0A, 0x0D:
                    return 0x20
                default:
                    return byte
                }
            }
            return HTTPField.Value(unchecked: String(decoding: bytes, as: UTF8.self))
        }
    }
}
