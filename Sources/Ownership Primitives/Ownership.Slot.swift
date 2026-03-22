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

/// State constants for Ownership.Slot state machine.
///
/// Hoisted to module scope due to Swift limitation: static stored properties
/// are not supported in generic types. Refer via `Ownership.Slot.State`.
@usableFromInline
enum __OwnershipSlotState {
    @usableFromInline static let empty: UInt8 = 0
    @usableFromInline static let initializing: UInt8 = 1
    @usableFromInline static let full: UInt8 = 2
}

// MARK: - Slot

extension Ownership {
    /// A reusable heap-allocated slot for storing a single `~Copyable` value.
    ///
    /// Unlike `Ownership.Shared` which holds an immutable value, `Slot` allows
    /// values to be stored and taken repeatedly. This is useful for:
    /// - Resource pools with reusable entries
    /// - Lifetime management patterns
    /// - Any pattern requiring heap storage with move-in/move-out semantics
    ///
    /// The key difference from `Ownership.Transfer`:
    /// - `Transfer`: One-shot (empty → filled → taken, then done)
    /// - `Slot`: Reusable (empty ↔ filled, can cycle indefinitely)
    ///
    /// ## Thread Safety
    ///
    /// All operations are atomic. The slot can be safely shared across threads,
    /// though only one thread will succeed at any given store/take operation.
    ///
    /// ## Totality
    ///
    /// Primary operations return results rather than trapping:
    /// - `store(_:)` returns `Store` indicating success or returning the value
    /// - `take()` returns `Value?`
    ///
    /// Trapping variants are available via `__unchecked` overloads for contexts
    /// where failure indicates a logic error.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let slot = Ownership.Slot<Resource>()
    ///
    /// switch slot.store(resource) {
    /// case .stored:
    ///     print("Resource stored")
    /// case .occupied(let returned):
    ///     print("Slot was full, got resource back")
    /// }
    ///
    /// if let r = slot.take() {
    ///     print("Got resource: \(r)")
    /// }
    /// ```
    @safe
    public final class Slot<Value: ~Copyable & Sendable>: @unchecked Sendable {
        // MARK: - State Machine
        //
        // ## Publication Protocol (release/acquire)
        //
        // Store path:
        //   1. CAS empty → initializing (acquiringAndReleasing) — reserves slot
        //   2. _storage.initialize(to:) — writes non-atomic memory
        //   3. store(State.full, releasing) — publishes; release barrier ensures
        //      initialize happens-before any observer sees .full
        //
        // Take path:
        //   1. CAS full → empty (acquiringAndReleasing) — acquire barrier ensures
        //      we observe all writes that happened-before the release in store
        //   2. _storage.move() — safe because we acquired the publication
        //
        // ## Invariants
        //
        // - State.full implies _storage is initialized and safe to move/deinit
        // - State.initializing is transient; no observer can take until .full
        // - _storage is non-atomic; all access is serialized by state transitions
        //
        // States:
        // - State.empty (0): storage uninitialized
        // - State.initializing (1): exclusive writer reserved; init in progress
        // - State.full (2): storage initialized; may be taken

        /// State constants for the slot state machine.
        @usableFromInline
        typealias State = __OwnershipSlotState

        /// Atomic state for the slot.
        @usableFromInline
        let _state: Atomic<UInt8>

        /// Preallocated storage for the value. Always allocated, even when empty.
        /// This avoids allocation on the hot path (store/take operations).
        @usableFromInline
        let _storage: UnsafeMutablePointer<Value>

        /// Creates an empty slot.
        ///
        /// Storage is preallocated but uninitialized.
        public init() {
            _state = Atomic(State.empty)
            unsafe (_storage = .allocate(capacity: 1))
        }

        /// Creates a slot containing the given value.
        ///
        /// - Parameter value: The value to store (ownership transferred).
        public init(_ value: consuming Value) {
            _state = Atomic(State.initializing)
            unsafe (_storage = .allocate(capacity: 1))
            unsafe _storage.initialize(to: value)
            _state.store(State.full, ordering: .releasing)
        }

        deinit {
            let prior = _state.exchange(State.empty, ordering: .acquiringAndReleasing)
            if prior == State.full {
                unsafe _storage.deinitialize(count: 1)
            }
            // State.initializing at deinit indicates a logic bug (store in progress
            // when object deallocated). In release builds we treat as empty.
            unsafe _storage.deallocate()
        }
    }
}

// MARK: - State Inspection

extension Ownership.Slot {
    /// Whether the slot is empty.
    ///
    /// Note: The intermediate "initializing" state is not considered empty
    /// (a store is in progress), but is also not full (cannot be taken).
    public var isEmpty: Bool {
        _state.load(ordering: .acquiring) == State.empty
    }

    /// Whether the slot contains a value that can be taken.
    public var isFull: Bool {
        _state.load(ordering: .acquiring) == State.full
    }
}
