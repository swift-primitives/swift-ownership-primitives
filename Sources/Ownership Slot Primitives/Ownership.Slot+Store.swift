internal import Synchronization

extension Ownership.Slot where Value: ~Copyable {

    public func store(_ value: consuming sending Value) -> Value? {

        let (reserved, _) = _state.compareExchange(
            expected: State.empty,
            desired: State.initializing,
            ordering: .acquiringAndReleasing
        )
        guard reserved else {
            return value
        }

        unsafe _storage.initialize(to: value)

        _state.store(State.full, ordering: .releasing)
        return nil
    }

    public func store(__unchecked value: consuming sending Value) {
        if case .some = store(value) {
            preconditionFailure("Ownership.Slot.store(__unchecked:): already occupied")
        }
    }
}
