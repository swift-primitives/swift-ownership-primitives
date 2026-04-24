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

extension Ownership.Transfer {
    /// Storage for "create inside closure, retrieve after" pattern.
    ///
    /// Use Storage when a value will be created inside an escaping `@Sendable`
    /// closure and you need to retrieve it after the closure completes.
    ///
    /// ## Ownership Model
    /// - `init()` allocates empty ARC-managed storage
    /// - `token` produces a Sendable token for storing
    /// - `token.store(_:)` stores the value (exactly once, enforced atomically)
    /// - `consume()` retrieves the stored value and destroys the storage
    ///
    /// ## Thread Safety
    /// Designed for single-producer/single-consumer with happens-before:
    /// - Producer calls `store()` inside thread
    /// - Join provides happens-before
    /// - Consumer calls `consume()` after join
    ///
    /// Multiple copies of the token may exist (it's Copyable), but only one
    /// `store()` call will succeed. Additional calls trap deterministically.
    ///
    /// ## Usage
    /// ```swift
    /// let storage = Ownership.Transfer.Storage<MyType>()
    /// let storeToken = storage.token
    /// let handle = spawnThread {
    ///     storeToken.store(createValue())
    /// }
    /// handle.join()
    /// let value = storage.consume()
    /// ```
    public struct Storage<T: ~Copyable>: ~Copyable {
        private let _box: Ownership.Latch<T>

        /// Creates empty storage.
        public init() {
            _box = Ownership.Latch()
        }
    }
}

// MARK: - Token

extension Ownership.Transfer.Storage where T: ~Copyable {
    /// Token for storing a value into Storage.
    ///
    /// ## Safety
    /// - `Sendable`: Can cross thread boundaries safely
    /// - `Copyable`: Can be captured in escaping closures (required for lane/thread use)
    /// - ARC-managed: Strong reference to box, no retain-count hazards
    /// - Atomic one-shot: `store()` enforced atomically, second call traps
    ///
    /// ## Thread Safety
    /// Multiple copies of a token may exist (it's Copyable), but only one
    /// `store()` call will succeed. Additional calls trap deterministically.
    ///
    /// ## Invariants
    /// - `store()` must be called exactly once across all copies
    /// - Calling `store()` twice (on any copy) traps with a clear error message
    public struct Token: Sendable {
        /// Strong reference to the latch. ARC manages lifetime.
        private let _box: Ownership.Latch<T>

        init(_ box: Ownership.Latch<T>) {
            self._box = box
        }
    }
}

// MARK: - Token Store

extension Ownership.Transfer.Storage.Token where T: ~Copyable {
    /// Atomically stores a value.
    ///
    /// - Parameter value: The value to store.
    /// - Precondition: Must be called exactly once across all token copies.
    ///   Second call traps with a clear error message.
    public func store(_ value: consuming T) {
        _box.store(value)
    }
}

// MARK: - Storage Operations

extension Ownership.Transfer.Storage where T: ~Copyable {
    /// Returns a token for storing a value.
    ///
    /// The token must be consumed by calling `store(_:)` exactly once.
    /// This does NOT consume the storage — you still call `consume()` afterward.
    public var token: Token {
        Token(_box)
    }

    /// Destroys the storage and returns the stored value.
    ///
    /// Mirrors SE-0517's `consuming func consume() -> Value` pattern —
    /// `consume()` destroys `self` and yields the owned value.
    ///
    /// - Returns: The stored value.
    /// - Precondition: `store()` must have been called exactly once.
    public consuming func consume() -> T {
        _box.take()
    }


    /// Destroys the storage and returns the stored value if present,
    /// otherwise returns nil.
    ///
    /// Use this for cleanup paths where storage may or may not have been filled.
    ///
    /// - Returns: The stored value if `store()` was called, nil otherwise.
    public consuming func consumeIfStored() -> T? {
        _box.takeIfPresent()
    }
}
