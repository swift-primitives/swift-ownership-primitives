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

// MARK: - Erased.Incoming.Token

extension Ownership.Transfer.Erased.Incoming {
    /// Sendable token for storing a boxed opaque pointer into an
    /// ``Ownership/Transfer/Erased/Incoming``.
    ///
    /// ## Safety
    /// - `Sendable` — crosses thread boundaries safely.
    /// - `Copyable` — can be captured in escaping closures.
    /// - ARC-managed — strong reference to the atomic state machine.
    /// - Atomic one-shot — `store()` enforced atomically; a second call traps.
    @safe
    public struct Token: Sendable {
        internal let _latch: Ownership.Latch<UnsafeMutableRawPointer>

        internal init(_ latch: Ownership.Latch<UnsafeMutableRawPointer>) {
            unsafe (self._latch = latch)
        }
    }
}

// MARK: - Store

extension Ownership.Transfer.Erased.Incoming.Token {
    /// Atomically stores an opaque boxed-pointer into the incoming slot.
    ///
    /// - Parameter raw: An opaque pointer produced by
    ///   ``Ownership/Transfer/Erased/Outgoing/make(_:)``.
    /// - Precondition: Must be called exactly once across all token copies.
    ///   Second call traps with a clear error message.
    @unsafe
    public func store(_ raw: UnsafeMutableRawPointer) {
        unsafe _latch.store(raw)
    }
}
