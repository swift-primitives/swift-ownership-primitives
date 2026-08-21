internal import Ownership_Latch_Primitives

extension Ownership.Transfer.Value.Incoming where V: ~Copyable {

    public struct Token: Sendable {
        internal let _latch: Ownership.Latch<V>

        internal init(_ latch: Ownership.Latch<V>) {
            self._latch = latch
        }
    }
}

extension Ownership.Transfer.Value.Incoming.Token where V: ~Copyable {

    public func store(_ value: consuming sending V) {
        _latch.store(value)
    }
}
