internal import Ownership_Latch_Primitives

extension Ownership.Transfer.Retained {

    @safe
    public struct Incoming: ~Copyable, Sendable {
        internal let _latch: Ownership.Latch<T>

        public init() {
            _latch = Ownership.Latch()
        }
    }
}

extension Ownership.Transfer.Retained.Incoming where T: Copyable {

    public var token: Token {
        Token(_latch)
    }

    public consuming func consume() -> T? {
        _latch.take()
    }
}
