extension Ownership {

    @frozen
    public struct Box<Value: ~Copyable> {

        @usableFromInline
        internal var storage: Storage

        @inlinable
        public init(
            _ value: consuming Value,
            drain: @escaping @Sendable (inout Value) -> Void,
            clone: (@Sendable (borrowing Value) -> Value)? = nil
        ) {
            self.storage = Storage(value, drain: drain, clone: clone)
        }

        @usableFromInline
        internal init(storage: consuming Storage) {
            self.storage = storage
        }
    }
}

extension Ownership.Box: @unchecked Sendable where Value: Sendable & ~Copyable {}

extension Ownership.Box where Value: Copyable {

    @inlinable
    public init(_ value: consuming Value) {
        self.init(value, drain: { _ in }, clone: { $0 })
    }
}

extension Ownership.Box where Value: ~Copyable {

    @inlinable
    public var isUnique: Bool {
        mutating get { isKnownUniquelyReferenced(&storage) }
    }

    @inlinable
    @discardableResult
    public mutating func ensureUnique() -> Bool {
        guard !isKnownUniquelyReferenced(&storage) else { return false }
        guard let clone = storage._clone else {

            preconditionFailure("Ownership.Box backing is shared but carries no clone strategy")
        }
        storage = Storage(clone(storage.value), drain: storage._drain, clone: storage._clone)
        return true
    }
}

extension Ownership.Box where Value: ~Copyable {

    @inlinable
    public var value: Value {
        _read { yield storage.value }
        _modify {
            ensureUnique()
            yield &storage.value
        }
    }

    @inlinable
    public var unguarded: Value {
        unsafeAddress { unsafe UnsafePointer(storage._payload) }
        unsafeMutableAddress { unsafe storage._payload }
    }

    @inlinable
    public var identity: ObjectIdentifier {
        ObjectIdentifier(storage)
    }
}

extension Ownership.Box where Value: Copyable {

    @inlinable
    public borrowing func clone() -> Ownership.Box<Value> {
        Ownership.Box(storage: Storage(storage.value, drain: storage._drain, clone: storage._clone))
    }
}
