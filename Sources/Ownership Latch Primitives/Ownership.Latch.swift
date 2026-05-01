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

// MARK: - Hoisted State Constants

/// State constants for Ownership.Latch state machine.
///
/// Hoisted to module scope due to Swift limitation: static stored properties
/// are not supported in generic types. Refer via `Ownership.Latch.State`.
@usableFromInline
enum __OwnershipLatchState {
    @usableFromInline static let empty: Int = 0
    @usableFromInline static let initializing: Int = 1
    @usableFromInline static let full: Int = 2
    @usableFromInline static let taken: Int = 3
}

// MARK: - Latch

extension Ownership {
    /// One-shot atomic cell for ~Copyable value storage with exactly-once semantics.
    ///
    /// `Latch<Value>` is a `final class` holding at most one value across its
    /// lifetime, with an atomic state machine (`empty → initializing → full →
    /// taken`) enforcing exactly-once publication and consumption. Multiple
    /// ARC holders may share the latch, but only one `take()` or
    /// `takeIfPresent()` call succeeds across all holders.
    ///
    /// Unlike ``Slot`` which cycles indefinitely between `empty` and `full`,
    /// `Latch` is terminal after its sole value is taken: subsequent `store()`
    /// and `take()` calls trap. The vocabulary mirrors Java's
    /// `CountDownLatch` — a triggered latch does not reset.
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
    /// let resource = latch.take()
    /// ```
    ///
    /// ## Safety Invariant
    ///
    /// Atomic state machine (`Atomic<Int>` with acquiringAndReleasing CAS) +
    /// release/acquire publication protocol protects storage access.
    /// `@unsafe @unchecked Sendable` per [MEM-SAFE-024] Category A
    /// (synchronized).
    @safe
    public final class Latch<Value: ~Copyable>: @unsafe @unchecked Sendable {
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

        /// State constants for the latch state machine.
        @usableFromInline
        typealias State = __OwnershipLatchState

        /// Atomic state for the latch.
        @usableFromInline
        let _state: Atomic<Int>

        /// Storage for the value. Access protected by _state transitions.
        /// Non-nil only when state is State.full.
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

        /// Atomically stores a value.
        ///
        /// - Parameter value: The value to store (ownership transferred).
        /// - Precondition: The latch must be empty. Traps if a value is already
        ///   present or if the latch has already been taken.
        public func store(_ value: consuming Value) {
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

        /// Atomically takes the value.
        ///
        /// - Returns: The stored value.
        /// - Precondition: The latch must be full. Traps if empty or already
        ///   taken.
        public func take() -> Value {
            // CAS full -> taken
            let (exchanged, original) = _state.compareExchange(
                expected: State.full,
                desired: State.taken,
                ordering: .acquiringAndReleasing
            )
            if !exchanged {
                if original == State.empty || original == State.initializing {
                    preconditionFailure("Ownership.Latch: take() called when no value present")
                } else {
                    preconditionFailure("Ownership.Latch: take() called twice")
                }
            }

            let p = unsafe _storage!
            unsafe (_storage = nil)
            let value = unsafe p.move()
            unsafe p.deallocate()
            return value
        }

        /// Atomically takes the value if present, otherwise returns nil.
        ///
        /// Useful for cleanup paths where the latch may or may not have been
        /// filled.
        ///
        /// - Returns: The stored value if present, otherwise `nil`.
        public func takeIfPresent() -> Value? {
            // CAS full -> taken
            let (exchanged, _) = _state.compareExchange(
                expected: State.full,
                desired: State.taken,
                ordering: .acquiringAndReleasing
            )
            guard exchanged else {
                return nil
            }

            let p = unsafe _storage!
            unsafe (_storage = nil)
            let value = unsafe p.move()
            unsafe p.deallocate()
            return value
        }

        /// Whether the latch currently holds a value that can be taken.
        ///
        /// Returns `false` for an empty latch, during a concurrent `store()`
        /// (transient `initializing` state), and after `take()` has consumed
        /// the value (terminal `taken` state).
        public var hasValue: Bool {
            _state.load(ordering: .acquiring) == State.full
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
