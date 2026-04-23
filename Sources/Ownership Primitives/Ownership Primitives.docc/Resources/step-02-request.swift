import Ownership_Primitives

struct Request: ~Copyable {
    var url: String
    var timeout: Duration
}
