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

// MARK: - Indirect

extension Ownership {
    /// A heap-allocated copy-on-write value cell.
    ///
    /// `Ownership.Indirect<Value>` wraps a `Copyable` value in heap storage
    /// whose physical copy is lazily deferred until mutation through a shared
    /// reference. Read access yields the stored value without allocation;
    /// write access checks `isKnownUniquelyReferenced(&_storage)` and clones
    /// the storage only if additional copies of the cell exist.
    ///
    /// The name mirrors Swift's `indirect` keyword on recursive enum cases —
    /// both place the value behind one level of heap indirection so identical
    /// conceptual values may share a physical representation. The type does
    /// not clash with the `Copyable` protocol (unlike the rejected
    /// `Ownership.Copyable` spelling).
    ///
    /// ## Example
    ///
    /// ```swift
    /// import Ownership_Primitives
    ///
    /// var a = Ownership.Indirect<[Int]>([1, 2, 3])
    /// var b = a                       // no copy yet — both share storage
    /// b.value.append(4)               // CoW: b's storage is cloned here
    /// // a.value == [1, 2, 3]
    /// // b.value == [1, 2, 3, 4]
    /// ```
    ///
    /// ## CoW vs `clone()`
    ///
    /// Two deep-copy shapes are offered:
    ///
    /// - **Lazy CoW** via `value { _read _modify }`: the copy happens the
    ///   first time a shared cell is mutated. Cheap reads, cheap shared
    ///   copies, cost paid at the moment of mutation.
    /// - **Eager clone** via ``Ownership/Indirect/clone()``: the copy happens
    ///   immediately, independent of sharing. Use when subsequent mutations
    ///   are certain and the CoW branch's runtime check is avoidable, or when
    ///   you want to explicitly decouple a copy from its original.
    ///
    /// ## When to Use
    ///
    /// - Value-semantic heap placement for a `Copyable` value, with shared
    ///   storage until divergent mutation — this type.
    /// - Exclusive single-owner heap cell for a `~Copyable` value — see
    ///   ``Ownership/Unique``.
    /// - Heap-shared immutable value — see ``Ownership/Shared``.
    /// - Heap-shared mutable value (no CoW, reference-identity semantics) —
    ///   see ``Ownership/Mutable``.
    @safe
    public struct Indirect<Value> {

        // MARK: - Storage

        /// Heap storage class. CoW replaces `_storage` when not uniquely
        /// referenced rather than mutating in place through a shared reference.
        @usableFromInline
        final class Storage {
            @usableFromInline
            var value: Value

            @usableFromInline
            init(_ value: consuming Value) {
                self.value = value
            }
        }

        // MARK: - Stored Properties

        @usableFromInline
        internal var _storage: Storage

        // MARK: - Initialization

        /// Creates an `Indirect` cell containing the given value.
        ///
        /// - Parameter initialValue: The value to own (consumed / moved into
        ///   heap storage).
        public init(_ initialValue: consuming Value) {
            _storage = Storage(initialValue)
        }
    }
}

// MARK: - Sendable

extension Ownership.Indirect: @unsafe @unchecked Sendable where Value: Sendable {
    // Safety Invariant: Sendable when Value: Sendable.
    //
    // Per [MEM-SAFE-024] Category D (SP-5: pointer/reference-backed Copyable):
    // `Storage` is a class reference whose `value: Value` is mutated only
    // after `isKnownUniquelyReferenced(&_storage)` has proven the caller has
    // the sole reference. Concurrent `_modify` accesses racing on the same
    // Storage each see a non-unique reference and each clone their own new
    // Storage — correctness preserved, only wasted work on contention. This
    // mirrors the stdlib `Array` / `Dictionary` CoW pattern, which is also
    // `@unchecked Sendable where Element: Sendable`.
}

// MARK: - Primary Accessor

extension Ownership.Indirect {
    /// Direct access to the stored value via yielding coroutines.
    ///
    /// `_read` yields a borrow without allocating. `_modify` first checks
    /// whether the heap storage is uniquely referenced; if not, it copies the
    /// storage before yielding the inout reference — the copy-on-write
    /// discipline.
    ///
    /// ```swift
    /// var indirect = Ownership.Indirect<Counter>(Counter())
    /// let tick = indirect.value.count        // _read — no allocation
    /// indirect.value.increment()             // _modify — CoW if shared
    /// ```
    public var value: Value {
        _read {
            yield _storage.value
        }
        _modify {
            if !isKnownUniquelyReferenced(&_storage) {
                _storage = Storage(_storage.value)
            }
            yield &_storage.value
        }
    }
}

// MARK: - Clone

extension Ownership.Indirect {
    /// Returns an eager deep copy with its own heap storage.
    ///
    /// Unlike the lazy CoW triggered by `_modify`, `clone()` allocates and
    /// copies immediately. The returned `Indirect` shares no storage with
    /// `self` and will not trigger a CoW check on its first mutation.
    ///
    /// Use `clone()` when the caller knows a divergent copy is needed and
    /// wants to pay the allocation cost up front rather than on the first
    /// shared-mutation check.
    public borrowing func clone() -> Ownership.Indirect<Value> {
        Ownership.Indirect(_storage.value)
    }
}
