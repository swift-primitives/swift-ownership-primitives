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

public import Memory_Primitives

extension Ownership.Transfer {
    /// A move-only Sendable wrapper for transferring retained object ownership
    /// across thread boundaries with zero allocation overhead.
    ///
    /// This type encapsulates the unsafe pointer representation needed to pass a retained
    /// reference across a Sendable boundary (e.g., to an OS thread). The wrapped object
    /// is retained on creation and released when `take()` is called.
    ///
    /// Uses `Unmanaged.passRetained/takeRetainedValue` for explicit ARC management.
    /// For non-class types, use `Ownership.Transfer.Cell` instead.
    ///
    /// ## Usage
    /// ```swift
    /// let retained = Ownership.Transfer.Retained(self)
    /// spawnThread { [retained] in
    ///     let executor = retained.take()
    ///     executor.runLoop()
    /// }
    /// ```
    ///
    /// ## Ownership Model
    /// - `init(_:)` retains the object (+1 retain count)
    /// - Ownership is transferred to exactly one consumer
    /// - `take()` must be called exactly once and consumes `self`
    /// - After `take()`, the caller owns the object and is responsible for its lifetime
    ///
    /// ## Thread Safety
    /// `@unchecked Sendable` because it is an opaque, single-consumption ownership
    /// token. The produced `T` may or may not be safe to use concurrently; that is
    /// a property of `T` and the surrounding program. It is `~Copyable` to enforce
    /// single-consumption at compile time.
    ///
    /// ## Invariant
    /// `take()` must be called exactly once. The `~Copyable` constraint makes
    /// double-take unrepresentable.
    ///
    /// ## Comparison with Ownership.Transfer.Cell
    /// - `Retained`: Zero allocation, `AnyObject` only, direct ARC manipulation
    /// - `Cell`: One allocation (box), any `~Copyable`, atomic state machine
    ///
    /// Use `Retained` when you need zero-overhead class reference passing.
    /// Use `Cell` for general-purpose ownership transfer of any type.
    @safe
    public struct Retained<T: AnyObject>: ~Copyable, @unchecked Sendable {
        /// Opaque bit representation of the retained pointer.
        /// This is NOT a pointer to be manipulated - it is an ownership token
        /// that must be round-tripped back via `take()`.
        @usableFromInline
        let raw: Memory.Mutable.Address

        /// Creates a retained pointer wrapper, incrementing the object's retain count.
        ///
        /// - Parameter instance: The object to retain.
        @inlinable
        @unsafe
        public init(_ instance: T) {
            unsafe (self.raw = Memory.Mutable.Address(Unmanaged.passRetained(instance).toOpaque()))
        }

        /// Takes ownership of the retained object, decrementing the retain count.
        ///
        /// This method consumes `self`, ensuring it can only be called once.
        ///
        /// - Returns: The retained object. The caller now owns this reference.
        @inlinable
        public consuming func take() -> T {
            unsafe Unmanaged<T>.fromOpaque(UnsafeRawPointer(Memory.Address(raw))).takeRetainedValue()
        }
    }
}
