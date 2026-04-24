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

// MARK: - Copyable Operations

extension Ownership.Unique where Value: Copyable {
    /// Creates an independent copy of this cell with new heap allocation.
    ///
    /// Mirrors SE-0517's `clone()`. The resulting cell owns a freshly
    /// allocated copy of the value; the original continues to exist.
    ///
    /// ```swift
    /// let a = Ownership.Unique<Int>(42)
    /// let b = a.clone()       // independent heap allocation
    /// ```
    ///
    /// - Returns: A new `Ownership.Unique` owning a deep copy of the value.
    @inlinable
    public borrowing func clone() -> Ownership.Unique<Value> {
        return unsafe Ownership.Unique(_storage.pointee)
    }
}
