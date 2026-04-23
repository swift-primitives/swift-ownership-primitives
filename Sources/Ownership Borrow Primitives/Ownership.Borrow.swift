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
    /// `Borrow` provides read-only access to a value through a raw pointer,
    /// with its lifetime tied to the source. This is the ecosystem equivalent of
    /// Swift stdlib's `Borrow<T>` (SE-0519, SwiftStdlib 6.4), using
    /// `UnsafeRawPointer` instead of `Builtin.Borrow<Value>`.
    ///
    /// ## When to Use
    ///
    /// - Need to return a borrowed view of a ~Copyable element without consuming it
    /// - Need `Optional<Ownership.Borrow<Element>>` for peek-style APIs
    /// - `Property.View` is ~Copyable — use `Ownership.Borrow` when Optional is needed
    ///
    /// ## Copyable + ~Escapable
    ///
    /// `Borrow` is `Copyable` (pointer copies are safe) but `~Escapable`
    /// (must not outlive its source). This enables `Optional<Ownership.Borrow<Element>>`
    /// — the key use case that `Property.View` (~Copyable) cannot serve.
    ///
    /// ## ~Escapable `Value`
    ///
    /// `Value` admits both `~Copyable` and `~Escapable`. Storage is
    /// `UnsafeRawPointer` because stdlib's `UnsafePointer<Pointee>` implicitly
    /// requires `Pointee: Escapable`. The typed construction API
    /// (`init(_ pointer: UnsafePointer<Value>)`) and the `value` accessor
    /// are therefore available only when `Value: Escapable` (extensions
    /// constrained with `where Value: ~Copyable` — the `~Copyable`
    /// suppression does not re-suppress escapability).
    @safe
    public struct Borrow<Value: ~Copyable & ~Escapable>: ~Escapable {

        @usableFromInline
        let _pointer: UnsafeRawPointer

        /// Canonical conformance path for the borrow-capability protocol.
        ///
        /// Conform via `extension Path: Ownership.Borrow.\`Protocol\` {}`.
        /// The typealias resolves to the module-scope
        /// `__Ownership_Borrow_Protocol` (hoisted because SE-0404 prohibits
        /// protocol nesting inside a generic struct).
        public typealias `Protocol` = __Ownership_Borrow_Protocol
    }
}

// MARK: - Typed Construction

extension Ownership.Borrow where Value: ~Copyable {
    /// Creates a borrow reference from the given typed pointer.
    ///
    /// The lifetime of this `Borrow` is tied to the pointer's lifetime scope.
    ///
    /// Only available when `Value: Escapable` — stdlib's `UnsafePointer<T>`
    /// requires `T: Escapable`. `~Escapable` `Value` constructs via the
    /// raw-address init in the ~Escapable-admitting extension.
    ///
    /// - Parameter pointer: A pointer to the value to borrow.
    @inlinable
    @_lifetime(borrow pointer)
    public init(_ pointer: UnsafePointer<Value>) {
        unsafe (self._pointer = UnsafeRawPointer(pointer))
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
    /// Only available for `Escapable` `Value` — stdlib's
    /// `withUnsafePointer(to:)` does not support `~Escapable` values.
    ///
    /// - Parameter value: The value to borrow.
    @inlinable
    @_lifetime(borrow value)
    public init(borrowing value: borrowing Value) {
        unsafe (_pointer = withUnsafePointer(to: value) { UnsafeRawPointer($0) })
    }
}

// MARK: - Unsafe Typed Construction

extension Ownership.Borrow where Value: ~Copyable {
    /// Unsafely creates a borrow reference using the given address, with
    /// lifetime based on the borrowed owner.
    ///
    /// This mirrors stdlib `Borrow.init(unsafeAddress:borrowing:)` (SE-0519).
    ///
    /// Only available for `Escapable` `Value` — the typed
    /// `UnsafePointer<Value>` parameter requires it.
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
        unsafe (self._pointer = UnsafeRawPointer(pointer))
    }
}

// MARK: - Raw-Address Construction (~Escapable Value)

extension Ownership.Borrow where Value: ~Copyable & ~Escapable {
    /// Unsafely creates a borrow reference using a raw address, with
    /// lifetime based on the borrowed owner.
    ///
    /// This is the only construction path available when `Value` is
    /// `~Escapable`, because stdlib's typed `UnsafePointer<Value>` requires
    /// `Value: Escapable`. In practice, the default associatedtype
    /// `Borrowed = Ownership.Borrow<Self>` on `Ownership.Borrow.\`Protocol\``
    /// only resolves to this shape for conformers that specifically want it;
    /// typical `~Escapable` conformers (Path, String) declare their own
    /// nested `Borrowed` struct instead.
    ///
    /// - Parameter pointer: The raw address of the value to borrow.
    /// - Parameter owner: The owning instance whose lifetime scopes this borrow.
    @unsafe
    @inlinable
    @_lifetime(borrow owner)
    public init<Owner: ~Copyable & ~Escapable>(
        unsafeRawAddress pointer: UnsafeRawPointer,
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
    ///
    /// Only available when `Value: Escapable` — reconstructing a typed
    /// pointer from `UnsafeRawPointer` via `assumingMemoryBound(to:)`
    /// returns `UnsafePointer<Value>`, which requires `Value: Escapable`.
    @inlinable
    public var value: Value {
        _read {
            yield unsafe _pointer.assumingMemoryBound(to: Value.self).pointee
        }
    }
}
