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

// MARK: - Ownership.Box

extension Ownership {
    /// A heap-allocated copy-on-write cell — the single copy-on-write box of the ownership layer.
    ///
    /// `Ownership.Box<Value>` wraps a value in a refcounted heap cell whose physical copy is
    /// deferred until mutation through a shared reference (copy-on-write). The box is a Copyable
    /// reference: copying it shares the cell (ARC retain), never copying the payload. Mutation
    /// restores uniqueness first via the injected `clone` strategy; with no clone strategy
    /// (`clone == nil`) a shared cell cannot restore uniqueness, so clone-less cells are used only
    /// where the wrapper keeps them statically unique (e.g. a move-only-element column), and the
    /// uniqueness gate is a proven no-op there.
    ///
    /// `Box` is the copy-on-write sibling of ``Ownership/Unique`` (the exclusive `~Copyable`
    /// cell), mirroring Apple's `Swift.Box` / `Swift.UniqueBox` split — SE-0517 reserves bare
    /// `Box` for exactly this copy-on-write variant.
    ///
    /// ## Witnesses keep the cell payload-generic
    ///
    /// Teardown (`drain`) and deep-copy (`clone`) strategies are injected at construction, so the
    /// cell learns no element, index, or collection vocabulary. The `Copyable` convenience
    /// initializer supplies whole-value defaults; payload-specific cells (e.g. buffer columns)
    /// supply their own. `clone == nil` ⟺ statically unique ⟹ the gate is a proven no-op ⟹
    /// move-only for free.
    ///
    /// ## Example
    ///
    /// ```swift
    /// import Ownership_Primitives
    ///
    /// var a = Ownership.Box<[Int]>([1, 2, 3])
    /// var b = a                       // no copy yet — both share the cell
    /// b.value.append(4)               // copy-on-write: b's cell is cloned here
    /// // a.value == [1, 2, 3]
    /// // b.value == [1, 2, 3, 4]
    /// ```
    ///
    /// ## Lazy copy-on-write vs eager `clone()`
    ///
    /// - **Lazy** via `value`'s `_modify`: the copy happens the first time a shared cell is
    ///   mutated. Cheap reads, cheap shared copies, cost paid at the moment of mutation.
    /// - **Eager** via ``clone()``: the copy happens immediately, independent of sharing.
    ///
    /// ## When to Use
    ///
    /// - Value-semantic heap placement with shared storage until divergent mutation — this type.
    /// - Exclusive single-owner heap cell for a `~Copyable` value — see ``Ownership/Unique``.
    /// - Heap-shared immutable value — see ``Ownership/Shared``.
    /// - Heap-shared mutable value (no copy-on-write, reference-identity) — see ``Ownership/Mutable``.
    @frozen
    public struct Box<Value: ~Copyable> {

        // MARK: - Stored Properties

        @usableFromInline
        internal var storage: Storage

        // MARK: - Initialization

        /// Creates a copy-on-write cell with explicit teardown (`drain`) and deep-copy (`clone`)
        /// strategies.
        ///
        /// - Parameters:
        ///   - value: The value to own (consumed / moved into heap storage).
        ///   - drain: The payload teardown strategy (the drain-box rule, [MEM-SAFE-028]).
        ///   - clone: The payload deep-copy strategy, or `nil` for a statically-unique (move-only)
        ///     payload — a payload whose cell can never become shared.
        @inlinable
        public init(
            _ value: consuming Value,
            drain: @escaping @Sendable (inout Value) -> Void,
            clone: (@Sendable (borrowing Value) -> Value)? = nil
        ) {
            self.storage = Storage(value, drain: drain, clone: clone)
        }

        @usableFromInline
        internal init(storage: consuming Storage) {
            self.storage = storage
        }
    }
}

// MARK: - Copyability
//
// `Ownership.Box` is UNCONDITIONALLY `Copyable`: copying the box copies its `Storage` class
// reference (ARC retain), so two boxes share one heap cell — the refcounted-reference role the
// column adapter requires. `Shared<Element, B>` stores `Ownership.Box<B>` (with `B` move-only) and
// gates ITS OWN copyability on `Element`, exactly as the prior `final class Box` did. Copying never
// copies the payload `Value` (it lives behind the cell's pointer); a `~Copyable` payload is shared
// by reference and torn down once. The struct carries no `deinit` — the cell's `Storage` owns
// teardown at the class boundary ([MEM-COPY-016]) — so SE-0427 is satisfied.

// MARK: - Sendable

/// The single audited home for the cell's `@unchecked Sendable` contract ([MEM-SAFE-024]).
// WHY: Category D (SP-5) — `Storage` carries mutable payload state behind an
// WHY: `UnsafeMutablePointer` the compiler cannot prove Sendable. Soundness is the
// WHY: copy-on-write discipline AROUND the cell: every safe mutation restores uniqueness
// WHY: before writing (`value`'s `_modify` / `ensureUnique()`) — a shared cell is detached
// WHY: onto a fresh backing before it is mutated, so it is never mutated while shared.
// WHY: Clone-less cells (`~Copyable`-element columns) are kept statically unique by their
// WHY: wrapper, so the gate is a no-op there. The sole unchecked lane is `unguarded`, whose
// WHY: name states the caller's obligation. Both witnesses are `@Sendable` by stored type.
// WHY: See [MEM-SAFE-028].
extension Ownership.Box: @unchecked Sendable where Value: Sendable & ~Copyable {}

// MARK: - Convenience Construction (Copyable payloads)

extension Ownership.Box where Value: Copyable {
    /// Creates a copy-on-write cell holding a `Copyable` value, with whole-value copy as the deep-
    /// copy strategy and a no-op drain (the payload's own teardown runs on deallocation).
    @inlinable
    public init(_ value: consuming Value) {
        self.init(value, drain: { _ in }, clone: { $0 })
    }
}

// MARK: - Uniqueness

extension Ownership.Box where Value: ~Copyable {
    /// Whether this cell holds the only reference to its backing.
    @inlinable
    public var isUnique: Bool {
        mutating get { isKnownUniquelyReferenced(&storage) }
    }

    /// Restores unique ownership, installing a deep copy of the payload when the backing is shared.
    ///
    /// A no-op on statically-unique (move-only) payloads — those cells can never be shared. Call
    /// before mutating through ``unguarded`` for copy-on-write correctness.
    ///
    /// - Returns: `true` iff a copy was made to restore uniqueness.
    @inlinable
    @discardableResult
    public mutating func ensureUnique() -> Bool {
        guard !isKnownUniquelyReferenced(&storage) else { return false }
        guard let clone = storage._clone else {
            // A clone-less cell that is nonetheless shared cannot restore uniqueness, so this traps
            // cleanly. It does not fire in practice: the box is unconditionally Copyable, so a
            // clone-less cell CAN be shared in principle, but the consolidation's `~Copyable`-element
            // wrappers (`Shared` / `Unique`) keep such cells statically unique
            // ([MEM-COPY-017] / [MEM-COPY-019]).
            preconditionFailure("Ownership.Box backing is shared but carries no clone strategy")
        }
        storage = Storage(clone(storage.value), drain: storage._drain, clone: storage._clone)
        return true
    }
}

// MARK: - Access

extension Ownership.Box where Value: ~Copyable {
    /// The stored value. Reads borrow without allocating; mutation restores unique ownership first
    /// (copy-on-write). The safe, default accessor.
    @inlinable
    public var value: Value {
        _read { yield storage.value }
        _modify {
            ensureUnique()
            yield &storage.value
        }
    }

    /// Address-projected access that does NOT restore uniqueness — the unchecked lane for callers
    /// who have already established uniqueness (gate once with ``ensureUnique()``, then run a hot
    /// batch). Mutating a shared backing through this accessor mutates shared state; the caller
    /// owns the uniqueness obligation (assert ``isUnique`` in debug at the call site).
    @inlinable
    public var unguarded: Value {
        unsafeAddress { unsafe UnsafePointer(storage._payload) }
        unsafeMutableAddress { unsafe storage._payload }
    }

    /// Identity of the current backing — copy-on-write divergence is observable here.
    @inlinable
    public var identity: ObjectIdentifier {
        ObjectIdentifier(storage)
    }
}

// MARK: - Clone

extension Ownership.Box where Value: Copyable {
    /// Returns an eager independent copy with its own backing.
    ///
    /// Unlike the lazy copy-on-write triggered by mutation, `clone()` copies immediately and shares
    /// no backing with `self` — the returned cell will not trigger a uniqueness check on its first
    /// mutation.
    @inlinable
    public borrowing func clone() -> Ownership.Box<Value> {
        Ownership.Box(storage: Storage(storage.value, drain: storage._drain, clone: storage._clone))
    }
}
