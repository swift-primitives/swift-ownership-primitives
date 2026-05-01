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
@safe
@usableFromInline
internal final class _Ownership_Borrow_OwnedBuffer<Value> {

    @usableFromInline
    let _pointer: UnsafeMutablePointer<Value>

    @inlinable
    init(copying value: consuming Value) {
        unsafe (self._pointer = UnsafeMutablePointer<Value>.allocate(capacity: 1))
        unsafe self._pointer.initialize(to: value)
    }

    @inlinable
    deinit {
        unsafe _pointer.deinitialize(count: 1)
        unsafe _pointer.deallocate()
    }
}
