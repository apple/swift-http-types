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

struct ISOLatin1String: Sendable, Hashable {
    let _storage: String

    private static func transcodeSlowPath(from bytes: some Collection<UInt8>) -> String {
        let scalars = bytes.lazy.map { UnicodeScalar(UInt32($0))! }
        var string = ""
        string.unicodeScalars.append(contentsOf: scalars)
        return string
    }

    private func withISOLatin1BytesSlowPath<Result>(
        _ body: (UnsafeBufferPointer<UInt8>) throws -> Result
    ) rethrows -> Result {
        try withUnsafeTemporaryAllocation(of: UInt8.self, capacity: self._storage.unicodeScalars.count) { buffer in
            for (index, scalar) in self._storage.unicodeScalars.enumerated() {
                assert(scalar.value <= UInt8.max)
                buffer[index] = UInt8(truncatingIfNeeded: scalar.value)
            }
            return try body(UnsafeBufferPointer(buffer))
        }
    }

    init(_ string: String) {
        if string.isASCII {
            self._storage = string
        } else {
            self._storage = Self.transcodeSlowPath(from: string.utf8)
        }
    }

    init(_ bytes: some Collection<UInt8>) {
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

    func withUnsafeBytes<Result>(_ body: (UnsafeBufferPointer<UInt8>) throws -> Result) rethrows -> Result {
        if self._storage.isASCII {
            var string = self._storage
            return try string.withUTF8(body)
        } else {
            return try self.withISOLatin1BytesSlowPath(body)
        }
    }
}
