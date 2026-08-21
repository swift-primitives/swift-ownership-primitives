internal import Ownership_Latch_Primitives

extension Ownership.Transfer.Value.Outgoing where V: ~Copyable {

    public struct Token: Sendable {
        internal let _latch: Ownership.Latch<V>

        internal init(_ latch: Ownership.Latch<V>) {
            self._latch = latch
        }
    }
}

extension Ownership.Transfer.Value.Outgoing.Token where V: ~Copyable {

    public func take() -> sending V {
        guard let value = _latch.take() else {
            preconditionFailure(
                "Ownership.Transfer.Value.Outgoing.Token.take(): called twice or on a latch that was never filled"
            )
        }
        return value
    }
}
