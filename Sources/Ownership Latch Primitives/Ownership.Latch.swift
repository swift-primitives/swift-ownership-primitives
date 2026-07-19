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

public import Synchronization

// MARK: - Latch

extension Ownership {
    /// One-shot atomic cell for ~Copyable value storage with exactly-once semantics.
    ///
    /// `Latch<Value>` is a `final class` holding at most one value across its
    /// lifetime, with an atomic state machine (`empty → initializing → full →
    /// taken`) enforcing exactly-once publication and consumption. Multiple
    /// ARC holders may share the latch, but only one `take()` call returns
    /// `.some(value)` across all holders; subsequent calls return `nil`.
    ///
    /// Unlike ``Slot`` which cycles indefinitely between `empty` and `full`,
    /// `Latch` is terminal after its sole value is taken: a subsequent
    /// `store()` traps, and subsequent `take()` calls return `nil`. The
    /// vocabulary mirrors Java's `CountDownLatch` — a triggered latch does
    /// not reset.
    ///
    /// ## Thread Safety
    ///
    /// All operations are atomic. The latch can be safely shared across
    /// threads: publication uses release-acquire semantics so any thread
    /// observing `.full` sees the write from `initialize(to:)` that preceded
    /// it on the producing thread.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let latch = Ownership.Latch<Resource>()
    ///
    /// // Producer
    /// latch.store(resource)
    ///
    /// // Consumer (later, on any thread)
    /// if let resource = latch.take() {
    ///     use(resource)
    /// }
    /// ```
    ///
    /// ## Safety Invariant
    ///
    /// Atomic state machine (`Atomic<Int>` with acquiringAndReleasing CAS) +
    /// release/acquire publication protocol protects storage access.
    /// `@unchecked Sendable` per [MEM-SAFE-024] Category A
    /// (synchronized). `store(_:)` takes and `take()` returns `sending
    /// Value`: the compiler verifies the handed-off value has no other live
    /// uses at the hand-off point, which is what makes the unconditional
    /// `@unchecked Sendable` conformance sound for non-Sendable `Value`
    /// types per the SE-0433 pattern — the synchronized state machine alone
    /// only protects `_storage`'s memory, not an aliased reference the
    /// caller kept and continued using concurrently.
    @safe
    public final class Latch<Value: ~Copyable>: @unchecked Sendable {
        // MARK: - State Machine
        //
        // ## Publication Protocol (release/acquire)
        //
        // Store path:
        //   1. CAS empty → initializing (acquiringAndReleasing) — reserves latch
        //   2. allocate + initialize _storage — writes non-atomic memory
        //   3. store(State.full, releasing) — publishes; release barrier ensures
        //      allocation/init happens-before any observer sees .full
        //
        // Take path:
        //   1. CAS full → taken (acquiringAndReleasing) — acquire barrier ensures
        //      we observe all writes that happened-before the release in store
        //   2. _storage!.move() + deallocate — safe because we acquired publication
        //
        // ## Invariants
        //
        // - State.full implies _storage is non-nil, allocated, and initialized
        // - State.initializing is transient; no observer can take until .full
        // - State.taken is terminal; no further operations allowed
        // - _storage is non-atomic; all access is serialized by state transitions
        //
        // States:
        // - State.empty (0): no storage allocated
        // - State.initializing (1): exclusive writer reserved; allocation/init in progress
        // - State.full (2): storage allocated and initialized; may be taken
        // - State.taken (3): value was consumed; terminal state

        /// Atomic state for the latch.
        @usableFromInline
        let _state: Atomic<Int>

        /// Storage for the value.
        ///
        /// Access protected by `_state` transitions. Non-nil only when
        /// state is `State.full`.
        @usableFromInline
        var _storage: UnsafeMutablePointer<Value>?

        /// Creates a latch containing a value.
        ///
        /// - Parameter value: The value to store (ownership transferred).
        public init(_ value: consuming Value) {
            _state = Atomic(State.initializing)
            let p = UnsafeMutablePointer<Value>.allocate(capacity: 1)
            unsafe p.initialize(to: value)
            unsafe (_storage = p)
            _state.store(State.full, ordering: .releasing)
        }

        /// Creates an empty latch.
        public init() {
            _state = Atomic(State.empty)
            unsafe (_storage = nil)
        }

        deinit {
            let state = _state.load(ordering: .acquiring)
            if state == State.full, let p = unsafe _storage {
                // Value was never taken - clean up to avoid memory leak
                unsafe p.deinitialize(count: 1)
                unsafe p.deallocate()
            }
            // State.initializing at deinit indicates a logic bug (store in progress
            // when object deallocated). In release builds we ignore.
            // State.taken or State.empty: nothing to clean up.
        }
    }
}

// MARK: - State Typealias

extension Ownership.Latch where Value: ~Copyable {
    /// State constants for the latch state machine.
    @usableFromInline
    typealias State = __OwnershipLatchState
}

// MARK: - Store

extension Ownership.Latch where Value: ~Copyable {
    /// Atomically stores a value.
    ///
    /// - Parameter value: The value to store (ownership transferred).
    /// - Precondition: The latch must be empty. Traps if a value is already
    ///   present or if the latch has already been taken.
    public func store(_ value: consuming sending Value) {
        // Reserve: CAS empty -> initializing
        let (reserved, original) = _state.compareExchange(
            expected: State.empty,
            desired: State.initializing,
            ordering: .acquiringAndReleasing
        )
        if !reserved {
            if original == State.full || original == State.initializing {
                preconditionFailure("Ownership.Latch: store() called when value already present")
            } else {
                preconditionFailure("Ownership.Latch: store() called after take()")
            }
        }

        // Allocate and initialize
        let p = UnsafeMutablePointer<Value>.allocate(capacity: 1)
        unsafe p.initialize(to: value)
        unsafe (_storage = p)

        // Publish: store full (release ensures init is visible to takers)
        _state.store(State.full, ordering: .releasing)
    }
}

// MARK: - Take

extension Ownership.Latch where Value: ~Copyable {
    /// Atomically takes the stored value.
    ///
    /// At most one call across all ARC holders returns `.some(value)`;
    /// subsequent calls (and calls on a never-filled latch) return `nil`.
    ///
    /// - Returns: The stored value, or `nil` if the latch is empty or has
    ///   already been taken.
    public func take() -> sending Value? {
        // CAS full -> taken
        let (exchanged, _) = _state.compareExchange(
            expected: State.full,
            desired: State.taken,
            ordering: .acquiringAndReleasing
        )
        guard exchanged else {
            return nil
        }

        // Invariant: state-CAS full→taken succeeded ⇒ _storage non-nil.
        guard let p = unsafe _storage else {
            preconditionFailure("Ownership.Latch: state-CAS succeeded but _storage was nil — protocol violation")
        }
        unsafe (_storage = nil)
        let value = unsafe p.move()
        unsafe p.deallocate()
        return value
    }
}

// MARK: - State Inspection

extension Ownership.Latch where Value: ~Copyable {
    /// Whether the latch currently holds a value that can be taken.
    ///
    /// Returns `false` for an empty latch, during a concurrent `store()`
    /// (transient `initializing` state), and after `take()` has consumed
    /// the value (terminal `taken` state).
    public var hasValue: Bool {
        _state.load(ordering: .acquiring) == State.full
    }
}
