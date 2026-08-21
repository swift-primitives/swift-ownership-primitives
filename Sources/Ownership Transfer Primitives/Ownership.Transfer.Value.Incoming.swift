internal import Ownership_Latch_Primitives

extension Ownership.Transfer.Value where V: ~Copyable {

    public struct Incoming: ~Copyable {
        internal let _latch: Ownership.Latch<V>

        public init() {
            _latch = Ownership.Latch()
        }
    }
}

extension Ownership.Transfer.Value.Incoming where V: ~Copyable {

    public var token: Token {
        Token(_latch)
    }

    public consuming func consume() -> sending V? {
        _latch.take()
    }
}
