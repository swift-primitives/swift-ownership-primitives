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

extension Ownership.Mutable where Value: ~Copyable {
    /// An unchecked-Sendable wrapper for `Mutable` that allows crossing
    /// concurrency boundaries with any value.
    ///
    /// ## Safety Invariant
    ///
    /// **This type bypasses the compiler's Sendable checking.** The caller
    /// promises external synchronization; the wrapper adds no runtime check.
    /// Concurrent mutation WILL cause data races with no runtime trap and
    /// silent corruption.
    ///
    /// - Single-consumer only — do not capture in multiple concurrent tasks.
    /// - NOT thread-safe — external synchronization (lock, actor, atomic) is
    ///   the caller's responsibility.
    ///
    /// ## Intended Use
    ///
    /// - Boxing non-Sendable async iterators for capture in `@Sendable` closures.
    /// - Single-writer patterns where the writer is the only accessor.
    /// - Actor-confined usage where the wrapper never escapes the actor.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // CORRECT: Single consumer
    /// let box = Ownership.Mutable.Unchecked(asyncIterator)
    /// Task {
    ///     while let value = await box.mutable.value.next() {
    ///         process(value)
    ///     }
    /// }
    ///
    /// // INCORRECT: Multiple consumers — DATA RACE
    /// let box = Ownership.Mutable.Unchecked(asyncIterator)
    /// Task { await box.mutable.value.next() }  // Race!
    /// Task { await box.mutable.value.next() }  // Race!
    /// ```
    public struct Unchecked: @unsafe @unchecked Sendable {
        /// The wrapped `Mutable` instance.
        public let mutable: Ownership.Mutable<Value>

        /// Creates an unchecked-Sendable wrapper containing the given value.
        @inlinable
        public init(_ value: consuming Value) {
            self.mutable = Ownership.Mutable(value)
        }
    }
}
