extension Ownership {

    @safe
    @frozen
    public struct Unique<Value: ~Copyable>: ~Copyable {

        @usableFromInline
        internal let _storage: UnsafeMutablePointer<Value>

        @inlinable
        public init(_ initialValue: consuming Value) {
            let storage = UnsafeMutablePointer<Value>.allocate(capacity: 1)
            unsafe storage.initialize(to: initialValue)
            unsafe (self._storage = storage)
        }

        deinit {
            unsafe _storage.deinitialize(count: 1)
            unsafe _storage.deallocate()
        }
    }
}

extension Ownership.Unique: @unchecked Sendable where Value: ~Copyable & Sendable {}

extension Ownership.Unique where Value: ~Copyable {

    @inlinable
    public var value: Value {
        _read { yield unsafe _storage.pointee }
        _modify { yield unsafe &_storage.pointee }
    }
}

extension Ownership.Unique where Value: ~Copyable {

    public consuming func consume() -> Value {
        let value = unsafe _storage.move()
        unsafe _storage.deallocate()
        discard self
        return value
    }
}

extension Ownership.Unique where Value: ~Copyable {

    @inlinable
    public var span: Swift.Span<Value> {
        @_lifetime(borrow self)
        borrowing get {
            unsafe Span(_unsafeStart: _storage, count: 1)
        }
    }

    @inlinable
    public var mutableSpan: MutableSpan<Value> {
        @_lifetime(&self)
        mutating get {
            unsafe MutableSpan(_unsafeStart: _storage, count: 1)
        }
    }
}
