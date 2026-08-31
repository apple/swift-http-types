//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

/// An HTTP/3 error code.
///
/// https://www.rfc-editor.org/rfc/rfc9114.html#section-8.1
@available(HTTPTypes 1.7, *)
public struct HTTP3ErrorCode: Sendable, Hashable, RawRepresentable {
    /// The largest valid HTTP/3 error code, 2^62 - 1.
    ///
    /// HTTP/3 error codes are encoded as QUIC variable-length integers, which cannot represent
    /// larger values.
    ///
    /// https://www.rfc-editor.org/rfc/rfc9000.html#section-16
    private static let maxRawValue: UInt64 = 0x3fff_ffff_ffff_ffff

    /// The error code value, which is never greater than 2^62 - 1.
    public let rawValue: UInt64

    /// Create an HTTP/3 error code from its numeric value.
    ///
    /// Values that are not registered are allowed, but the value must be representable as a QUIC
    /// variable-length integer.
    ///
    /// https://www.rfc-editor.org/rfc/rfc9000.html#section-16
    /// - Parameter rawValue: The error code value. It must not be greater than 2^62 - 1.
    public init(rawValue: UInt64) {
        precondition(rawValue <= Self.maxRawValue, "Invalid HTTP/3 error code")
        self.rawValue = rawValue
    }

    @inlinable
    init(uncheckedRawValue: UInt64) {
        self.rawValue = uncheckedRawValue
    }
}

@available(HTTPTypes 1.7, *)
extension HTTP3ErrorCode {
    /// H3_NO_ERROR (0x0100)
    ///
    /// No error.
    ///
    /// https://www.rfc-editor.org/rfc/rfc9114.html#section-8.1
    @inlinable
    public static var noError: Self { .init(uncheckedRawValue: 0x0100) }

    /// H3_GENERAL_PROTOCOL_ERROR (0x0101)
    ///
    /// General protocol error.
    ///
    /// https://www.rfc-editor.org/rfc/rfc9114.html#section-8.1
    @inlinable
    public static var generalProtocolError: Self { .init(uncheckedRawValue: 0x0101) }

    /// H3_INTERNAL_ERROR (0x0102)
    ///
    /// Internal error.
    ///
    /// https://www.rfc-editor.org/rfc/rfc9114.html#section-8.1
    @inlinable
    public static var internalError: Self { .init(uncheckedRawValue: 0x0102) }

    /// H3_STREAM_CREATION_ERROR (0x0103)
    ///
    /// Stream creation error.
    ///
    /// https://www.rfc-editor.org/rfc/rfc9114.html#section-8.1
    @inlinable
    public static var streamCreationError: Self { .init(uncheckedRawValue: 0x0103) }

    /// H3_CLOSED_CRITICAL_STREAM (0x0104)
    ///
    /// Critical stream was closed.
    ///
    /// https://www.rfc-editor.org/rfc/rfc9114.html#section-8.1
    @inlinable
    public static var closedCriticalStream: Self { .init(uncheckedRawValue: 0x0104) }

    /// H3_FRAME_UNEXPECTED (0x0105)
    ///
    /// Frame not permitted in the current state.
    ///
    /// https://www.rfc-editor.org/rfc/rfc9114.html#section-8.1
    @inlinable
    public static var frameUnexpected: Self { .init(uncheckedRawValue: 0x0105) }

    /// H3_FRAME_ERROR (0x0106)
    ///
    /// Frame violated layout or size rules.
    ///
    /// https://www.rfc-editor.org/rfc/rfc9114.html#section-8.1
    @inlinable
    public static var frameError: Self { .init(uncheckedRawValue: 0x0106) }

    /// H3_EXCESSIVE_LOAD (0x0107)
    ///
    /// Peer generating excessive load.
    ///
    /// https://www.rfc-editor.org/rfc/rfc9114.html#section-8.1
    @inlinable
    public static var excessiveLoad: Self { .init(uncheckedRawValue: 0x0107) }

    /// H3_ID_ERROR (0x0108)
    ///
    /// An identifier was used incorrectly.
    ///
    /// https://www.rfc-editor.org/rfc/rfc9114.html#section-8.1
    @inlinable
    public static var idError: Self { .init(uncheckedRawValue: 0x0108) }

    /// H3_SETTINGS_ERROR (0x0109)
    ///
    /// SETTINGS frame contained invalid values.
    ///
    /// https://www.rfc-editor.org/rfc/rfc9114.html#section-8.1
    @inlinable
    public static var settingsError: Self { .init(uncheckedRawValue: 0x0109) }

    /// H3_MISSING_SETTINGS (0x010a)
    ///
    /// No SETTINGS frame received.
    ///
    /// https://www.rfc-editor.org/rfc/rfc9114.html#section-8.1
    @inlinable
    public static var missingSettings: Self { .init(uncheckedRawValue: 0x010a) }

    /// H3_REQUEST_REJECTED (0x010b)
    ///
    /// Request not processed.
    ///
    /// https://www.rfc-editor.org/rfc/rfc9114.html#section-8.1
    @inlinable
    public static var requestRejected: Self { .init(uncheckedRawValue: 0x010b) }

    /// H3_REQUEST_CANCELLED (0x010c)
    ///
    /// Data no longer needed.
    ///
    /// https://www.rfc-editor.org/rfc/rfc9114.html#section-8.1
    @inlinable
    public static var requestCancelled: Self { .init(uncheckedRawValue: 0x010c) }

    /// H3_REQUEST_INCOMPLETE (0x010d)
    ///
    /// Stream terminated early.
    ///
    /// https://www.rfc-editor.org/rfc/rfc9114.html#section-8.1
    @inlinable
    public static var requestIncomplete: Self { .init(uncheckedRawValue: 0x010d) }

    /// H3_MESSAGE_ERROR (0x010e)
    ///
    /// Malformed message.
    ///
    /// https://www.rfc-editor.org/rfc/rfc9114.html#section-8.1
    @inlinable
    public static var messageError: Self { .init(uncheckedRawValue: 0x010e) }

    /// H3_CONNECT_ERROR (0x010f)
    ///
    /// TCP reset or error on CONNECT request.
    ///
    /// https://www.rfc-editor.org/rfc/rfc9114.html#section-8.1
    @inlinable
    public static var connectError: Self { .init(uncheckedRawValue: 0x010f) }

    /// H3_VERSION_FALLBACK (0x0110)
    ///
    /// Retry over HTTP/1.1.
    ///
    /// https://www.rfc-editor.org/rfc/rfc9114.html#section-8.1
    @inlinable
    public static var versionFallback: Self { .init(uncheckedRawValue: 0x0110) }

    /// QPACK_DECOMPRESSION_FAILED (0x0200)
    ///
    /// Decoding of a field section failed.
    ///
    /// https://www.rfc-editor.org/rfc/rfc9204.html#section-6
    @inlinable
    public static var qpackDecompressionFailed: Self { .init(uncheckedRawValue: 0x0200) }

    /// QPACK_ENCODER_STREAM_ERROR (0x0201)
    ///
    /// Error on the encoder stream.
    ///
    /// https://www.rfc-editor.org/rfc/rfc9204.html#section-6
    @inlinable
    public static var qpackEncoderStreamError: Self { .init(uncheckedRawValue: 0x0201) }

    /// QPACK_DECODER_STREAM_ERROR (0x0202)
    ///
    /// Error on the decoder stream.
    ///
    /// https://www.rfc-editor.org/rfc/rfc9204.html#section-6
    @inlinable
    public static var qpackDecoderStreamError: Self { .init(uncheckedRawValue: 0x0202) }
}

@available(HTTPTypes 1.7, *)
extension HTTP3ErrorCode: CustomStringConvertible {
    /// The registered name of the error code, or nil if the code is not registered.
    private var name: String? {
        switch self.rawValue {
        case 0x0100:
            return "H3_NO_ERROR"
        case 0x0101:
            return "H3_GENERAL_PROTOCOL_ERROR"
        case 0x0102:
            return "H3_INTERNAL_ERROR"
        case 0x0103:
            return "H3_STREAM_CREATION_ERROR"
        case 0x0104:
            return "H3_CLOSED_CRITICAL_STREAM"
        case 0x0105:
            return "H3_FRAME_UNEXPECTED"
        case 0x0106:
            return "H3_FRAME_ERROR"
        case 0x0107:
            return "H3_EXCESSIVE_LOAD"
        case 0x0108:
            return "H3_ID_ERROR"
        case 0x0109:
            return "H3_SETTINGS_ERROR"
        case 0x010a:
            return "H3_MISSING_SETTINGS"
        case 0x010b:
            return "H3_REQUEST_REJECTED"
        case 0x010c:
            return "H3_REQUEST_CANCELLED"
        case 0x010d:
            return "H3_REQUEST_INCOMPLETE"
        case 0x010e:
            return "H3_MESSAGE_ERROR"
        case 0x010f:
            return "H3_CONNECT_ERROR"
        case 0x0110:
            return "H3_VERSION_FALLBACK"
        case 0x0200:
            return "QPACK_DECOMPRESSION_FAILED"
        case 0x0201:
            return "QPACK_ENCODER_STREAM_ERROR"
        case 0x0202:
            return "QPACK_DECODER_STREAM_ERROR"
        default:
            return nil
        }
    }

    /// A textual representation of the error code.
    ///
    /// Registered codes are rendered as their registered name followed by their hexadecimal value,
    /// such as `H3_REQUEST_CANCELLED (0x10c)`. Codes that are not registered are rendered as their
    /// hexadecimal value alone, such as `0x21`.
    public var description: String {
        let hexValue = "0x\(String(self.rawValue, radix: 16))"
        if let name = self.name {
            return "\(name) (\(hexValue))"
        } else {
            return hexValue
        }
    }
}
