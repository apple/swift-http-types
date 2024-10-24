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

/// A name-value pair with additional metadata.
///
/// The field name is a case-insensitive but case-preserving ASCII string; the field value is a
/// collection of bytes.
public struct HTTPField: Sendable, Hashable {
    /// The strategy for whether the field is indexed in the HPACK or QPACK dynamic table.
    public struct DynamicTableIndexingStrategy: Sendable, Hashable {
        /// Default strategy.
        public static var automatic: Self { .init(uncheckedValue: 0) }

        /// Always put this field in the dynamic table if possible.
        public static var prefer: Self { .init(uncheckedValue: 1) }

        /// Don't put this field in the dynamic table.
        public static var avoid: Self { .init(uncheckedValue: 2) }

        /// Don't put this field in the dynamic table, and set a flag to disallow intermediaries to
        /// index this field.
        public static var disallow: Self { .init(uncheckedValue: 3) }

        fileprivate let rawValue: UInt8

        private static let maxRawValue: UInt8 = 3

        private init(uncheckedValue: UInt8) {
            assert(uncheckedValue <= Self.maxRawValue)
            self.rawValue = uncheckedValue
        }

        fileprivate init?(rawValue: UInt8) {
            if rawValue > Self.maxRawValue {
                return nil
            }
            self.rawValue = rawValue
        }
    }

    /// Create an HTTP field from a name and a value.
    /// - Parameters:
    ///   - name: The HTTP field name.
    ///   - value: The HTTP field value is initialized from the UTF-8 encoded bytes of the string.
    ///            Invalid bytes are converted into space characters.
    public init(name: Name, value: String) {
        self.name = name
        self.rawValue = Self.legalizeValue(ISOLatin1String(value))
    }

    /// Create an HTTP field from a name and a value.
    /// - Parameters:
    ///   - name: The HTTP field name.
    ///   - value: The HTTP field value. Invalid bytes are converted into space characters.
    public init(name: Name, value: some Collection<UInt8>) {
        self.name = name
        self.rawValue = Self.legalizeValue(ISOLatin1String(value))
    }

    /// Create an HTTP field from a name and a value. Leniently legalize the value.
    /// - Parameters:
    ///   - name: The HTTP field name.
    ///   - lenientValue: The HTTP field value. Newlines and NULs are converted into space
    ///                   characters.
    public init(name: Name, lenientValue: some Collection<UInt8>) {
        self.name = name
        self.rawValue = Self.lenientLegalizeValue(ISOLatin1String(lenientValue))
    }

    init(name: Name, uncheckedValue: ISOLatin1String) {
        self.name = name
        self.rawValue = uncheckedValue
    }

    /// The HTTP field name.
    public var name: Name

    /// The HTTP field value as a UTF-8 string.
    ///
    /// When setting the value, invalid bytes (defined in RFC 9110) are converted into space characters.
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html#name-field-values
    ///
    /// If the field is not UTF-8 encoded, `withUnsafeBytesOfValue` can be used to access the
    /// underlying bytes of the field value.
    public var value: String {
        get {
            self.rawValue.string
        }
        set {
            self.rawValue = Self.legalizeValue(ISOLatin1String(newValue))
        }
    }

    /// Runs `body` over the raw HTTP field value bytes as a contiguous buffer.
    ///
    /// This function is useful if the field is not UTF-8 encoded and the default `value` view
    /// cannot be used.
    ///
    /// Note that it is unsafe to escape the buffer pointer beyond the duration of this call.
    ///
    /// - Parameter body: The closure to be invoked with the buffer.
    /// - Returns: Result of the `body` closure.
    public func withUnsafeBytesOfValue<Result>(
        _ body: (UnsafeBufferPointer<UInt8>) throws -> Result
    ) rethrows -> Result {
        try self.rawValue.withUnsafeBytes(body)
    }

    /// The strategy for whether the field is indexed in the HPACK or QPACK dynamic table.
    public var indexingStrategy: DynamicTableIndexingStrategy = .automatic

    var rawValue: ISOLatin1String

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

    static func legalizeValue(_ value: ISOLatin1String) -> ISOLatin1String {
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
            return ISOLatin1String(unchecked: String(decoding: trimmed, as: UTF8.self))
        }
    }

    static func lenientLegalizeValue(_ value: ISOLatin1String) -> ISOLatin1String {
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
            return ISOLatin1String(unchecked: String(decoding: bytes, as: UTF8.self))
        }
    }

    /// Whether the string is valid for an HTTP field value based on RFC 9110.
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html#name-field-values
    ///
    /// - Parameter value: The string to validate.
    /// - Returns: Whether the string is valid.
    public static func isValidValue(_ value: String) -> Bool {
        self._isValidValue(value.utf8)
    }

    /// Whether the byte collection is valid for an HTTP field value based on RFC 9110.
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html#name-field-values
    ///
    /// - Parameter value: The byte collection to validate.
    /// - Returns: Whether the byte collection is valid.
    public static func isValidValue(_ value: some Collection<UInt8>) -> Bool {
        self._isValidValue(value)
    }
}

extension HTTPField: CustomStringConvertible {
    public var description: String {
        "\(self.name): \(self.value)"
    }
}

extension HTTPField: CustomPlaygroundDisplayConvertible {
    public var playgroundDescription: Any {
        self.description
    }
}

extension HTTPField: Codable {
    enum CodingKeys: String, CodingKey {
        case name
        case value
        case indexingStrategy
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.name, forKey: .name)
        try container.encode(self.rawValue._storage, forKey: .value)
        if self.indexingStrategy != .automatic {
            try container.encode(self.indexingStrategy.rawValue, forKey: .indexingStrategy)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let name = try container.decode(Name.self, forKey: .name)
        let value = try container.decode(String.self, forKey: .value)
        guard Self.isValidValue(value) else {
            throw DecodingError.dataCorruptedError(
                forKey: .value,
                in: container,
                debugDescription: "HTTP field value \"\(value)\" contains invalid characters"
            )
        }
        self.init(name: name, uncheckedValue: ISOLatin1String(unchecked: value))
        if let indexingStrategyValue = try container.decodeIfPresent(UInt8.self, forKey: .indexingStrategy),
            let indexingStrategy = DynamicTableIndexingStrategy(rawValue: indexingStrategyValue)
        {
            self.indexingStrategy = indexingStrategy
        }
    }
}

extension HTTPField {
    static func isValidToken(_ token: some StringProtocol) -> Bool {
        !token.isEmpty
            && token.utf8.allSatisfy {
                switch $0 {
                case 0x21, 0x23, 0x24, 0x25, 0x26, 0x27, 0x2A, 0x2B, 0x2D, 0x2E, 0x5E, 0x5F, 0x60, 0x7C, 0x7E:
                    return true
                case 0x30...0x39, 0x41...0x5A, 0x61...0x7A:  // DIGHT, ALPHA
                    return true
                default:
                    return false
                }
            }
    }
}
