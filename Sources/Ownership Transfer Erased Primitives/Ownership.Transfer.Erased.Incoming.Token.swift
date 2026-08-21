internal import Ownership_Latch_Primitives

extension Ownership.Transfer.Erased.Incoming {

    @safe
    public struct Token: Sendable {
        internal let _latch: Ownership.Latch<UnsafeMutableRawPointer>

        internal init(_ latch: Ownership.Latch<UnsafeMutableRawPointer>) {
            unsafe (self._latch = latch)
        }
    }
}

extension Ownership.Transfer.Erased.Incoming.Token {

    @unsafe
    public func store(_ raw: sending UnsafeMutableRawPointer) {
        unsafe _latch.store(raw)
    }
}
