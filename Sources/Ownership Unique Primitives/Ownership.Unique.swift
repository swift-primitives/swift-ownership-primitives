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

// MARK: - Ownership.Unique

extension Ownership {
    /// A heap-owned, exclusively-owned single-value cell.
    ///
    /// `Ownership.Unique<Value>` owns one heap-allocated value. The cell is
    /// `~Copyable` — copies are forbidden — so the owner is guaranteed to be
    /// unique at every point in the value's lifetime. On destruction, either
    /// through `consume()` or normal scope-exit, the value is deinitialised
    /// and the heap storage is deallocated.
    ///
    /// Institute rendering of Apple stdlib's `Swift.UniqueBox<Value: ~Copyable>`
    /// (SE-0517, accepted March 2026). The compound-form `UniqueBox` name is
    /// rendered here as the Nest.Name form `Ownership.Unique` per [API-NAME-001];
    /// semantics and API surface mirror SE-0517.
    ///
    /// ## When to Use
    ///
    /// - Heap placement of a `~Copyable` value with deterministic cleanup: this type.
    /// - Shared immutable heap reference: ``Ownership/Shared``.
    /// - Shared mutable heap reference (intra-isolation): ``Ownership/Mutable``.
    /// - One-shot cross-boundary transfer: ``Ownership/Transfer``.
    ///
    /// ## Sendable
    ///
    /// `Ownership.Unique` is `@unsafe @unchecked Sendable` when
    /// `Value: ~Copyable & Sendable`. The `@unchecked` is required because
    /// the stored `UnsafeMutablePointer<Value>` is non-Sendable by stdlib
    /// `@unsafe` conformance. The exclusive-ownership contract (enforced
    /// by the `~Copyable` wrapper) plus Value's own Sendable guarantee make
    /// the concrete type safe to transfer — only one thread can hold a
    /// `Ownership.Unique<Value>` at a time — so the conformance is sound.
    ///
    /// ## Semantics vs. `Optional<Unique<Value>>`
    ///
    /// An `Ownership.Unique` instance always holds a value while it exists.
    /// There is no observable "empty" state. Callers who need optional
    /// ownership should use `Ownership.Unique<Value>?`. This matches
    /// SE-0517's explicit design choice — empty state is rejected — and
    /// eliminates the class of bugs from re-observing a taken cell.
    @safe
    public struct Unique<Value: ~Copyable>: ~Copyable {

        // MARK: - Stored Properties

        /// Heap-allocated pointer to the value. Always initialised while the
        /// owner exists; `consume()` and `deinit` are the only exits.
        @usableFromInline
        internal let _storage: UnsafeMutablePointer<Value>

        // MARK: - Initialization

        /// Creates a unique heap-owner by allocating storage and moving
        /// `initialValue` into it.
        ///
        /// - Parameter initialValue: The value to own (consumed / moved).
        @inlinable
        public init(_ initialValue: consuming Value) {
            let storage = UnsafeMutablePointer<Value>.allocate(capacity: 1)
            unsafe storage.initialize(to: initialValue)
            unsafe (self._storage = storage)
        }

        deinit {
            unsafe _storage.deinitialize(count: 1)
            unsafe _storage.deallocate()
        }
    }
}

// MARK: - Sendable

extension Ownership.Unique: @unsafe @unchecked Sendable where Value: ~Copyable & Sendable {}

// MARK: - Primary Accessor

extension Ownership.Unique where Value: ~Copyable {
    /// Direct access to the owned value via yielding `_read` / `_modify`
    /// coroutines.
    ///
    /// `_read` yields a borrow; `_modify` yields an inout reference.
    /// Pre-SE-0507 rendering of SE-0517's `var value: Value { borrow mutate }`.
    ///
    /// Read access:
    /// ```swift
    /// let box = Ownership.Unique<Resource>(resource)
    /// let id = box.value.id           // transitive borrow
    /// print(box.value)                // borrowed print
    /// ```
    ///
    /// Mutation:
    /// ```swift
    /// var box = Ownership.Unique<Counter>(Counter())
    /// box.value.increment()           // _modify coroutine
    /// ```
    @inlinable
    public var value: Value {
        _read { yield unsafe _storage.pointee }
        _modify { yield unsafe &_storage.pointee }
    }
}

// MARK: - Consume

extension Ownership.Unique where Value: ~Copyable {
    /// Consumes the cell, destroying it and returning its value.
    ///
    /// After `consume()` returns, the cell no longer exists. Attempting to
    /// reference the consumed cell is a compile-time error. This mirrors
    /// SE-0517's `consuming func consume() -> Value` exactly.
    ///
    /// ```swift
    /// let box = Ownership.Unique<Resource>(resource)
    /// let extracted = box.consume()    // box no longer exists
    /// use(extracted)
    /// ```
    ///
    /// - Returns: The owned value.
    public consuming func consume() -> Value {
        let value = unsafe _storage.move()
        unsafe _storage.deallocate()
        discard self
        return value
    }
}

// MARK: - Span Access

extension Ownership.Unique where Value: ~Copyable {
    /// A read-only `~Escapable` view over the owned value's storage.
    ///
    /// `Span<Value>` has `count == 1` — a single-element contiguous view
    /// over the heap-allocated cell. Useful for interop with stdlib APIs
    /// expecting contiguous-memory spans.
    ///
    /// Mirrors SE-0517's `var span: Span<Value> { get }`.
    @inlinable
    public var span: Span<Value> {
        @_lifetime(borrow self)
        borrowing get {
            unsafe Span(_unsafeStart: _storage, count: 1)
        }
    }

    /// A mutable `~Escapable` view over the owned value's storage.
    ///
    /// `MutableSpan<Value>` has `count == 1` — a single-element mutable
    /// contiguous view over the heap-allocated cell.
    ///
    /// Mirrors SE-0517's `var mutableSpan: MutableSpan<Value> { mutating get }`.
    @inlinable
    public var mutableSpan: MutableSpan<Value> {
        @_lifetime(&self)
        mutating get {
            unsafe MutableSpan(_unsafeStart: _storage, count: 1)
        }
    }
}
