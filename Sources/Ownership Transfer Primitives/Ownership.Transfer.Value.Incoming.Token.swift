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

// MARK: - Value.Incoming.Token

extension Ownership.Transfer.Value.Incoming where V: ~Copyable {
    /// Sendable token for storing a value into an ``Ownership/Transfer/Value/Incoming``.
    ///
    /// ## Safety
    /// - `Sendable` — crosses thread boundaries safely.
    /// - `Copyable` — can be captured in escaping closures (required for
    ///   lane/thread use).
    /// - ARC-managed — strong reference to the atomic state machine.
    /// - Atomic one-shot — `store()` enforced atomically; a second call traps.
    ///
    /// ## Invariants
    /// - `store()` must be called exactly once across all token copies.
    /// - Calling `store()` twice (on any copy) traps with a clear error message.
    public struct Token: Sendable {
        internal let _latch: Ownership.Latch<V>

        internal init(_ latch: Ownership.Latch<V>) {
            self._latch = latch
        }
    }
}

// MARK: - Store

extension Ownership.Transfer.Value.Incoming.Token where V: ~Copyable {
    /// Atomically stores a value into the incoming slot.
    ///
    /// - Parameter value: The value to store (ownership transferred).
    /// - Precondition: Must be called exactly once across all token copies.
    ///   Second call traps with a clear error message.
    public func store(_ value: consuming V) {
        _latch.store(value)
    }
}
