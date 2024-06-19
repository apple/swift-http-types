//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Benchmark
import HTTPTypes

let benchmarks = {
    Benchmark(
        "Initialize HTTPFields from Dictionary Literal"
    ) { _ in
        let fiels: HTTPFields = [
            .contentType: "application/json",
            .contentLength: "42",
            .connection: "keep-alive",
            .accept: "application/json",
            .acceptEncoding: "gzip, deflate, br",
        ]
    }
}
