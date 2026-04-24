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

// MARK: - Retained.Outgoing

extension Ownership.Transfer.Retained {
    /// Outgoing AnyObject transfer — producer already holds a retained class
    /// instance and hands it across a `@Sendable` boundary with zero box
    /// allocation.
    ///
    /// ``Ownership/Transfer/Retained/Outgoing`` wraps the opaque pointer
    /// representation of a `+1` retained reference. The object is retained
    /// on creation and released when `consume()` is called; the `~Copyable`
    /// constraint makes double-consume unrepresentable.
    ///
    /// Uses `Unmanaged.passRetained` / `takeRetainedValue` for explicit ARC
    /// manipulation — no heap allocation beyond the caller's own class
    /// instance. For non-class types, use
    /// ``Ownership/Transfer/Value/Outgoing`` instead.
    ///
    /// ## Usage
    /// ```swift
    /// let outgoing = Ownership.Transfer.Retained<Executor>.Outgoing(self)
    /// spawnThread { [outgoing] in
    ///     let executor = outgoing.consume()
    ///     executor.runLoop()
    /// }
    /// ```
    ///
    /// ## Ownership Model
    /// - `init(_:)` retains the object (+1 retain count).
    /// - `consume()` must be called exactly once; it decrements the unbalanced
    ///   retain and hands the object to the consumer.
    ///
    /// ## Safety Invariant
    ///
    /// `~Copyable` — opaque, single-consumption ownership token. The stored
    /// `raw` is an ARC-retained pointer; `consume()` balances the retain.
    /// Single ownership prevents double-release. `@unsafe @unchecked Sendable`
    /// per [MEM-SAFE-024] Category B (ownership transfer).
    @safe
    public struct Outgoing: ~Copyable, @unsafe @unchecked Sendable {
        /// Opaque bit representation of the retained pointer. This is NOT a
        /// pointer to be manipulated — it is an ownership token that must be
        /// round-tripped back via `consume()`.
        internal let raw: UnsafeMutableRawPointer

        /// Creates an outgoing retained-transfer token, incrementing the
        /// object's retain count.
        ///
        /// - Parameter instance: The object to retain.
        @unsafe
        public init(_ instance: T) {
            unsafe (self.raw = UnsafeMutableRawPointer(Unmanaged.passRetained(instance).toOpaque()))
        }

        /// Creates an outgoing retained-transfer token from an opaque pointer
        /// previously created by `Unmanaged.passRetained(_:).toOpaque()`.
        ///
        /// The pointer MUST represent a `+1` retained reference to `T`. Call
        /// `consume()` exactly once to recover the instance.
        ///
        /// - Parameter ptr: An opaque pointer holding a `+1` retained reference.
        @unsafe
        public init(_ ptr: UnsafeRawPointer) {
            unsafe (self.raw = UnsafeMutableRawPointer(mutating: ptr))
        }
    }
}

// MARK: - Consume

extension Ownership.Transfer.Retained.Outgoing {
    /// Consumes the transfer token and returns ownership of the retained
    /// object, decrementing the unbalanced retain.
    ///
    /// Mirrors SE-0517's `consuming func consume() -> Value` pattern.
    ///
    /// - Returns: The retained object. The caller now owns this reference.
    public consuming func consume() -> T {
        unsafe Unmanaged<T>.fromOpaque(UnsafeRawPointer(raw)).takeRetainedValue()
    }
}
