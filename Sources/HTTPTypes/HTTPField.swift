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
@available(HTTPTypes 1.0, *)
public struct HTTPField: Sendable, Hashable {
    /// The strategy for whether the field is indexed in the HPACK or QPACK dynamic table.
    public struct DynamicTableIndexingStrategy: Sendable, Hashable {
        /// Default strategy.
        @inlinable
        public static var automatic: Self { .init(uncheckedValue: 0) }

        /// Always put this field in the dynamic table if possible.
        @inlinable
        public static var prefer: Self { .init(uncheckedValue: 1) }

        /// Don't put this field in the dynamic table.
        @inlinable
        public static var avoid: Self { .init(uncheckedValue: 2) }

        /// Don't put this field in the dynamic table, and set a flag to disallow intermediaries to
        /// index this field.
        @inlinable
        public static var disallow: Self { .init(uncheckedValue: 3) }

        @usableFromInline
        let rawValue: UInt8

        @inlinable
        static var maxRawValue: UInt8 { 3 }

        @inlinable
        init(uncheckedValue: UInt8) {
            assert(uncheckedValue <= Self.maxRawValue)
            self.rawValue = uncheckedValue
        }

        @inlinable
        init?(rawValue: UInt8) {
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
    @inlinable
    public init(name: Name, value: String) {
        self.name = name
        self.rawValue = HTTPField.Value(legalize: value)
    }

    /// Create an HTTP field from a name and a value.
    /// - Parameters:
    ///   - name: The HTTP field name.
    ///   - value: The HTTP field value. Invalid bytes are converted into space characters.
    @inlinable
    public init(name: Name, value: some Collection<UInt8>) {
        self.name = name
        self.rawValue = HTTPField.Value(legalize: value)
    }

    /// Create an HTTP field from a name and a value. Leniently legalize the value.
    /// - Parameters:
    ///   - name: The HTTP field name.
    ///   - lenientValue: The HTTP field value. Newlines and NULs are converted into space
    ///                   characters.
    @available(HTTPTypes 1.1, *)
    @inlinable
    public init(name: Name, lenientValue: some Collection<UInt8>) {
        self.name = name
        self.rawValue = HTTPField.Value(lenient: lenientValue)
    }

    init(name: Name, uncheckedValue: HTTPField.Value) {
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
    @inlinable
    public var value: String {
        get {
            self.rawValue.string
        }
        set {
            self.rawValue = HTTPField.Value(legalize: newValue)
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
    @inlinable
    public func withUnsafeBytesOfValue<Result, Failure: Error>(
        _ body: (UnsafeBufferPointer<UInt8>) throws(Failure) -> Result
    ) throws(Failure) -> Result {
        try self.rawValue.withUnsafeBytes(body)
    }

    /// The strategy for whether the field is indexed in the HPACK or QPACK dynamic table.
    public var indexingStrategy: DynamicTableIndexingStrategy = .automatic

    @usableFromInline
    var rawValue: HTTPField.Value

    /// Whether the string is valid for an HTTP field value based on RFC 9110.
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html#name-field-values
    ///
    /// - Parameter value: The string to validate.
    /// - Returns: Whether the string is valid.
    @inlinable
    public static func isValidValue(_ value: String) -> Bool {
        Self.Value.isValid(value)
    }

    /// Whether the byte collection is valid for an HTTP field value based on RFC 9110.
    ///
    /// https://www.rfc-editor.org/rfc/rfc9110.html#name-field-values
    ///
    /// - Parameter value: The byte collection to validate.
    /// - Returns: Whether the byte collection is valid.
    @inlinable
    public static func isValidValue(_ value: some Collection<UInt8>) -> Bool {
        Self.Value.isValid(value)
    }
}

@available(HTTPTypes 1.0, *)
extension HTTPField: CustomStringConvertible {
    public var description: String {
        "\(self.name): \(self.value)"
    }
}

#if !hasFeature(Embedded)

@available(HTTPTypes 1.0, *)
extension HTTPField: CustomPlaygroundDisplayConvertible {
    public var playgroundDescription: Any {
        self.description
    }
}

@available(HTTPTypes 1.0, *)
extension HTTPField: Codable {
    enum CodingKeys: String, CodingKey {
        case name
        case value
        case indexingStrategy
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.name, forKey: .name)
        try container.encode(self.rawValue, forKey: .value)
        if self.indexingStrategy != .automatic {
            try container.encode(self.indexingStrategy.rawValue, forKey: .indexingStrategy)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let name = try container.decode(Name.self, forKey: .name)
        let value = try container.decode(HTTPField.Value.self, forKey: .value)
        self.init(name: name, uncheckedValue: value)
        if let indexingStrategyValue = try container.decodeIfPresent(UInt8.self, forKey: .indexingStrategy),
            let indexingStrategy = DynamicTableIndexingStrategy(rawValue: indexingStrategyValue)
        {
            self.indexingStrategy = indexingStrategy
        }
    }
}

#endif

@available(HTTPTypes 1.0, *)
extension HTTPField {
    @usableFromInline
    enum TokenValidity {
        case invalid
        case valid
        case canonical

        @inlinable
        var isValid: Bool {
            switch self {
            case .valid, .canonical:
                return true
            case .invalid:
                return false
            }
        }
    }

    @inlinable
    static var digits: ClosedRange<UInt8> {
        UInt8(ascii: "0")...UInt8(ascii: "9")
    }

    @inlinable
    static var lowerCaseLetters: ClosedRange<UInt8> {
        UInt8(ascii: "a")...UInt8(ascii: "z")
    }

    @inlinable
    static var upperCaseLetters: ClosedRange<UInt8> {
        UInt8(ascii: "A")...UInt8(ascii: "Z")
    }

    @inlinable
    static func validatedCanonicalName(_ name: String) -> String? {
        switch Self.tokenValidity(name) {
        case .canonical:
            return name
        case .valid:
            return name.lowercased()
        case .invalid:
            return nil
        }
    }

    @inlinable
    static func isValidToken(_ token: String) -> Bool {
        Self.tokenValidity(token).isValid
    }

    @inlinable
    static func isValidToken(_ token: Substring) -> Bool {
        Self.tokenValidity(token).isValid
    }

    @inlinable
    static func isValidToken(_ bytes: some Collection<UInt8>) -> Bool {
        Self.tokenValidity(bytes).isValid
    }

    #if compiler(>=6.3) && !(os(watchOS) && _pointerBitWidth(_32))
    @inlinable
    static func tokenValidity(_ token: String) -> TokenValidity {
        #if canImport(Darwin)
        if #available(macOS 26.0, iOS 26.0, watchOS 26.0, tvOS 26.0, visionOS 26.0, *) {
            return Self.tokenValidity(token.utf8.span)
        }
        return Self.tokenValidity(token.utf8)
        #else
        return Self.tokenValidity(token.utf8.span)
        #endif
    }

    @inlinable
    static func tokenValidity(_ token: Substring) -> TokenValidity {
        #if canImport(Darwin)
        if #available(macOS 26.0, iOS 26.0, watchOS 26.0, tvOS 26.0, visionOS 26.0, *) {
            return Self.tokenValidity(token.utf8.span)
        }
        return Self.tokenValidity(token.utf8)
        #else
        return Self.tokenValidity(token.utf8.span)
        #endif
    }

    @available(macOS 26.0, iOS 26.0, watchOS 26.0, tvOS 26.0, visionOS 26.0, *)
    @inlinable
    static func tokenValidity(_ buffer: borrowing Span<UInt8>) -> TokenValidity {
        // Checks validity of token based on [RFC 9110](https://www.rfc-editor.org/rfc/rfc9110.html#name-tokens)
        if buffer.isEmpty {
            return .invalid
        }

        var validity: TokenValidity = .canonical
        for index in buffer.indices {
            switch buffer[index] {
            // Symbols like "!" / "#" / "$" / "%" / "&" / "'" / "*" / "+" / "-" / "." / "^" / "_" / "`" / "|" / "~"
            case 0x21, 0x23, 0x24, 0x25, 0x26, 0x27, 0x2A, 0x2B, 0x2D, 0x2E, 0x5E, 0x5F, 0x60, 0x7C, 0x7E:
                continue
            case Self.digits, Self.lowerCaseLetters:
                continue
            case Self.upperCaseLetters:
                validity = .valid
            default:
                return .invalid
            }
        }

        return validity
    }
    #else
    @inlinable
    static func tokenValidity(_ token: some StringProtocol) -> TokenValidity {
        Self.tokenValidity(token.utf8)
    }
    #endif

    @inlinable
    static func tokenValidity(_ bytes: some Collection<UInt8>) -> TokenValidity {
        // Checks validity of token based on [RFC 9110](https://www.rfc-editor.org/rfc/rfc9110.html#name-tokens)
        if bytes.isEmpty {
            return .invalid
        }

        var validity: TokenValidity = .canonical
        for byte in bytes {
            switch byte {
            // Symbols like "!" / "#" / "$" / "%" / "&" / "'" / "*" / "+" / "-" / "." / "^" / "_" / "`" / "|" / "~"
            case 0x21, 0x23, 0x24, 0x25, 0x26, 0x27, 0x2A, 0x2B, 0x2D, 0x2E, 0x5E, 0x5F, 0x60, 0x7C, 0x7E:
                continue
            case Self.digits, Self.lowerCaseLetters:
                continue
            case Self.upperCaseLetters:
                validity = .valid
            default:
                return .invalid
            }
        }

        return validity
    }
}
