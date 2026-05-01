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

// MARK: - Erased.Incoming

extension Ownership.Transfer.Erased {
    /// Incoming type-erased transfer — consumer allocates an empty slot for
    /// the producer to fill with a boxed value of an out-of-band-agreed
    /// payload type.
    ///
    /// Mirror of ``Ownership/Transfer/Erased/Outgoing``: Outgoing flows
    /// producer→consumer at box-creation time; Incoming flows the other way
    /// — the consumer stands up an empty slot, the producer boxes a value
    /// via `Erased.Outgoing.make(_:)` and stores the opaque pointer through
    /// a Sendable token, and the consumer unboxes on the far side with
    /// `consume(_:)`.
    ///
    /// ## Ownership Model
    /// - `init()` allocates empty ARC-managed storage.
    /// - `token` produces a Sendable token for storing a boxed-pointer.
    /// - `token.store(_:)` atomically publishes the opaque pointer.
    /// - `consume(_:)` atomically takes the pointer and unboxes into the
    ///   consumer-known `T`.
    /// - `consumeIfStored(_:)` same as consume, but returns `nil` if the
    ///   slot was never filled.
    ///
    /// ## Safety Invariant
    ///
    /// Atomic state machine in the shared latch + release/acquire
    /// publication protocol protects the stored pointer.
    /// `@unsafe @unchecked Sendable` per [MEM-SAFE-024] Category A
    /// (synchronized).
    @safe
    public struct Incoming: ~Copyable, @unsafe @unchecked Sendable {
        internal let _latch: Ownership.Latch<UnsafeMutableRawPointer>

        /// Creates empty incoming storage.
        public init() {
            unsafe (_latch = Ownership.Latch())
        }
    }
}

// MARK: - Operations

extension Ownership.Transfer.Erased.Incoming {
    /// Returns a Sendable token that the producer uses to `store` a boxed
    /// opaque pointer (produced by `Erased.Outgoing.make(_:)`).
    public var token: Token {
        unsafe Token(_latch)
    }

    /// Destroys the slot, unboxes the stored pointer as `T`, and returns
    /// the result.
    ///
    /// - Parameter type: The payload type agreed between producer and consumer.
    /// - Returns: The unboxed value.
    /// - Precondition: `token.store(_:)` must have been called exactly once.
    @unsafe
    public consuming func consume<T>(_ type: T.Type) -> T {
        let raw = unsafe _latch.take()
        return unsafe Ownership.Transfer.Erased.Outgoing.consume(raw)
    }

    /// Destroys the slot and unboxes the stored pointer as `T` if present;
    /// returns `nil` if the slot was never filled.
    ///
    /// Use this on cleanup paths where the slot may or may not have been
    /// filled.
    @unsafe
    public consuming func consumeIfStored<T>(_ type: T.Type) -> T? {
        guard let raw = unsafe _latch.takeIfPresent() else { return nil }
        return unsafe Ownership.Transfer.Erased.Outgoing.consume(raw)
    }
}
