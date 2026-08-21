internal import Ownership_Latch_Primitives

extension Ownership.Transfer.Value where V: ~Copyable {

    public struct Outgoing: ~Copyable {
        internal let _latch: Ownership.Latch<V>

        public init(_ value: consuming sending V) {
            _latch = Ownership.Latch(value)
        }
    }
}

extension Ownership.Transfer.Value.Outgoing where V: ~Copyable {

    public consuming func token() -> Token {
        Token(_latch)
    }
}
