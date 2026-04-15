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
    /// - Type erasure via `Unmanaged` + `UnsafeRawPointer`
    /// - Breaking recursive type definitions
    /// - Storage for `~Copyable` types that need heap allocation
    ///
    /// ## Ownership Model
    ///
    /// Multiple owners can share the same `Shared` instance via ARC.
    /// The value is immutable (`let`), so sharing is safe.
    ///
    /// ## Sendable
    ///
    /// `Shared` is `Sendable` when `Value: Sendable`. The value is immutable (`let`),
    /// so sharing across isolation domains is safe.
    ///
    /// **Note:** This type uses `@unchecked Sendable` due to a Swift compiler
    /// limitation where `~Copyable` generic parameters in class stored properties
    /// prevent checked `Sendable` conformance inference. The type is structurally
    /// safe: the stored `value` is immutable and requires `Value: Sendable`.
    /// When this compiler limitation is resolved, this should be converted to
    /// checked `Sendable` conformance.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let shared = Ownership.Shared(42)
    /// print(shared.value)  // 42
    /// ```
    @safe
    /// ## Safety Invariant
    ///
    /// `Ownership.Shared` holds an immutable `let value: Value` where
    /// `Value: Sendable`. The value cannot be mutated after construction.
    /// `~Copyable` generic in class storage blocks structural Sendable inference.
    ///
    /// ## Intended Use
    ///
    /// - Sharing an immutable value across multiple owners.
    ///
    /// ## Non-Goals
    ///
    /// - Does not support mutation after construction.
    public final class Shared<Value: ~Copyable & Sendable>: @unsafe @unchecked Sendable {
        /// The wrapped value.
        public let value: Value

        /// Creates a shared owner containing the given value.
        @inlinable
        public init(_ value: consuming Value) {
            self.value = value
        }
    }
}
