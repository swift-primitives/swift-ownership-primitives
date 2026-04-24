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

internal import Synchronization

// MARK: - Store Operations

extension Ownership.Slot where Value: ~Copyable {
    /// Atomically stores a value into the slot.
    ///
    /// This is the primary, total store operation. If the slot is already
    /// occupied, the caller's value is bounced back unconsumed — exactly-once
    /// ownership is preserved.
    ///
    /// The return shape mirrors stdlib `Dictionary.updateValue(_:forKey:)`:
    /// the `Optional` carries the value the operation did NOT consume.
    ///
    /// ## Example
    ///
    /// ```swift
    /// if let returned = slot.store(resource) {
    ///     // Slot was occupied — `returned` is the value we tried to store.
    ///     releaseElsewhere(returned)
    /// } else {
    ///     // Slot was empty — `resource` is now stored.
    /// }
    /// ```
    ///
    /// - Parameter value: The value to store (ownership transferred on success).
    /// - Returns: `nil` if the slot was empty and the value is now stored;
    ///   `.some(value)` if the slot was occupied — the caller's value is
    ///   returned unconsumed.
    public func store(_ value: consuming Value) -> Value? {
        // Reserve: CAS empty -> initializing
        let (reserved, _) = _state.compareExchange(
            expected: State.empty,
            desired: State.initializing,
            ordering: .acquiringAndReleasing
        )
        guard reserved else {
            return value
        }

        // Initialize storage
        unsafe _storage.initialize(to: value)

        // Publish: store full (release ensures init is visible to takers)
        _state.store(State.full, ordering: .releasing)
        return nil
    }

    /// Atomically stores a value into the slot, trapping if occupied.
    ///
    /// Use this when failure indicates a logic error in the calling code.
    ///
    /// - Parameter value: The value to store (ownership transferred).
    /// - Precondition: The slot must be empty.
    public func store(__unchecked value: consuming Value) {
        if case .some = store(value) {
            preconditionFailure("Ownership.Slot.store(__unchecked:): already occupied")
        }
    }
}
