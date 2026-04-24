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

// MARK: - Retained.Incoming

extension Ownership.Transfer.Retained {
    /// Incoming AnyObject transfer — consumer allocates an empty slot for
    /// the producer to fill with a retained class instance across a
    /// `@Sendable` boundary.
    ///
    /// Mirror of ``Ownership/Transfer/Retained/Outgoing``: where Outgoing
    /// flows producer→consumer at construction time, Incoming flows the
    /// other way — the consumer stands up an empty slot before the producer
    /// has the object, the producer fills it through a Sendable token, and
    /// the consumer reads the retained reference back after a
    /// happens-before edge.
    ///
    /// ## Ownership Model
    /// - `init()` allocates empty ARC-managed storage (one heap class).
    /// - `token` produces a Sendable token for the producer to store a
    ///   retained class reference.
    /// - `token.store(_:)` retains the instance and atomically publishes it.
    /// - `consume()` atomically takes ownership of the retained reference
    ///   and destroys the slot; the `~Copyable` constraint makes
    ///   double-consume unrepresentable.
    ///
    /// ## Usage
    /// ```swift
    /// let incoming = Ownership.Transfer.Retained<Service>.Incoming()
    /// let token = incoming.token
    /// let handle = spawnThread {
    ///     token.store(Service())
    /// }
    /// handle.join()
    /// let service = incoming.consume()
    /// ```
    ///
    /// ## Safety Invariant
    ///
    /// Atomic state machine in the shared latch + release/acquire
    /// publication protocol protects the stored class reference.
    /// `@unsafe @unchecked Sendable` per [MEM-SAFE-024] Category A
    /// (synchronized).
    @safe
    public struct Incoming: ~Copyable, @unsafe @unchecked Sendable {
        internal let _latch: Ownership.Latch<T>

        /// Creates empty incoming storage.
        public init() {
            _latch = Ownership.Latch()
        }
    }
}

// MARK: - Operations

extension Ownership.Transfer.Retained.Incoming {
    /// Returns a Sendable token that the producer uses to `store` a
    /// retained class reference into this slot.
    ///
    /// Reading `token` does NOT consume the slot — the consumer still calls
    /// `consume()` afterward to retrieve the stored object.
    public var token: Token {
        Token(_latch)
    }

    /// Destroys the slot and returns the retained class reference.
    ///
    /// Mirrors SE-0517's `consuming func consume() -> Value` pattern.
    ///
    /// - Returns: The retained object. The caller now owns this reference.
    /// - Precondition: `token.store(_:)` must have been called exactly once.
    public consuming func consume() -> T {
        _latch.take()
    }

    /// Destroys the slot and returns the retained reference if present,
    /// otherwise returns `nil`.
    ///
    /// Use this on cleanup paths where the slot may or may not have been
    /// filled (cancelled producer, failed handshake).
    ///
    /// - Returns: The retained object if `token.store(_:)` was called,
    ///   nil otherwise.
    public consuming func consumeIfStored() -> T? {
        _latch.takeIfPresent()
    }
}
