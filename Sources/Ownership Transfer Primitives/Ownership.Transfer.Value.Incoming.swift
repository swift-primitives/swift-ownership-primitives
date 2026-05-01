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

// MARK: - Value.Incoming

extension Ownership.Transfer.Value where V: ~Copyable {
    /// Incoming value cell — consumer allocates an empty slot for the
    /// producer to fill across a `@Sendable` boundary.
    ///
    /// Use ``Ownership/Transfer/Value/Incoming`` when a value will be
    /// created inside an escaping `@Sendable` closure and you need to
    /// retrieve it after the closure completes.
    ///
    /// ## Ownership Model
    /// - `init()` allocates empty ARC-managed storage.
    /// - `token` produces a Sendable token for storing.
    /// - `token.store(_:)` stores the value (exactly once, enforced atomically).
    /// - `consume()` retrieves the stored value and destroys the storage.
    ///
    /// ## Thread Safety
    /// Designed for single-producer/single-consumer with a happens-before
    /// edge between store and consume. Multiple copies of the token may
    /// exist (it is Copyable), but only one `store()` call will succeed —
    /// additional calls trap deterministically.
    ///
    /// ## Usage
    /// ```swift
    /// let incoming = Ownership.Transfer.Value<MyType>.Incoming()
    /// let storeToken = incoming.token
    /// let handle = spawnThread {
    ///     storeToken.store(createValue())
    /// }
    /// handle.join()
    /// let value = incoming.consume()
    /// ```
    public struct Incoming: ~Copyable {
        internal let _latch: Ownership.Latch<V>

        /// Creates empty incoming storage.
        public init() {
            _latch = Ownership.Latch()
        }
    }
}

// MARK: - Operations

extension Ownership.Transfer.Value.Incoming where V: ~Copyable {
    /// Returns a Sendable token that the producer can use to `store` a value
    /// into this incoming slot.
    ///
    /// Reading `token` does NOT consume the slot — the consumer still calls
    /// `consume()` afterward to retrieve the filled value.
    public var token: Token {
        Token(_latch)
    }

    /// Destroys the slot and returns the stored value.
    ///
    /// Mirrors SE-0517's `consuming func consume() -> Value` pattern:
    /// `consume()` destroys `self` and yields the owned value.
    ///
    /// - Returns: The stored value.
    /// - Precondition: `token.store(_:)` must have been called exactly once.
    public consuming func consume() -> V {
        _latch.take()
    }

    /// Destroys the slot and returns the stored value if present, otherwise
    /// returns `nil`.
    ///
    /// Use this on cleanup paths where the slot may or may not have been
    /// filled (e.g., cancelled producer, failed handshake).
    ///
    /// - Returns: The stored value if `token.store(_:)` was called, nil otherwise.
    public consuming func consumeIfStored() -> V? {
        _latch.takeIfPresent()
    }
}
