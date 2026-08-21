extension Ownership.Box where Value: ~Copyable {

    @safe
    @usableFromInline
    internal final class Storage {

        @usableFromInline
        internal let _payload: UnsafeMutablePointer<Value>

        @usableFromInline
        internal var value: Value {
            unsafeAddress { unsafe UnsafePointer(_payload) }
            unsafeMutableAddress { unsafe _payload }
        }

        @usableFromInline
        internal let _drain: @Sendable (inout Value) -> Void

        @usableFromInline
        internal let _clone: (@Sendable (borrowing Value) -> Value)?

        @usableFromInline
        internal init(
            _ value: consuming Value,
            drain: @escaping @Sendable (inout Value) -> Void,
            clone: (@Sendable (borrowing Value) -> Value)? = nil
        ) {
            let payload = UnsafeMutablePointer<Value>.allocate(capacity: 1)
            unsafe payload.initialize(to: value)
            unsafe (self._payload = payload)
            self._drain = drain
            self._clone = clone
        }

        deinit {
            _drain(&value)
            unsafe _payload.deinitialize(count: 1)
            unsafe _payload.deallocate()
            _fixLifetime(self)
        }
    }
}
