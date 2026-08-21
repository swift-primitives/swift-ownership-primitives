extension Ownership.Unique where Value: Copyable {

    @inlinable
    public borrowing func clone() -> Ownership.Unique<Value> {
        return unsafe Ownership.Unique(_storage.pointee)
    }
}
