import Ownership_Primitives

struct Request: ~Copyable {
    var url: String
    var timeout: Duration
}

var cell = Ownership.Unique(
    Request(url: "https://example.com/status", timeout: .seconds(5))
)

// Direct access via the _modify coroutine on `value`.
cell.value.timeout = .seconds(30)
