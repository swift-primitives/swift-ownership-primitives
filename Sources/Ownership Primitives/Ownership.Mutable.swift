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

extension Ownership {
    /// A heap-allocated wrapper enabling recursive value types and shared mutable state.
    ///
    /// `Mutable` boxes a value (including `~Copyable` types) in a reference type,
    /// enabling:
    /// - Breaking infinite-size cycles in recursive struct/enum definitions
    /// - Multiple owners sharing access to the same underlying storage
    /// - Heap allocation for values that need stable identity
    ///
    /// ## Access Patterns
    ///
    /// For `Copyable` values, direct property access is available:
    /// ```swift
    /// let mutable = Ownership.Mutable(42)
    /// mutable.value += 1
    /// ```
    ///
    /// For `~Copyable` values or when scoped access is preferred, use closures:
    /// ```swift
    /// mutable.withValue { print($0) }
    /// mutable.update { $0 += 1 }
    /// ```
    ///
    /// ## Thread Safety
    ///
    /// `Mutable` itself provides no synchronization. If the boxed value needs
    /// thread-safe access, wrap a synchronized type (e.g., `Mutex`).
    ///
    /// ## Sendable
    ///
    /// `Mutable` is **not** `Sendable` by design. It is an identity-sharing mutable
    /// reference wrapper without synchronization. Sending it across isolation domains
    /// would allow concurrent mutation without protection—a data race.
    ///
    /// For use cases requiring capture of values in `@Sendable` closures (e.g., async
    /// iterator boxing), use ``Unchecked`` instead. This is an explicit opt-in to
    /// bypass Sendable checking—you take responsibility for ensuring single-consumer
    /// or externally-synchronized access.
    ///
    /// **Policy:** No general-purpose mutable reference wrapper in this module is
    /// `Sendable` unless it provides synchronization or actor isolation by construction.
    ///
    /// ## Example
    ///
    /// ```swift
    /// struct TreeNode {
    ///     var value: Int
    ///     var children: [Ownership.Mutable<TreeNode>]
    /// }
    /// ```
    @safe
    public final class Mutable<Value: ~Copyable> {
        /// The wrapped value.
        @usableFromInline
        var _value: Value

        /// Direct access to the wrapped value.
        ///
        /// For `~Copyable` types, prefer `withValue(_:)` or `update(_:)` for
        /// safer scoped access.
        @inlinable
        public var value: Value {
            _read { yield _value }
            _modify { yield &_value }
        }

        /// Creates a mutable owner containing the given value.
        @inlinable
        public init(_ value: consuming Value) {
            self._value = value
        }

        /// Accesses the value for reading.
        ///
        /// - Parameter body: A closure that receives the value.
        /// - Returns: The result of the closure.
        /// - Throws: Rethrows any error thrown by the closure, preserving the exact error type.
        @inlinable
        public func withValue<Result, E: Error>(
            _ body: (borrowing Value) throws(E) -> Result
        ) throws(E) -> Result {
            try body(_value)
        }

        /// Accesses the value for mutation.
        ///
        /// - Parameter body: A closure that receives an inout reference to the value.
        /// - Returns: The result of the closure.
        /// - Throws: Rethrows any error thrown by the closure, preserving the exact error type.
        @inlinable
        public func update<Result, E: Error>(
            _ body: (inout Value) throws(E) -> Result
        ) throws(E) -> Result {
            try body(&_value)
        }
    }
}

// Mutable is intentionally NOT Sendable.
// Use Ownership.Mutable.Unchecked for explicit opt-in to cross-isolation transfer.
