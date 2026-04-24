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

// MARK: - Take Operations

extension Ownership.Slot where Value: ~Copyable {
    /// Atomically takes the value from the slot if present.
    ///
    /// This is the primary, total take operation.
    ///
    /// - Returns: The stored value, or `nil` if empty.
    public func take() -> sending Value? {
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
    public func take(__unchecked: Void) -> sending Value {
        guard let value = take() else {
            preconditionFailure("Ownership.Slot.take(__unchecked:): already empty")
        }
        return value
    }
}
