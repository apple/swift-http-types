import HTTPTypes
import Benchmark

let benchmarks = {
    Benchmark(
        "Initialize HTTPFields from Dictionary Literal"
    ) { benchmark in
        let fiels: HTTPFields = [
            .contentType: "application/json",
            .contentLength: "42",
            .connection: "keep-alive",
            .accept: "application/json",
            .acceptEncoding: "gzip, deflate, br",
        ]
    }
}