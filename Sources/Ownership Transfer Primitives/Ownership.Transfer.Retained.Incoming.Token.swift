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

internal import Ownership_Latch_Primitives

// MARK: - Retained.Incoming.Token

extension Ownership.Transfer.Retained.Incoming {
    /// Sendable token for storing a retained class reference into a
    /// ``Ownership/Transfer/Retained/Incoming``.
    ///
    /// ## Safety
    /// - `Sendable` — crosses thread boundaries safely.
    /// - `Copyable` — can be captured in escaping closures.
    /// - ARC-managed — strong reference to the atomic state machine.
    /// - Atomic one-shot — `store()` enforced atomically; a second call traps.
    ///
    /// ## Invariants
    /// - `store()` must be called exactly once across all token copies.
    /// - Calling `store()` twice (on any copy) traps with a clear error message.
    public struct Token: Sendable {
        internal let _latch: Ownership.Latch<T>

        internal init(_ latch: Ownership.Latch<T>) {
            self._latch = latch
        }
    }
}

// MARK: - Store

extension Ownership.Transfer.Retained.Incoming.Token {
    /// Atomically stores a class reference into the incoming slot.
    ///
    /// The caller retains ownership semantics through the slot: the stored
    /// reference is held until `consume()` returns it to the consumer (or
    /// the slot's deinit cleans up an un-consumed reference).
    ///
    /// - Parameter instance: The object to store.
    /// - Precondition: Must be called exactly once across all token copies.
    ///   Second call traps with a clear error message.
    public func store(_ instance: T) {
        _latch.store(instance)
    }
}
