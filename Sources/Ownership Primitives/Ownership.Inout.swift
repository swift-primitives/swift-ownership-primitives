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

// MARK: - Ownership.Inout

extension Ownership {
    /// A safe mutable reference allowing in-place reads and writes to an
    /// exclusive value.
    ///
    /// `Inout` provides mutable access to a value through an
    /// `UnsafeMutablePointer`, with its lifetime tied to the source. This is
    /// the ecosystem equivalent of Swift stdlib's `Inout<T>` (SwiftStdlib 6.4),
    /// using `UnsafeMutablePointer` instead of `Builtin` internals.
    ///
    /// ## When to Use
    ///
    /// - Need to mutate a ~Copyable element in-place without removing it
    /// - Need `Optional<Ownership.Inout<Element>>` for conditional mutable access
    /// - Mutable counterpart to ``Borrow``
    ///
    /// ## ~Copyable + ~Escapable
    ///
    /// `Inout` is `~Copyable` (mutable access must be exclusive) and
    /// `~Escapable` (must not outlive its source). Compare with ``Borrow``
    /// which is `Copyable` (read-only access can be shared).
    @safe
    public struct Inout<Value: ~Copyable>: ~Copyable, ~Escapable {

        @usableFromInline
        let _pointer: UnsafeMutablePointer<Value>

        /// Creates a mutable reference from the given pointer.
        ///
        /// The lifetime of this `Inout` is tied to the pointer's lifetime scope.
        ///
        /// - Parameter pointer: A mutable pointer to the value to access.
        @inlinable
        @_lifetime(borrow pointer)
        public init(_ pointer: UnsafeMutablePointer<Value>) {
            unsafe (self._pointer = pointer)
        }
    }
}

// MARK: - Mutating Construction

extension Ownership.Inout where Value: ~Copyable {
    /// Creates a mutable reference from an inout value.
    ///
    /// This mirrors stdlib `Inout.init(_ value: inout Value)`. Enables
    /// construction from any mutating context without pointer exposure.
    ///
    /// - Parameter value: The value to mutate.
    @inlinable
    @_lifetime(&value)
    public init(mutating value: inout Value) {
        unsafe (_pointer = withUnsafeMutablePointer(to: &value) { unsafe $0 })
    }
}

// MARK: - Unsafe Construction

extension Ownership.Inout where Value: ~Copyable {
    /// Unsafely creates a mutable reference using the given address, with
    /// lifetime based on the mutating owner.
    ///
    /// This mirrors stdlib `Inout.init(unsafeAddress:mutating:)`.
    ///
    /// - Parameter pointer: The address of the value to mutate.
    /// - Parameter owner: The owning instance whose mutation scope bounds
    ///   this reference.
    @unsafe
    @inlinable
    @_lifetime(&owner)
    public init<Owner: ~Copyable & ~Escapable>(
        unsafeAddress pointer: UnsafeMutablePointer<Value>,
        mutating owner: inout Owner
    ) {
        unsafe (self._pointer = pointer)
    }
}

// MARK: - Value Access

extension Ownership.Inout where Value: ~Copyable {
    /// The referenced value.
    ///
    /// Provides in-place read and write access to the underlying value
    /// through the stored pointer. Uses `_read`/`nonmutating _modify`
    /// coroutines until `borrow`/`mutate` accessors (SE-0507,
    /// `BorrowAndMutateAccessors`) ship in a production compiler.
    ///
    /// `nonmutating _modify` provides interior mutability per [IMPL-071]:
    /// the pointer itself is `let` — mutation goes through to the pointee.
    /// Exclusivity is guaranteed by `~Copyable` on the `Inout` struct.
    @inlinable
    public var value: Value {
        _read { yield unsafe _pointer.pointee }
        nonmutating _modify { yield unsafe &_pointer.pointee }
    }
}
