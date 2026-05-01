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
    /// ## Access
    ///
    /// Access goes through the `value` accessor, which yields a borrow on
    /// read and an `inout` reference on mutation:
    ///
    /// ```swift
    /// let mutable = Ownership.Mutable(42)
    /// print(mutable.value)          // _read coroutine: borrowed access
    /// mutable.value += 1            // _modify coroutine: in-place mutation
    /// ```
    ///
    /// For `~Copyable` values, transitive borrow through `value` is the
    /// only legal read path — the coroutine yields a borrow that cannot
    /// be stored past the access expression.
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
    /// would allow concurrent mutation without protection — a data race.
    ///
    /// For use cases requiring capture of values in `@Sendable` closures (e.g., async
    /// iterator boxing), use ``Unchecked`` instead. This is an explicit opt-in to
    /// bypass Sendable checking — you take responsibility for ensuring single-consumer
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

        /// Creates a mutable owner containing the given value.
        @inlinable
        public init(_ value: consuming Value) {
            self._value = value
        }
    }
}

// MARK: - Value Access

extension Ownership.Mutable where Value: ~Copyable {
    /// Direct access to the wrapped value via yielding `_read` / `_modify`
    /// coroutines.
    ///
    /// `_read` yields a borrow; `_modify` yields an inout reference.
    /// Pre-SE-0507 rendering of `var value: Value { borrow mutate }`.
    @inlinable
    public var value: Value {
        _read { yield _value }
        _modify { yield &_value }
    }
}

// Mutable is intentionally NOT Sendable.
// Use Ownership.Mutable.Unchecked for explicit opt-in to cross-isolation transfer.
