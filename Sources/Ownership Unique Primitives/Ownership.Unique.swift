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
    /// `Unique` is `@unsafe @unchecked Sendable` when `Value: ~Copyable & Sendable`.
    /// The `@unchecked` is required because the stored
    /// `UnsafeMutablePointer<Value>?` is non-Sendable by stdlib design
    /// (`@unsafe` conformance of `_Pointer`). The exclusive-ownership
    /// contract + `~Copyable` wrapper make the concrete type safe to
    /// transfer — only one thread can hold a `Unique<Value>` at a time —
    /// so the conformance is sound. See
    /// `swift-institute/Experiments/noncopyable-generic-sendable-inference/`
    /// for the revalidation that isolates UnsafeMutablePointer (not the
    /// `~Copyable` generic parameter) as the actual inference blocker on
    /// Swift 6.3.1.
    ///
    /// If you need to transfer a non-Sendable value across isolation boundaries,
    /// use `Ownership.Transfer`.
    @safe
    public struct Unique<Value: ~Copyable>: ~Copyable {

        // MARK: - Stored Properties

        /// Internal pointer storage. Nil after `take()` or `leak()`.
        @usableFromInline
        internal var _storage: UnsafeMutablePointer<Value>?

        // MARK: - Initialization

        /// Creates a unique owner by heap-allocating the given value.
        ///
        /// The value is moved into heap-allocated memory. The owner takes
        /// responsibility for deallocating this memory when destroyed.
        ///
        /// - Parameter value: The value to own (consumed/moved).
        @inlinable
        public init(_ value: consuming Value) {
            let storage = UnsafeMutablePointer<Value>.allocate(
                capacity: 1
            )
            unsafe storage.initialize(to: value)
            unsafe (self._storage = storage)
        }

        deinit {
            if let storage = unsafe _storage {
                unsafe storage.deinitialize(count: 1)
                unsafe storage.deallocate()
            }
        }
    }
}

// MARK: - Sendable

extension Ownership.Unique: @unsafe @unchecked Sendable where Value: ~Copyable & Sendable {}

// MARK: - Core Operations

extension Ownership.Unique where Value: ~Copyable {
    /// Takes ownership of the value, leaving the owner empty.
    ///
    /// After calling `take()`, the owner no longer holds a value and `hasValue`
    /// returns `false`. The memory is deallocated.
    ///
    /// - Returns: The owned value.
    /// - Precondition: The owner has not already been emptied via `take()` or `leak()`.
    @inlinable
    public mutating func take() -> Value {
        guard let storage = unsafe _storage else {
            preconditionFailure("Ownership.Unique value has already been taken")
        }
        let value = unsafe storage.move()
        unsafe storage.deallocate()
        unsafe (_storage = nil)
        return value
    }

    /// Executes a closure with borrowed access to the owned value.
    ///
    /// - Parameter body: A closure receiving a borrowed reference to the value.
    /// - Returns: The closure's return value.
    /// - Precondition: The owner has not been emptied via `take()` or `leak()`.
    @inlinable
    public borrowing func withValue<Result: ~Copyable, E: Swift.Error>(
        _ body: (borrowing Value) throws(E) -> Result
    ) throws(E) -> Result {
        guard let storage = unsafe _storage else {
            preconditionFailure("Ownership.Unique value has already been taken")
        }
        return try unsafe body(storage.pointee)
    }

    /// Executes a closure with mutable access to the owned value.
    ///
    /// - Parameter body: A closure receiving an inout reference to the value.
    /// - Returns: The closure's return value.
    /// - Precondition: The owner has not been emptied via `take()` or `leak()`.
    @inlinable
    public mutating func withMutableValue<Result: ~Copyable, E: Swift.Error>(
        _ body: (inout Value) throws(E) -> Result
    ) throws(E) -> Result {
        guard let storage = unsafe _storage else {
            preconditionFailure("Ownership.Unique value has already been taken")
        }
        return try unsafe body(&storage.pointee)
    }

    /// Returns the underlying pointer and prevents automatic cleanup.
    ///
    /// Use this for interop scenarios where ownership transfers elsewhere.
    /// The caller is responsible for deinitialization and deallocation.
    ///
    /// - Returns: The mutable pointer to the value.
    /// - Precondition: The owner has not already been emptied.
    @inlinable
    @unsafe
    public mutating func leak() -> UnsafeMutablePointer<Value> {
        guard let storage = unsafe _storage else {
            preconditionFailure("Ownership.Unique value has already been taken")
        }
        unsafe (_storage = nil)
        return unsafe storage
    }

    /// A Boolean indicating whether the owner still holds a value.
    ///
    /// Returns `false` after `take()` or `leak()` has been called.
    @inlinable
    public var hasValue: Bool {
        unsafe (_storage != nil)
    }
}

// MARK: - Description

extension Ownership.Unique where Value: ~Copyable {
    /// A textual representation of the owner.
    public var description: String {
        if let storage = unsafe _storage {
            return unsafe "Ownership.Unique<\(Value.self)>(\(storage))"
        } else {
            return "Ownership.Unique<\(Value.self)>(empty)"
        }
    }

    /// A textual representation suitable for debugging.
    public var debugDescription: String {
        if let storage = unsafe _storage {
            return unsafe "Ownership.Unique<\(Value.self)>(storage: \(storage))"
        } else {
            return "Ownership.Unique<\(Value.self)>(storage: nil)"
        }
    }
}
