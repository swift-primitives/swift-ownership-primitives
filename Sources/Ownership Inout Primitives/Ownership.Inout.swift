extension Ownership {

    @safe
    public struct Inout<Value: ~Copyable & ~Escapable>: ~Copyable, ~Escapable {

        @usableFromInline
        let _pointer: UnsafeMutableRawPointer
    }
}

extension Ownership.Inout where Value: ~Copyable {

    @inlinable
    @_lifetime(borrow pointer)
    public init(_ pointer: UnsafeMutablePointer<Value>) {
        unsafe self._pointer = UnsafeMutableRawPointer(pointer)
    }
}

extension Ownership.Inout where Value: ~Copyable {

    @_transparent
    @_lifetime(&value)
    public init(mutating value: inout Value) {

        unsafe (_pointer = withUnsafeMutablePointer(to: &value) { UnsafeMutableRawPointer($0) })
    }
}

extension Ownership.Inout where Value: ~Copyable {

    @unsafe
    @inlinable
    @_lifetime(&owner)
    public init<Owner: ~Copyable & ~Escapable>(
        unsafeAddress pointer: UnsafeMutablePointer<Value>,
        mutating owner: inout Owner
    ) {
        unsafe (self._pointer = UnsafeMutableRawPointer(pointer))
    }
}

extension Ownership.Inout where Value: ~Copyable & ~Escapable {

    @unsafe
    @inlinable
    @_lifetime(&owner)
    public init<Owner: ~Copyable & ~Escapable>(
        unsafeRawAddress pointer: UnsafeMutableRawPointer,
        mutating owner: inout Owner
    ) {
        unsafe (self._pointer = pointer)
    }
}

extension Ownership.Inout where Value: ~Copyable {

    @inlinable
    public var value: Value {
        _read { yield unsafe _pointer.assumingMemoryBound(to: Value.self).pointee }
        nonmutating _modify { yield unsafe &_pointer.assumingMemoryBound(to: Value.self).pointee }
    }
}

extension Ownership.Inout where Value: Copyable {

    @inlinable
    public var value: Value {
        get { unsafe _pointer.assumingMemoryBound(to: Value.self).pointee }
        nonmutating _modify { yield unsafe &_pointer.assumingMemoryBound(to: Value.self).pointee }
    }
}
