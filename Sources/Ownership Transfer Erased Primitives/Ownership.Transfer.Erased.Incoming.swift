internal import Ownership_Latch_Primitives

extension Ownership.Transfer.Erased {

    @safe
    public struct Incoming: ~Copyable, Sendable {
        internal let _latch: Ownership.Latch<UnsafeMutableRawPointer>

        public init() {
            unsafe (_latch = Ownership.Latch())
        }
    }
}

extension Ownership.Transfer.Erased.Incoming {

    public var token: Token {
        unsafe Token(_latch)
    }

    @unsafe
    public consuming func consume<T>(_ type: T.Type) -> T? {
        guard let raw = unsafe _latch.take() else { return nil }
        return unsafe Ownership.Transfer.Erased.Outgoing.consume(raw)
    }
}
