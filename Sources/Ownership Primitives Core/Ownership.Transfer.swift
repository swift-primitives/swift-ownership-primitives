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

extension Ownership {
    /// Namespace for cross-boundary ownership transfer primitives.
    ///
    /// Transfer provides mechanisms for moving `~Copyable` values across
    /// `@Sendable` boundaries (e.g., to OS threads, workers, or other contexts)
    /// with exactly-once semantics.
    ///
    /// ## Design
    /// - `Cell<T>`: Pass an existing value through an escaping boundary
    /// - `Storage<T>`: Create a value inside a closure, retrieve after
    /// - `Retained<T>`: Zero-allocation transfer for `AnyObject` types
    /// - `Box`: Type-erased boxing for opaque pointer scenarios
    ///
    /// ## Safety Guarantees
    /// - Tokens are Copyable (required for escaping closure capture)
    /// - All invariant violations trap deterministically (not undefined behavior)
    /// - ARC-managed storage with atomic one-shot enforcement
    /// - Thread-safe: multiple copies of a token can exist, but only one
    ///   take/store succeeds
    ///
    /// ## Usage
    /// ```swift
    /// // Cell: pass existing value through
    /// let cell = Ownership.Transfer.Cell(myValue)
    /// let token = cell.token()
    /// spawnThread { let value = token.take() }
    ///
    /// // Storage: create inside, retrieve after
    /// let storage = Ownership.Transfer.Storage<MyType>()
    /// let storeToken = storage.token
    /// spawnThread { storeToken.store(createValue()) }
    /// let value = storage.consume()
    ///
    /// // Retained: zero-allocation class transfer
    /// let retained = Ownership.Transfer.Retained(myObject)
    /// spawnThread { let obj = retained.consume() }
    /// ```
    public enum Transfer {}
}
