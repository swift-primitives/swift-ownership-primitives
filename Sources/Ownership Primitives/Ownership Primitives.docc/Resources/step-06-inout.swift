import Ownership_Primitives

struct Request: ~Copyable {
    var url: String
    var timeout: Duration
}

func applyDefaults(to request: inout Request) {
    let ref = Ownership.Inout(mutating: &request)
    // `ref` is @safe, ~Copyable, ~Escapable; its lifetime is bound to
    // the caller's &request scope.
    _ = ref
}
