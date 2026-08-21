public import Synchronization

extension Ownership {

    @safe
    public final class Latch<Value: ~Copyable>: @unchecked Sendable {

        @usableFromInline
        let _state: Atomic<Int>

        @usableFromInline
        var _storage: UnsafeMutablePointer<Value>?

        public init(_ value: consuming Value) {
            _state = Atomic(State.initializing)
            let p = UnsafeMutablePointer<Value>.allocate(capacity: 1)
            unsafe p.initialize(to: value)
            unsafe (_storage = p)
            _state.store(State.full, ordering: .releasing)
        }

        public init() {
            _state = Atomic(State.empty)
            unsafe (_storage = nil)
        }

        deinit {
            let state = _state.load(ordering: .acquiring)
            if state == State.full, let p = unsafe _storage {

                unsafe p.deinitialize(count: 1)
                unsafe p.deallocate()
            }

        }
    }
}

extension Ownership.Latch where Value: ~Copyable {

    @usableFromInline
    typealias State = __OwnershipLatchState
}

extension Ownership.Latch where Value: ~Copyable {

    public func store(_ value: consuming sending Value) {

        let (reserved, original) = _state.compareExchange(
            expected: State.empty,
            desired: State.initializing,
            ordering: .acquiringAndReleasing
        )
        if !reserved {
            if original == State.full || original == State.initializing {
                preconditionFailure("Ownership.Latch: store() called when value already present")
            } else {
                preconditionFailure("Ownership.Latch: store() called after take()")
            }
        }

        let p = UnsafeMutablePointer<Value>.allocate(capacity: 1)
        unsafe p.initialize(to: value)
        unsafe (_storage = p)

        _state.store(State.full, ordering: .releasing)
    }
}

extension Ownership.Latch where Value: ~Copyable {

    public func take() -> sending Value? {

        let (exchanged, _) = _state.compareExchange(
            expected: State.full,
            desired: State.taken,
            ordering: .acquiringAndReleasing
        )
        guard exchanged else {
            return nil
        }

        guard let p = unsafe _storage else {
            preconditionFailure(
                "Ownership.Latch: state-CAS succeeded but _storage was nil — protocol violation"
            )
        }
        unsafe (_storage = nil)
        let value = unsafe p.move()
        unsafe p.deallocate()
        return value
    }
}

extension Ownership.Latch where Value: ~Copyable {

    public var hasValue: Bool {
        _state.load(ordering: .acquiring) == State.full
    }
}
