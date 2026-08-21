internal import Ownership_Latch_Primitives

extension Ownership.Transfer.Retained.Incoming {

    public struct Token: Sendable {
        internal let _latch: Ownership.Latch<T>

        internal init(_ latch: Ownership.Latch<T>) {
            self._latch = latch
        }
    }
}

extension Ownership.Transfer.Retained.Incoming.Token {

    public func store(_ instance: sending T) {
        _latch.store(instance)
    }
}
