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
    /// A heap-allocated wrapper for an immutable value with shared ownership.
    ///
    /// `Shared` provides reference semantics for value types via ARC, enabling:
    /// - Heap allocation for values that need stable identity
    /// - Breaking recursive type definitions
    /// - Storage for `~Copyable` values that need heap allocation
    ///
    /// ## Ownership Model
    ///
    /// Multiple owners can share the same `Shared` instance via ARC.
    /// The value is immutable (`let`), so sharing is safe.
    ///
    /// ## Sendable
    ///
    /// `Shared` is checked `Sendable` when `Value: Sendable`. The value is
    /// immutable (`let`) and the generic requires `Value: Sendable`, so the
    /// compiler synthesises the conformance structurally — no `@unchecked`
    /// escape hatch needed.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let shared = Ownership.Shared(42)
    /// print(shared.value)  // 42
    /// ```
    @safe
    public final class Shared<Value: ~Copyable & Sendable>: Sendable {
        /// The wrapped value.
        public let value: Value

        /// Creates a shared owner containing the given value.
        @inlinable
        public init(_ value: consuming Value) {
            self.value = value
        }
    }
}
