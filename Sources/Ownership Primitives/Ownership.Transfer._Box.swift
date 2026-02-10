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

import Synchronization

// MARK: - Hoisted State Constants

/// State constants for Ownership.Transfer._Box state machine.
///
/// Hoisted to module scope due to Swift limitation: static stored properties
/// are not supported in generic types. Refer via `Ownership.Transfer._Box.State`.
@usableFromInline
enum __OwnershipTransferBoxState {
    @usableFromInline static let empty: Int = 0
    @usableFromInline static let initializing: Int = 1
    @usableFromInline static let full: Int = 2
    @usableFromInline static let taken: Int = 3
}

// MARK: - _Box

extension Ownership.Transfer {
    /// ARC-managed box for ~Copyable value storage with atomic one-shot enforcement.
    ///
    /// Thread-safe: take() and store() use atomic operations to ensure exactly-once
    /// semantics even if tokens are duplicated (Copyable tokens with Sendable).
    ///
    /// ## State Machine
    ///
    /// Publication invariant: State.full implies storage pointer is non-nil
    /// and initialized, safe to move/deinitialize.
    ///
    /// Intermediate state semantics: State.initializing is transient and must not
    /// be observable as "takeable" or "storable".
    ///
    /// @unchecked Sendable because:
    /// - Atomic operations protect mutable state
    /// - Storage pointer access is serialized by atomic state transitions
    @safe
    @usableFromInline
    internal final class _Box<T: ~Copyable>: @unchecked Sendable {
        // MARK: - State Machine
        //
        // ## Publication Protocol (release/acquire)
        //
        // Store path:
        //   1. CAS empty → initializing (acquiringAndReleasing) — reserves box
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

        /// State constants for the box state machine.
        @usableFromInline
        typealias State = __OwnershipTransferBoxState

        /// Atomic state for the box.
        private let _state: Atomic<Int>

        /// Storage for the value. Access protected by _state transitions.
        /// Non-nil only when state is State.full.
        @usableFromInline
        var _storage: UnsafeMutablePointer<T>?

        /// Creates a box containing a value.
        @usableFromInline
        init(_ value: consuming T) {
            _state = Atomic(State.initializing)
            let p = unsafe UnsafeMutablePointer<T>.allocate(capacity: 1)
            unsafe p.initialize(to: value)
            (_storage = p)
            _state.store(State.full, ordering: .releasing)
        }

        /// Creates an empty box (for Storage pattern).
        @usableFromInline
        init() {
            _state = Atomic(State.empty)
            (_storage = nil)
        }

        /// Atomically stores a value. Traps if already has a value or already taken.
        @usableFromInline
        func store(_ value: consuming T) {
            // Reserve: CAS empty -> initializing
            let (reserved, original) = _state.compareExchange(
                expected: State.empty,
                desired: State.initializing,
                ordering: .acquiringAndReleasing
            )
            if !reserved {
                if original == State.full || original == State.initializing {
                    preconditionFailure("Ownership.Transfer: store() called when value already present")
                } else {
                    preconditionFailure("Ownership.Transfer: store() called after take()")
                }
            }

            // Allocate and initialize
            let p = unsafe UnsafeMutablePointer<T>.allocate(capacity: 1)
            unsafe p.initialize(to: value)
            (_storage = p)

            // Publish: store full (release ensures init is visible to takers)
            _state.store(State.full, ordering: .releasing)
        }

        /// Atomically takes the value. Traps if no value or already taken.
        @usableFromInline
        func take() -> T {
            // CAS full -> taken
            let (exchanged, original) = _state.compareExchange(
                expected: State.full,
                desired: State.taken,
                ordering: .acquiringAndReleasing
            )
            if !exchanged {
                if original == State.empty || original == State.initializing {
                    preconditionFailure("Ownership.Transfer: take() called when no value present")
                } else {
                    preconditionFailure("Ownership.Transfer: take() called twice")
                }
            }

            let p = _storage!
            (_storage = nil)
            let value = unsafe p.move()
            unsafe p.deallocate()
            return value
        }

        /// Atomically takes the value if present, otherwise returns nil.
        @usableFromInline
        func takeIfPresent() -> T? {
            // CAS full -> taken
            let (exchanged, _) = _state.compareExchange(
                expected: State.full,
                desired: State.taken,
                ordering: .acquiringAndReleasing
            )
            guard exchanged else {
                return nil
            }

            let p = _storage!
            (_storage = nil)
            let value = unsafe p.move()
            unsafe p.deallocate()
            return value
        }

        /// Check if a value is present (state is full).
        @usableFromInline
        var hasValue: Bool {
            _state.load(ordering: .acquiring) == State.full
        }

        deinit {
            let state = _state.load(ordering: .acquiring)
            if state == State.full, let p = _storage {
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
