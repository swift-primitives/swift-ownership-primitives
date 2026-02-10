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

public import Synchronization

// MARK: - Store Result

extension Ownership.Slot where Value: ~Copyable {
    /// Result of a total store operation.
    ///
    /// For `~Copyable` values, this enum ensures the value is never silently
    /// discarded on failure—it is returned to the caller for handling.
    public enum Store: ~Copyable {
        /// The value was successfully stored in the slot.
        case stored
        /// The slot was already occupied. The value is returned unconsumed.
        case occupied(Value)
    }
}

// MARK: - Store Operations

extension Ownership.Slot where Value: ~Copyable {
    /// Atomically stores a value into the slot.
    ///
    /// This is the primary, total store operation. If the slot is occupied,
    /// the value is returned to the caller rather than being discarded.
    ///
    /// - Parameter value: The value to store (ownership transferred on success).
    /// - Returns: `.stored` on success, or `.occupied(value)` if the slot was full.
    public func store(_ value: consuming Value) -> Store {
        // Reserve: CAS empty -> initializing
        let (reserved, _) = _state.compareExchange(
            expected: State.empty,
            desired: State.initializing,
            ordering: .acquiringAndReleasing
        )
        guard reserved else {
            return .occupied(value)
        }

        // Initialize storage
        unsafe _storage.initialize(to: value)

        // Publish: store full (release ensures init is visible to takers)
        _state.store(State.full, ordering: .releasing)
        return .stored
    }

    /// Atomically stores a value into the slot, trapping if occupied.
    ///
    /// Use this when failure indicates a logic error in the calling code.
    ///
    /// - Parameter value: The value to store (ownership transferred).
    /// - Precondition: The slot must be empty.
    public func store(__unchecked value: consuming Value) {
        switch store(value) {
        case .stored:
            return
        case .occupied:
            preconditionFailure("Ownership.Slot.store(__unchecked:): already occupied")
        }
    }
}

// MARK: - Take Operations

extension Ownership.Slot where Value: ~Copyable {
    /// Atomically takes the value from the slot if present.
    ///
    /// This is the primary, total take operation.
    ///
    /// - Returns: The stored value, or `nil` if empty.
    public func take() -> Value? {
        // CAS full -> empty
        let (exchanged, _) = _state.compareExchange(
            expected: State.full,
            desired: State.empty,
            ordering: .acquiringAndReleasing
        )
        guard exchanged else {
            return nil
        }
        return unsafe _storage.move()
    }

    /// Atomically takes the value from the slot, trapping if empty.
    ///
    /// Use this when failure indicates a logic error in the calling code.
    ///
    /// - Returns: The stored value.
    /// - Precondition: The slot must be occupied.
    public func take(__unchecked: Void) -> Value {
        guard let value = take() else {
            preconditionFailure("Ownership.Slot.take(__unchecked:): already empty")
        }
        return value
    }
}
