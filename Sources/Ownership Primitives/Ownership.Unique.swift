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

import Memory_Primitives
public import Identity_Primitives
import Index_Primitives

// MARK: - Ownership.Unique

extension Ownership {
    /// A unique-ownership heap box with deterministic deinitialization.
    ///
    /// `Unique` allocates and owns a single value on the heap, automatically
    /// deallocating when destroyed. This is the Swift equivalent of Rust's `Box<T>`.
    ///
    /// ## Invariants
    ///
    /// - Storage is non-null while owned (nil only after `take()`)
    /// - Memory is initialized while owned
    /// - `deinit` deallocates if still owned
    ///
    /// ## When to Use
    ///
    /// - Need unique ownership with deterministic cleanup: `Ownership.Unique`
    /// - Need shared immutable reference: `Ownership.Shared`
    /// - Need shared mutable reference: `Ownership.Mutable`
    ///
    /// ## ~Copyable
    ///
    /// `Unique` is always `~Copyable` to prevent accidental heap allocations.
    /// For `Copyable` values, use `duplicated()` for explicit deep copy.
    ///
    /// ## Sendable
    ///
    /// `Unique` is `Sendable` when `Value: Sendable`. If you need to transfer
    /// a non-Sendable value across isolation boundaries, use `Ownership.Transfer`.
    @safe
    public struct Unique<Value: ~Copyable>: ~Copyable {

        // MARK: - Stored Properties

        /// Internal pointer storage. Nil after `take()` or `leak()`.
        @usableFromInline
        internal var _storage: Pointer<Value>.Mutable?

        // MARK: - Initialization

        /// Creates a unique owner by heap-allocating the given value.
        ///
        /// The value is moved into heap-allocated memory. The owner takes
        /// responsibility for deallocating this memory when destroyed.
        ///
        /// - Parameter value: The value to own (consumed/moved).
        @inlinable
        public init(_ value: consuming Value) {
            let storage = Pointer<Value>.Mutable.allocate(
                capacity: .one
            )
            storage.initialize(to: value)
            self._storage = storage
        }

        deinit {
            if let storage = _storage {
                _ = storage.deinitialize(count: .one)
                storage.deallocate()
            }
        }
    }
}

// MARK: - Sendable

extension Ownership.Unique: @unchecked Sendable where Value: Sendable {}

// MARK: - Core Operations

extension Ownership.Unique {
    /// Takes ownership of the value, leaving the owner empty.
    ///
    /// After calling `take()`, the owner no longer holds a value and `hasValue`
    /// returns `false`. The memory is deallocated.
    ///
    /// - Returns: The owned value.
    /// - Precondition: The owner has not already been emptied via `take()` or `leak()`.
    @inlinable
    public mutating func take() -> Value {
        guard let storage = _storage else {
            preconditionFailure("Ownership.Unique value has already been taken")
        }
        let value = storage.move()
        storage.deallocate()
        _storage = nil
        return value
    }

    /// Executes a closure with borrowed access to the owned value.
    ///
    /// - Parameter body: A closure receiving a borrowed reference to the value.
    /// - Returns: The closure's return value.
    /// - Precondition: The owner has not been emptied via `take()` or `leak()`.
    @inlinable
    public borrowing func withValue<Result: ~Copyable>(
        _ body: (borrowing Value) throws -> Result
    ) rethrows -> Result {
        guard let storage = _storage else {
            preconditionFailure("Ownership.Unique value has already been taken")
        }
        return try body(storage.pointee)
    }

    /// Executes a closure with mutable access to the owned value.
    ///
    /// - Parameter body: A closure receiving an inout reference to the value.
    /// - Returns: The closure's return value.
    /// - Precondition: The owner has not been emptied via `take()` or `leak()`.
    @inlinable
    public mutating func withMutableValue<Result: ~Copyable>(
        _ body: (inout Value) throws -> Result
    ) rethrows -> Result {
        guard let storage = _storage else {
            preconditionFailure("Ownership.Unique value has already been taken")
        }
        return try body(&storage.pointee)
    }

    /// Returns the underlying pointer and prevents automatic cleanup.
    ///
    /// Use this for interop scenarios where ownership transfers elsewhere.
    /// The caller is responsible for deinitialization and deallocation.
    ///
    /// - Returns: The mutable pointer to the value.
    /// - Precondition: The owner has not already been emptied.
    @inlinable
    public mutating func leak() -> Pointer<Value>.Mutable {
        guard let storage = _storage else {
            preconditionFailure("Ownership.Unique value has already been taken")
        }
        _storage = nil
        return storage
    }

    /// A Boolean indicating whether the owner still holds a value.
    ///
    /// Returns `false` after `take()` or `leak()` has been called.
    @inlinable
    public var hasValue: Bool {
        _storage != nil
    }
}

// MARK: - Description

extension Ownership.Unique {
    /// A textual representation of the owner.
    public var description: String {
        if let storage = _storage {
            return "Ownership.Unique<\(Value.self)>(\(storage))"
        } else {
            return "Ownership.Unique<\(Value.self)>(empty)"
        }
    }

    /// A textual representation suitable for debugging.
    public var debugDescription: String {
        if let storage = _storage {
            return "Ownership.Unique<\(Value.self)>(storage: \(storage))"
        } else {
            return "Ownership.Unique<\(Value.self)>(storage: nil)"
        }
    }
}
