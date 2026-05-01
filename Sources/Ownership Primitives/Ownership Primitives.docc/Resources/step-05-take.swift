import Ownership_Primitives

struct Request: ~Copyable {
    var url: String
    var timeout: Duration
}

let cell = Ownership.Unique(
    Request(url: "https://example.com/status", timeout: .seconds(5))
)

// consume() is consuming: it destroys the cell and returns the value.
let owned = cell.consume()
// cell no longer exists — accessing it here would be a compile-time error.
// `owned` is the moved-out Request; the heap storage is deallocated.
