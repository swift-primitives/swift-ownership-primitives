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

// MARK: - Ownership.Borrow

extension Ownership {
    /// A safe reference allowing in-place reads to a borrowed value.
    ///
    /// `Borrow` provides read-only access to a value through an `UnsafePointer`,
    /// with its lifetime tied to the source. This is the ecosystem equivalent of
    /// Swift stdlib's `Borrow<T>` (SE-0519, SwiftStdlib 6.4), using
    /// `UnsafePointer` instead of `Builtin.Borrow<Value>`.
    ///
    /// ## When to Use
    ///
    /// - Need to return a borrowed view of a ~Copyable element without consuming it
    /// - Need `Optional<Ownership.Borrow<Element>>` for peek-style APIs
    /// - `Property.View` is ~Copyable — use `Ownership.Borrow` when Optional is needed
    ///
    /// ## Copyable + ~Escapable
    ///
    /// `Borrow` is `Copyable` (UnsafePointer copies are safe) but `~Escapable`
    /// (must not outlive its source). This enables `Optional<Ownership.Borrow<Element>>`
    /// — the key use case that `Property.View` (~Copyable) cannot serve.
    @safe
    public struct Borrow<Value: ~Copyable>: ~Escapable {

        @usableFromInline
        let _pointer: UnsafePointer<Value>

        /// Creates a borrow reference from the given pointer.
        ///
        /// The lifetime of this `Borrow` is tied to the pointer's lifetime scope.
        ///
        /// - Parameter pointer: A pointer to the value to borrow.
        @inlinable
        @_lifetime(borrow pointer)
        public init(_ pointer: UnsafePointer<Value>) {
            unsafe (self._pointer = pointer)
        }
    }
}

// MARK: - Borrowing Construction

extension Ownership.Borrow where Value: ~Copyable {
    /// Creates a borrow reference from a borrowed value.
    ///
    /// This mirrors stdlib `Borrow.init(_ value: borrowing Value)` and the
    /// ecosystem `Property.View.Read` borrowing-init pattern. Enables
    /// construction from any borrowing context without pointer exposure.
    ///
    /// - Parameter value: The value to borrow.
    @inlinable
    @_lifetime(borrow value)
    public init(borrowing value: borrowing Value) {
        unsafe (_pointer = withUnsafePointer(to: value) { unsafe $0 })
    }
}

// MARK: - Unsafe Construction

extension Ownership.Borrow where Value: ~Copyable {
    /// Unsafely creates a borrow reference using the given address, with
    /// lifetime based on the borrowed owner.
    ///
    /// This mirrors stdlib `Borrow.init(unsafeAddress:borrowing:)` (SE-0519).
    ///
    /// - Parameter pointer: The address of the value to borrow.
    /// - Parameter owner: The owning instance whose lifetime scopes this borrow.
    @unsafe
    @inlinable
    @_lifetime(borrow owner)
    public init<Owner: ~Copyable & ~Escapable>(
        unsafeAddress pointer: UnsafePointer<Value>,
        borrowing owner: borrowing Owner
    ) {
        unsafe (self._pointer = pointer)
    }
}

// MARK: - Value Access

extension Ownership.Borrow where Value: ~Copyable {
    /// The borrowed value.
    ///
    /// Provides in-place read access to the underlying value through the
    /// stored pointer. Uses `_read` coroutine until `borrow` accessor
    /// (SE-0507, `BorrowAndMutateAccessors`) ships in a production compiler.
    @inlinable
    public var value: Value {
        _read { yield unsafe _pointer.pointee }
    }
}
