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
