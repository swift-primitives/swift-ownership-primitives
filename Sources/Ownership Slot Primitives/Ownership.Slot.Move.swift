// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-primitives open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-primitives
// project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

// MARK: - Move Accessor

extension Ownership.Slot where Value: ~Copyable {
    /// Accessor for move operations using fluent syntax.
    ///
    /// Provides `slot.move.in(value)` and `slot.move.out` as alternatives
    /// to the trapping `store(__unchecked:)` and `take(__unchecked:)`.
    public var move: Move {
        Move(slot: self)
    }
}

// MARK: - Move Type

extension Ownership.Slot where Value: ~Copyable {
    /// Namespace for fluent value move operations.
    ///
    /// These operations trap on failure—use the total `store(_:)` and `take()`
    /// methods when you need to handle failure gracefully.
    public struct Move {
        @usableFromInline
        let slot: Ownership.Slot<Value>

        @usableFromInline
        init(slot: Ownership.Slot<Value>) {
            self.slot = slot
        }
    }
}

// MARK: - Move Operations

extension Ownership.Slot.Move where Value: ~Copyable {
    /// Takes the value out of the slot.
    ///
    /// - Precondition: Slot must be occupied.
    /// - Returns: The stored value.
    public var out: Value {
        slot.take(__unchecked: ())
    }

    /// Puts a value into the slot.
    ///
    /// - Precondition: Slot must be empty.
    /// - Parameter value: The value to store.
    public func `in`(_ value: consuming Value) {
        slot.store(__unchecked: value)
    }
}
