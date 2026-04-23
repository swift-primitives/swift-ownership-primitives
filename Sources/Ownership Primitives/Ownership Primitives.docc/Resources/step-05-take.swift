import Ownership_Primitives

struct Request: ~Copyable {
    var url: String
    var timeout: Duration
}

var cell = Ownership.Unique(
    Request(url: "https://example.com/status", timeout: .seconds(5))
)

cell.withMutableValue { request in
    request.timeout = .seconds(30)
}

let owned = cell.take()
precondition(!cell.hasValue)
// `owned` is the moved-out Request; the heap storage is deallocated.
