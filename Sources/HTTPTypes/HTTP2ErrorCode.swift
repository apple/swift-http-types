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

/// An HTTP/2 error code.
///
/// https://www.rfc-editor.org/rfc/rfc9113.html#section-7
@available(HTTPTypes 1.7, *)
public struct HTTP2ErrorCode: Sendable, Hashable, RawRepresentable {
    /// The 32-bit error code value.
    public let rawValue: UInt32

    /// Create an HTTP/2 error code from its numeric value.
    ///
    /// Every 32-bit value is a valid HTTP/2 error code, including values that are not registered.
    /// - Parameter rawValue: The error code value.
    @inlinable
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
}

@available(HTTPTypes 1.7, *)
extension HTTP2ErrorCode {
    /// NO_ERROR (0x00)
    ///
    /// Graceful shutdown.
    ///
    /// https://www.rfc-editor.org/rfc/rfc9113.html#section-7
    @inlinable
    public static var noError: Self { .init(rawValue: 0x00) }

    /// PROTOCOL_ERROR (0x01)
    ///
    /// Protocol error detected.
    ///
    /// https://www.rfc-editor.org/rfc/rfc9113.html#section-7
    @inlinable
    public static var protocolError: Self { .init(rawValue: 0x01) }

    /// INTERNAL_ERROR (0x02)
    ///
    /// Implementation fault.
    ///
    /// https://www.rfc-editor.org/rfc/rfc9113.html#section-7
    @inlinable
    public static var internalError: Self { .init(rawValue: 0x02) }

    /// FLOW_CONTROL_ERROR (0x03)
    ///
    /// Flow-control limits exceeded.
    ///
    /// https://www.rfc-editor.org/rfc/rfc9113.html#section-7
    @inlinable
    public static var flowControlError: Self { .init(rawValue: 0x03) }

    /// SETTINGS_TIMEOUT (0x04)
    ///
    /// Settings not acknowledged.
    ///
    /// https://www.rfc-editor.org/rfc/rfc9113.html#section-7
    @inlinable
    public static var settingsTimeout: Self { .init(rawValue: 0x04) }

    /// STREAM_CLOSED (0x05)
    ///
    /// Frame received for closed stream.
    ///
    /// https://www.rfc-editor.org/rfc/rfc9113.html#section-7
    @inlinable
    public static var streamClosed: Self { .init(rawValue: 0x05) }

    /// FRAME_SIZE_ERROR (0x06)
    ///
    /// Frame size incorrect.
    ///
    /// https://www.rfc-editor.org/rfc/rfc9113.html#section-7
    @inlinable
    public static var frameSizeError: Self { .init(rawValue: 0x06) }

    /// REFUSED_STREAM (0x07)
    ///
    /// Stream not processed.
    ///
    /// https://www.rfc-editor.org/rfc/rfc9113.html#section-7
    @inlinable
    public static var refusedStream: Self { .init(rawValue: 0x07) }

    /// CANCEL (0x08)
    ///
    /// Stream cancelled.
    ///
    /// https://www.rfc-editor.org/rfc/rfc9113.html#section-7
    @inlinable
    public static var cancel: Self { .init(rawValue: 0x08) }

    /// COMPRESSION_ERROR (0x09)
    ///
    /// Compression state not updated.
    ///
    /// https://www.rfc-editor.org/rfc/rfc9113.html#section-7
    @inlinable
    public static var compressionError: Self { .init(rawValue: 0x09) }

    /// CONNECT_ERROR (0x0a)
    ///
    /// TCP connection error for CONNECT method.
    ///
    /// https://www.rfc-editor.org/rfc/rfc9113.html#section-7
    @inlinable
    public static var connectError: Self { .init(rawValue: 0x0a) }

    /// ENHANCE_YOUR_CALM (0x0b)
    ///
    /// Processing capacity exceeded.
    ///
    /// https://www.rfc-editor.org/rfc/rfc9113.html#section-7
    @inlinable
    public static var enhanceYourCalm: Self { .init(rawValue: 0x0b) }

    /// INADEQUATE_SECURITY (0x0c)
    ///
    /// Negotiated TLS parameters not acceptable.
    ///
    /// https://www.rfc-editor.org/rfc/rfc9113.html#section-7
    @inlinable
    public static var inadequateSecurity: Self { .init(rawValue: 0x0c) }

    /// HTTP_1_1_REQUIRED (0x0d)
    ///
    /// Use HTTP/1.1 for the request.
    ///
    /// https://www.rfc-editor.org/rfc/rfc9113.html#section-7
    @inlinable
    public static var http11Required: Self { .init(rawValue: 0x0d) }
}

@available(HTTPTypes 1.7, *)
extension HTTP2ErrorCode: CustomStringConvertible {
    /// The registered name of the error code, or nil if the code is not registered.
    private var name: String? {
        switch self.rawValue {
        case 0x00:
            return "NO_ERROR"
        case 0x01:
            return "PROTOCOL_ERROR"
        case 0x02:
            return "INTERNAL_ERROR"
        case 0x03:
            return "FLOW_CONTROL_ERROR"
        case 0x04:
            return "SETTINGS_TIMEOUT"
        case 0x05:
            return "STREAM_CLOSED"
        case 0x06:
            return "FRAME_SIZE_ERROR"
        case 0x07:
            return "REFUSED_STREAM"
        case 0x08:
            return "CANCEL"
        case 0x09:
            return "COMPRESSION_ERROR"
        case 0x0a:
            return "CONNECT_ERROR"
        case 0x0b:
            return "ENHANCE_YOUR_CALM"
        case 0x0c:
            return "INADEQUATE_SECURITY"
        case 0x0d:
            return "HTTP_1_1_REQUIRED"
        default:
            return nil
        }
    }

    /// A textual representation of the error code.
    ///
    /// Registered codes are rendered as their registered name followed by their hexadecimal value,
    /// such as `CANCEL (0x8)`. Codes that are not registered are rendered as their hexadecimal
    /// value alone, such as `0xe`.
    public var description: String {
        let hexValue = "0x\(String(self.rawValue, radix: 16))"
        if let name = self.name {
            return "\(name) (\(hexValue))"
        } else {
            return hexValue
        }
    }
}
