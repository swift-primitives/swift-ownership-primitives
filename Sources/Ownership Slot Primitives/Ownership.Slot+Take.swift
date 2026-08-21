internal import Synchronization

extension Ownership.Slot where Value: ~Copyable {

    public func take() -> sending Value? {

        let (exchanged, _) = _state.compareExchange(
            expected: State.full,
            desired: State.draining,
            ordering: .acquiringAndReleasing
        )
        guard exchanged else {
            return nil
        }

        let value = unsafe _storage.move()

        _state.store(State.empty, ordering: .releasing)
        return value
    }

    public func take(__unchecked: Void) -> sending Value {
        guard let value = take() else {
            preconditionFailure("Ownership.Slot.take(__unchecked:): already empty")
        }
        return value
    }
}
