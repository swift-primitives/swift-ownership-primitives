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
    ///
    /// ## Dual-storage invariant
    ///
    /// `Borrow` holds two pieces of storage that together define its
    /// semantics:
    ///
    /// - `_pointer` — a raw pointer to an initialized `Value`.
    /// - `_owner` — an optional class reference that keeps the underlying
    ///   allocation alive for the Borrow's lifetime.
    ///
    /// For `~Copyable Value`, `_owner` is always `nil`: the borrowing-parameter
    /// calling convention forces indirect passing, so the caller's storage
    /// address is already stable for the lifetime scope expressed by
    /// `@_lifetime(borrow value)`.
    ///
    /// For `Copyable Value`, the borrowing convention may be trivial (by
    /// register for types like `Int`), meaning no stable callee-side address
    /// exists. `init(borrowing:)` therefore copies the value into a
    /// class-owned heap allocation and stores a reference to the owner in
    /// `_owner`; `Borrow`'s struct copies inherit the class reference via
    /// ARC, and the owner's `deinit` frees the allocation when the last
    /// `Borrow` referencing it is destroyed. The typed and raw-address
    /// initializers leave `_owner = nil` — they promise the caller provided
    /// a pointer whose lifetime is managed elsewhere.
    @safe
    public struct Borrow<Value: ~Copyable & ~Escapable>: ~Escapable {

        @usableFromInline
        let _pointer: UnsafeRawPointer

        @usableFromInline
        let _owner: AnyObject?

        /// Designated internal initializer. All public inits delegate here.
        ///
        /// The lifetime of this `Borrow` is bound to `pointer`'s lifetime
        /// scope. `owner`, when non-nil, is an ARC-managed heap buffer that
        /// keeps the memory `pointer` points at alive for as long as any
        /// `Borrow` referencing it exists; callers that supply a
        /// caller-managed pointer pass `owner: nil`.
        @inlinable
        @_lifetime(borrow pointer)
        internal init(
            _pointer pointer: UnsafeRawPointer,
            _owner owner: AnyObject?
        ) {
            unsafe (self._pointer = pointer)
            self._owner = owner
        }

        /// Canonical conformance path for the borrow-capability protocol.
        ///
        /// Conform via `extension Path: Ownership.Borrow.\`Protocol\` {}`.
        /// The typealias resolves to the module-scope
        /// `__Ownership_Borrow_Protocol` (hoisted because SE-0404 prohibits
        /// protocol nesting inside a generic struct).
        public typealias `Protocol` = __Ownership_Borrow_Protocol
    }
}

// MARK: - Owned Storage (Copyable Value path)

/// Heap-allocated owner for the `Copyable` `Value` path of `Ownership.Borrow`.
///
/// Allocates a single-element buffer, copies `Value` into it at construction,
/// and frees the buffer in `deinit`. `Ownership.Borrow` stores a reference
/// to this class in its `_owner` field; the class reference is ARC-managed
/// across Borrow copies, so the buffer survives as long as any `Borrow`
/// referencing it is alive.
///
/// Only used by `Ownership.Borrow.init(borrowing:) where Value: Copyable`.
/// The typed and `unsafeAddress:` inits pass through a caller-managed
/// pointer and leave `_owner = nil`.
@usableFromInline
internal final class _Ownership_Borrow_OwnedBuffer<Value> {

    @usableFromInline
    let _pointer: UnsafeMutablePointer<Value>

    @inlinable
    init(copying value: consuming Value) {
        self._pointer = unsafe UnsafeMutablePointer<Value>.allocate(capacity: 1)
        unsafe self._pointer.initialize(to: value)
    }

    @inlinable
    deinit {
        unsafe _pointer.deinitialize(count: 1)
        unsafe _pointer.deallocate()
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
        self._owner = nil
    }
}

// MARK: - Borrowing Construction (~Copyable Value path)

extension Ownership.Borrow where Value: ~Copyable {
    /// Creates a borrow reference from a borrowed `~Copyable` value.
    ///
    /// This mirrors stdlib `Borrow.init(_ value: borrowing Value)` and the
    /// ecosystem `Property.View.Read` borrowing-init pattern. Enables
    /// construction from any borrowing context without pointer exposure.
    ///
    /// For `~Copyable Value`, the borrowing calling convention is always
    /// indirect: the parameter carries the caller's storage address, and
    /// `withUnsafePointer(to:)` yields that address. The stored pointer is
    /// valid for the lifetime scope declared by `@_lifetime(borrow value)`,
    /// and `_owner` is `nil` because no owned copy exists.
    ///
    /// For `Copyable Value`, a separate overload in the `where Value: Copyable`
    /// extension takes priority; it heap-allocates a copy because the
    /// borrowing convention for trivial `Copyable` types may be by-register
    /// (no stable callee address).
    ///
    /// Only available for `Escapable` `Value` — stdlib's
    /// `withUnsafePointer(to:)` does not support `~Escapable` values.
    ///
    /// - Parameter value: The value to borrow.
    @inlinable
    @_lifetime(borrow value)
    public init(borrowing value: borrowing Value) {
        unsafe (self._pointer = withUnsafePointer(to: value) { UnsafeRawPointer($0) })
        self._owner = nil
    }
}

// MARK: - Borrowing Construction (Copyable Value path)

extension Ownership.Borrow where Value: Copyable {
    /// Creates a borrow reference from a `Copyable` value via a heap-owned copy.
    ///
    /// For `Copyable Value`, the borrowing calling convention may be trivial
    /// (pass-by-register for types like `Int`). `withUnsafePointer(to: value)`
    /// would then capture the callee's spill slot, which becomes invalid the
    /// moment the `withUnsafePointer` frame unwinds — leaving `Borrow`
    /// storing a dangling pointer. The optimizer is free to rematerialize
    /// the (dangling) init on each `.value` read because `Borrow` is
    /// `Copyable`, producing different garbage across reads.
    ///
    /// This overload bypasses the issue by copying `value` into a
    /// class-owned heap buffer and storing a reference to the class in
    /// `_owner`. The buffer lives as long as any `Borrow` referencing it
    /// exists (ARC on the class reference), and the copy semantics of the
    /// underlying `Value` guarantee read-stability: every subsequent read
    /// via `.value` returns a value equal to the borrowed source.
    ///
    /// Cost: one heap allocation per `init(borrowing:)` call with `Copyable
    /// Value`, plus ARC on `Borrow` copies. This is the price of preserving
    /// the `init(borrowing:)` API for `Copyable Value` within the pre-SE-0519
    /// toolchain surface; the overhead disappears once the package migrates
    /// to stdlib `Borrow<T>` after SE-0519 stabilises.
    ///
    /// - Parameter value: The value to borrow. Copied into a heap buffer.
    @inlinable
    @_lifetime(borrow value)
    public init(borrowing value: borrowing Value) {
        let owner = _Ownership_Borrow_OwnedBuffer<Value>(copying: copy value)
        unsafe (self._pointer = UnsafeRawPointer(owner._pointer))
        self._owner = owner
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
        self._owner = nil
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
        self._owner = nil
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
