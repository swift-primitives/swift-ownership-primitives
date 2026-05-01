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

// MARK: - Value.Outgoing.Token

extension Ownership.Transfer.Value.Outgoing where V: ~Copyable {
    /// Sendable token referencing the outgoing cell's ARC-managed storage.
    ///
    /// ## Safety
    /// - `Sendable` — crosses thread boundaries safely.
    /// - `Copyable` — can be captured in escaping closures (required for
    ///   lane/thread use).
    /// - ARC-managed — strong reference to the atomic state machine.
    /// - Atomic one-shot — `take()` enforced atomically; a second call traps.
    ///
    /// ## Invariants
    /// - `take()` must be called exactly once across all token copies.
    /// - Calling `take()` twice (on any copy) traps with a clear error message.
    public struct Token: Sendable {
        internal let _latch: Ownership.Latch<V>

        internal init(_ latch: Ownership.Latch<V>) {
            self._latch = latch
        }
    }
}

// MARK: - Take

extension Ownership.Transfer.Value.Outgoing.Token where V: ~Copyable {
    /// Atomically takes the stored value.
    ///
    /// - Returns: The stored value.
    /// - Precondition: Must be called exactly once across all token copies.
    ///   Second call traps with a clear error message.
    public func take() -> V {
        _latch.take()
    }
}
