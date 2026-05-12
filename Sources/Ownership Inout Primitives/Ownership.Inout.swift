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
    ///
    /// ## ~Escapable `Value`
    ///
    /// `Value` admits both `~Copyable` and `~Escapable`. Storage is
    /// `UnsafeMutableRawPointer` because stdlib's `UnsafeMutablePointer<Pointee>`
    /// implicitly requires `Pointee: Escapable`. The typed construction API
    /// (`init(_ pointer: UnsafeMutablePointer<Value>)`) and the `value`
    /// accessor are therefore available only when `Value: Escapable`
    /// (extensions constrained with `where Value: ~Copyable` — the
    /// `~Copyable` suppression does not re-suppress escapability). For
    /// `~Escapable Value`, construct via `init(unsafeRawAddress:mutating:)`
    /// in the `where Value: ~Copyable & ~Escapable` extension.
    // SAFETY: Encapsulates unsafe internals behind a safe API; see
    // SAFETY: [MEM-SAFE-024] for the absorber-pattern taxonomy.
    @safe
    public struct Inout<Value: ~Copyable & ~Escapable>: ~Copyable, ~Escapable {

        @usableFromInline
        let _pointer: UnsafeMutableRawPointer
    }
}

// MARK: - Typed Construction

extension Ownership.Inout where Value: ~Copyable {
    /// Creates a mutable reference from the given typed pointer.
    ///
    /// The lifetime of this `Inout` is tied to the pointer's lifetime scope.
    ///
    /// Only available when `Value: Escapable` — stdlib's `UnsafeMutablePointer<T>`
    /// requires `T: Escapable`. `~Escapable` `Value` constructs via
    /// `init(unsafeRawAddress:mutating:)` in the `~Escapable`-admitting extension.
    ///
    /// - Parameter pointer: A mutable pointer to the value to access.
    @inlinable
    @_lifetime(borrow pointer)
    public init(_ pointer: UnsafeMutablePointer<Value>) {
        self._pointer = UnsafeMutableRawPointer(pointer)
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
        unsafe (_pointer = withUnsafeMutablePointer(to: &value) { UnsafeMutableRawPointer($0) })
    }
}

// MARK: - Unsafe Construction

extension Ownership.Inout where Value: ~Copyable {
    /// Unsafely creates a mutable reference using the given address, with
    /// lifetime based on the mutating owner.
    ///
    /// This mirrors stdlib `Inout.init(unsafeAddress:mutating:)`.
    ///
    /// - Parameters:
    ///   - pointer: The address of the value to mutate.
    ///   - owner: The owning instance whose mutation scope bounds
    ///     this reference.
    @unsafe
    @inlinable
    @_lifetime(&owner)
    public init<Owner: ~Copyable & ~Escapable>(
        unsafeAddress pointer: UnsafeMutablePointer<Value>,
        mutating owner: inout Owner
    ) {
        unsafe (self._pointer = UnsafeMutableRawPointer(pointer))
    }
}

// MARK: - Unsafe Raw-Address Construction (~Escapable Value)

extension Ownership.Inout where Value: ~Copyable & ~Escapable {
    /// Unsafely creates a mutable reference using a raw address, with
    /// lifetime based on the mutating owner.
    ///
    /// This is the only construction path available when `Value` is
    /// `~Escapable`, because stdlib's typed `UnsafeMutablePointer<Value>`
    /// requires `Value: Escapable`. Mirrors
    /// ``Ownership/Borrow/init(unsafeRawAddress:borrowing:)`` (the read-only
    /// counterpart) — same shape, mutating-owner lifetime instead of
    /// borrowing-owner lifetime.
    ///
    /// - Parameters:
    ///   - pointer: The raw address of the value to mutate.
    ///   - owner: The owning instance whose mutation scope bounds this
    ///     reference.
    @unsafe
    @inlinable
    @_lifetime(&owner)
    public init<Owner: ~Copyable & ~Escapable>(
        unsafeRawAddress pointer: UnsafeMutableRawPointer,
        mutating owner: inout Owner
    ) {
        unsafe (self._pointer = pointer)
    }
}

// MARK: - Value Access

extension Ownership.Inout where Value: ~Copyable {
    /// The referenced value (noncopyable case).
    ///
    /// Coroutine-based access preserves in-place ~Copyable reads/writes without
    /// moving the value through the pointer. `nonmutating _modify` provides
    /// interior mutability per [IMPL-071].
    ///
    /// Only available when `Value: Escapable` — `assumingMemoryBound(to:)`
    /// returns `UnsafeMutablePointer<Value>`, which requires `Value: Escapable`.
    /// `~Escapable` `Value` constructs via the raw-address init in the
    /// `~Escapable`-admitting extension and has no `value` accessor.
    @inlinable
    public var value: Value {
        _read { yield unsafe _pointer.assumingMemoryBound(to: Value.self).pointee }
        nonmutating _modify { yield unsafe &_pointer.assumingMemoryBound(to: Value.self).pointee }
    }
}

extension Ownership.Inout where Value: Copyable {
    /// The referenced value (copyable case).
    ///
    /// `get` returns a copy, avoiding the lifetime tagging that a `_read`
    /// coroutine imposes on the yielded value. `nonmutating _modify`
    /// preserves in-place writeback so CoW semantics (`base.value.pop.front()`
    /// etc.) continue to fire through the pointer. The rejected `get + set`
    /// split broke CoW because `set` writebacks did not trigger for nested
    /// method-call mutations — `_modify` does.
    @inlinable
    public var value: Value {
        get { unsafe _pointer.assumingMemoryBound(to: Value.self).pointee }
        nonmutating _modify { yield unsafe &_pointer.assumingMemoryBound(to: Value.self).pointee }
    }
}
