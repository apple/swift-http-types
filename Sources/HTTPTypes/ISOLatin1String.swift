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

extension StringProtocol {
    var isASCII: Bool {
        utf8.allSatisfy { $0 & 0x80 == 0 }
    }
}

struct ISOLatin1String: Sendable, Hashable {
    let _storage: String

    private static func transcodeSlowPath(from bytes: some Collection<UInt8>) -> String {
        let scalars = bytes.lazy.map { UnicodeScalar(UInt32($0))! }
        var string = ""
        string.unicodeScalars.append(contentsOf: scalars)
        return string
    }

    private func withISOLatin1BytesSlowPath<Result>(_ body: (UnsafeBufferPointer<UInt8>) throws -> Result) rethrows -> Result {
        try withUnsafeTemporaryAllocation(of: UInt8.self, capacity: _storage.unicodeScalars.count) { buffer in
            for (index, scalar) in _storage.unicodeScalars.enumerated() {
                assert(scalar.value <= UInt8.max)
                buffer.initializeElement(at: index, to: UInt8(truncatingIfNeeded: scalar.value))
            }
            return try body(UnsafeBufferPointer(buffer))
        }
    }

    init(_ string: some StringProtocol) {
        if string.isASCII {
            _storage = String(string)
        } else {
            _storage = Self.transcodeSlowPath(from: string.utf8)
        }
    }

    init(_ bytes: some Collection<UInt8>) {
        let ascii = bytes.allSatisfy { $0 & 0x80 == 0 }
        if ascii {
            _storage = String(decoding: bytes, as: UTF8.self)
        } else {
            _storage = Self.transcodeSlowPath(from: bytes)
        }
    }

    init(unchecked: String) {
        _storage = unchecked
    }

    var string: String {
        if _storage.isASCII {
            return _storage
        } else {
            return withISOLatin1BytesSlowPath {
                String(decoding: $0, as: UTF8.self)
            }
        }
    }

    func withUnsafeBytes<Result>(_ body: (UnsafeBufferPointer<UInt8>) throws -> Result) rethrows -> Result {
        if _storage.isASCII {
            var string = _storage
            return try string.withUTF8(body)
        } else {
            return try withISOLatin1BytesSlowPath(body)
        }
    }
}
