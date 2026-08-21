@safe
@usableFromInline
internal final class _Ownership_Borrow_OwnedBuffer<Value> {

    @usableFromInline
    let _pointer: UnsafeMutablePointer<Value>

    @inlinable
    package init(copying value: consuming Value) {
        unsafe (self._pointer = UnsafeMutablePointer<Value>.allocate(capacity: 1))
        unsafe self._pointer.initialize(to: value)
    }

    @inlinable
    deinit {
        unsafe _pointer.deinitialize(count: 1)
        unsafe _pointer.deallocate()
    }
}
