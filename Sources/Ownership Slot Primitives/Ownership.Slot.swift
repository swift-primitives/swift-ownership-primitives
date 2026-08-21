public import Synchronization

extension Ownership {

    @safe
    public final class Slot<Value: ~Copyable>: @unchecked Sendable {

        @usableFromInline
        let _state: Atomic<UInt8>

        @usableFromInline
        let _storage: UnsafeMutablePointer<Value>

        public init() {
            _state = Atomic(State.empty)
            unsafe (_storage = .allocate(capacity: 1))
        }

        public init(_ value: consuming sending Value) {
            _state = Atomic(State.initializing)
            unsafe (_storage = .allocate(capacity: 1))
            unsafe _storage.initialize(to: value)
            _state.store(State.full, ordering: .releasing)
        }

        deinit {
            let prior = _state.exchange(State.empty, ordering: .acquiringAndReleasing)
            if prior == State.full {
                unsafe _storage.deinitialize(count: 1)
            }

            unsafe _storage.deallocate()
        }
    }
}

extension Ownership.Slot where Value: ~Copyable {

    @usableFromInline
    typealias State = __OwnershipSlotState
}

extension Ownership.Slot where Value: ~Copyable {

    public var isEmpty: Bool {
        _state.load(ordering: .acquiring) == State.empty
    }

    public var isFull: Bool {
        _state.load(ordering: .acquiring) == State.full
    }
}
