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

// MARK: - Transfer

extension Ownership {
    /// Namespace for cross-boundary ownership transfer primitives.
    ///
    /// Transfer provides mechanisms for moving values across `@Sendable`
    /// boundaries (e.g., to OS threads, workers, or other contexts) with
    /// exactly-once semantics. The family is organised along two axes:
    ///
    /// | Kind (payload shape) | Outgoing (producer→consumer) | Incoming (consumer slot) |
    /// |----------------------|------------------------------|--------------------------|
    /// | ``Ownership/Transfer/Value`` \<V\> | ``Ownership/Transfer/Value/Outgoing`` | ``Ownership/Transfer/Value/Incoming`` |
    /// | ``Ownership/Transfer/Retained`` \<T\> | ``Ownership/Transfer/Retained/Outgoing`` | ``Ownership/Transfer/Retained/Incoming`` |
    /// | ``Ownership/Transfer/Erased`` | ``Ownership/Transfer/Erased/Outgoing`` | ``Ownership/Transfer/Erased/Incoming`` |
    ///
    /// - **Outgoing** — the producer creates the cell with a value already in
    ///   hand, hands off a Sendable token (or the cell itself), and the
    ///   consumer takes the value on the far side of the boundary.
    /// - **Incoming** — the consumer creates an empty cell on its side, hands
    ///   off a Sendable token to the producer, the producer fills the cell
    ///   through the token, and the consumer reads back after a
    ///   happens-before edge.
    /// - **Value<V>** — any `~Copyable` / `Copyable` value type.
    /// - **Retained<T>** — `AnyObject`; uses direct ARC manipulation via
    ///   `Unmanaged` for a zero-boxed-allocation outgoing path.
    /// - **Erased** — type-erased payload; the producer and consumer agree on
    ///   `T` out of band, and the cell preserves correct destruction on
    ///   abandoned paths.
    ///
    /// ## Safety Guarantees
    /// - All invariant violations trap deterministically (never UB).
    /// - Exactly-once enforcement via atomic state.
    public enum Transfer {}
}

// MARK: - Kind Namespaces

extension Ownership.Transfer {
    /// Value-typed transfer namespace.
    ///
    /// Use ``Ownership/Transfer/Value/Outgoing`` when the producer already
    /// holds the value and wants to hand it across a `@Sendable` boundary.
    /// Use ``Ownership/Transfer/Value/Incoming`` when the consumer creates an
    /// empty slot for the producer to fill later.
    public enum Value<V: ~Copyable> {}

    /// AnyObject transfer namespace.
    ///
    /// Uses direct ARC retain/release via `Unmanaged` so the outgoing
    /// direction needs no heap box at all. The incoming direction uses a
    /// single shared atomic slot (one allocation, no internal payload
    /// pointer indirection).
    public enum Retained<T: AnyObject> {}

    /// Type-erased transfer namespace.
    ///
    /// The payload's concrete type is known to producer and consumer by
    /// agreement; the cell itself stores an opaque box that destructs
    /// correctly even when neither side reaches the unboxing call (for
    /// abandoned paths).
    public enum Erased {}
}
