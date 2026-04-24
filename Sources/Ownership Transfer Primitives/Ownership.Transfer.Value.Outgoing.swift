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

// MARK: - Value.Outgoing

extension Ownership.Transfer.Value where V: ~Copyable {
    /// Outgoing value cell — producer already holds the value and hands it
    /// across an escaping `@Sendable` boundary.
    ///
    /// ``Ownership/Transfer/Value/Outgoing`` wraps an existing value in
    /// ARC-managed storage, hands the consumer a Sendable
    /// ``Ownership/Transfer/Value/Outgoing/Token`` (Copyable so it can be
    /// captured in escaping closures), and atomically releases the value
    /// the first time any token copy calls `take()`. Subsequent `take()`
    /// calls trap deterministically.
    ///
    /// ## Ownership Model
    /// - `init(_:)` moves the value into ARC-managed storage.
    /// - `token()` consumes the cell and yields a Sendable token.
    /// - `token.take()` consumes the value (exactly once across all token copies).
    ///
    /// ## Usage
    /// ```swift
    /// let outgoing = Ownership.Transfer.Value<MyType>.Outgoing(myValue)
    /// let token = outgoing.token()
    /// spawnThread {
    ///     let value = token.take()
    ///     // use value
    /// }
    /// ```
    public struct Outgoing: ~Copyable {
        internal let _latch: Ownership.Latch<V>

        /// Creates an outgoing cell containing the given value.
        ///
        /// - Parameter value: The value to store (ownership transferred).
        public init(_ value: consuming V) {
            _latch = Ownership.Latch(value)
        }
    }
}

// MARK: - Operations

extension Ownership.Transfer.Value.Outgoing where V: ~Copyable {
    /// Produces a Sendable token and consumes the cell.
    ///
    /// After calling this method, the cell no longer exists. The token
    /// represents exclusive ownership of the stored value and must be
    /// consumed by calling `take()` exactly once across all token copies.
    ///
    /// - Returns: A Sendable token.
    public consuming func token() -> Token {
        Token(_latch)
    }
}
