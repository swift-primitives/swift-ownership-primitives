extension Ownership {

    @safe
    public struct Borrow<Value: ~Copyable & ~Escapable>: ~Escapable {

        @usableFromInline
        let _pointer: UnsafeRawPointer

        @usableFromInline
        let _owner: AnyObject?

        @inlinable
        @_lifetime(borrow pointer)
        package init(
            _pointer pointer: UnsafeRawPointer,
            _owner owner: AnyObject?
        ) {
            unsafe (self._pointer = pointer)
            self._owner = owner
        }

        public typealias `Protocol` = __Ownership_Borrow_Protocol
    }
}

extension Ownership.Borrow where Value: ~Copyable {

    @inlinable
    @_lifetime(borrow pointer)
    public init(_ pointer: UnsafePointer<Value>) {
        unsafe (self._pointer = UnsafeRawPointer(pointer))
        self._owner = nil
    }
}

extension Ownership.Borrow where Value: ~Copyable {

    @_lifetime(borrow value)
    public init(borrowing value: borrowing Value) {
        unsafe (self._pointer = withUnsafePointer(to: value) { unsafe UnsafeRawPointer($0) })
        self._owner = nil
    }
}

extension Ownership.Borrow where Value: Copyable {

    @inlinable
    @_lifetime(borrow value)
    public init(borrowing value: borrowing Value) {
        let owner = _Ownership_Borrow_OwnedBuffer<Value>(copying: copy value)
        unsafe (self._pointer = UnsafeRawPointer(owner._pointer))
        self._owner = owner
    }
}

extension Ownership.Borrow where Value: ~Copyable {

    @unsafe
    @inlinable
    @_lifetime(borrow owner)
    public init<Owner: ~Copyable & ~Escapable>(
        unsafeAddress pointer: UnsafePointer<Value>,
        borrowing owner: borrowing Owner
    ) {
        unsafe (self._pointer = UnsafeRawPointer(pointer))
        self._owner = nil
    }
}

extension Ownership.Borrow where Value: ~Copyable & ~Escapable {

    @unsafe
    @inlinable
    @_lifetime(borrow owner)
    public init<Owner: ~Copyable & ~Escapable>(
        unsafeRawAddress pointer: UnsafeRawPointer,
        borrowing owner: borrowing Owner
    ) {
        unsafe (self._pointer = pointer)
        self._owner = nil
    }
}

extension Ownership.Borrow where Value: ~Copyable {

    @inlinable
    public var value: Value {
        _read {
            yield unsafe _pointer.assumingMemoryBound(to: Value.self).pointee
        }
    }
}
