extension Ownership.Slot where Value: ~Copyable {

    public var move: Move {
        Move(slot: self)
    }
}

extension Ownership.Slot where Value: ~Copyable {

    public struct Move {
        @usableFromInline
        let slot: Ownership.Slot<Value>

        @usableFromInline
        init(slot: Ownership.Slot<Value>) {
            self.slot = slot
        }
    }
}

extension Ownership.Slot.Move where Value: ~Copyable {

    public var out: Value {

        slot.take(__unchecked: ())
    }

    public func `in`(_ value: consuming sending Value) {

        slot.store(__unchecked: value)
    }
}
