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

extension Ownership.Box where Value: ~Copyable {
    // WHY: Category D (SP-5) — `Storage` reaches its payload through an
    // WHY: `UnsafeMutablePointer`; the pointer is `Storage`-owned for the cell's
    // WHY: whole life, projected only through the addressor below, and mutated
    // WHY: only on uniqueness-restored paths. See [MEM-SAFE-024], [MEM-SAFE-028].
    /// The refcounted heap cell behind ``Ownership/Box`` — the single audited home for the
    /// drain-box rule ([MEM-SAFE-028]) and the cell's copy-on-write teardown discipline.
    ///
    /// ## The drain-box rule ([MEM-SAFE-028], binding)
    ///
    /// `Storage` holds its payload OUT OF LINE behind its own allocation (a `let` pointer field),
    /// and its `deinit` OWNS payload teardown: it drains the payload through the strategy captured
    /// at construction, then closes with `_fixLifetime(self)` — the stdlib `_ContiguousArrayStorage`
    /// idiom. It MUST NOT rely on the payload's own deinit oracle running during automatic field
    /// destruction: on Swift 6.3.x under `-O`, once `isKnownUniquelyReferenced` has been applied to
    /// the cell, the devirtualized destroy of a generic-namespace-NESTED `~Copyable` payload OMITS
    /// the user deinit while still freeing its fields — elements leak, bytes are freed. With the
    /// drain, the payload oracle behind the cell tears down an already-empty payload (count-driven),
    /// so correctness no longer depends on whether the compiler runs it, converging with the stdlib
    /// factoring. The drain is a stored `@Sendable` closure so `Storage` stays payload-agnostic;
    /// each construction site supplies the strategy its payload needs.
    ///
    /// Durable repro: `swift-institute/Experiments/cow-box-deinit-omission-miscompile` (CONFIRMED,
    /// still live on Swift 6.3.3). The drain is time-boxed to that miscompile being fixed upstream;
    /// it remains correct (and stdlib-convergent) thereafter.
    @safe
    @usableFromInline
    internal final class Storage {

        /// The payload, OUT OF LINE behind the cell's own allocation: a `let` pointer field carries
        /// no class-field exclusivity bookkeeping and exits the struct-in-class-field deinit-omission
        /// miscompile shape — teardown is the explicit drain + pointer deinitialize below.
        @usableFromInline
        internal let _payload: UnsafeMutablePointer<Value>

        /// Address-projected access to the payload (no copies, no class-field exclusivity; the
        /// borrow / mutation scope is the enclosing access of the projected address — the stdlib
        /// addressor discipline).
        @usableFromInline
        internal var value: Value {
            unsafeAddress { unsafe UnsafePointer(_payload) }
            unsafeMutableAddress { unsafe _payload }
        }

        /// The payload teardown strategy, captured at construction (the drain-box rule).
        @usableFromInline
        internal let _drain: @Sendable (inout Value) -> Void

        /// The payload deep-copy strategy.
        ///
        /// `nil` on statically-unique payloads (`~Copyable` payloads
        /// cannot be duplicated, so uniqueness never needs restoring); non-`nil` whenever the payload
        /// is `Copyable` and the cell can become shared: `ensureUnique()` clones through it.
        @usableFromInline
        internal let _clone: (@Sendable (borrowing Value) -> Value)?

        @usableFromInline
        internal init(
            _ value: consuming Value,
            drain: @escaping @Sendable (inout Value) -> Void,
            clone: (@Sendable (borrowing Value) -> Value)? = nil
        ) {
            let payload = UnsafeMutablePointer<Value>.allocate(capacity: 1)
            unsafe payload.initialize(to: value)
            unsafe (self._payload = payload)
            self._drain = drain
            self._clone = clone
        }

        deinit {
            _drain(&value)
            unsafe _payload.deinitialize(count: 1)
            unsafe _payload.deallocate()
            _fixLifetime(self)
        }
    }
}
