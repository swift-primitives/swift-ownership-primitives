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
    /// Creates a deep copy with new heap allocation.
    ///
    /// This explicitly allocates new storage and copies the value.
    /// Use when you need independent ownership of a duplicate.
    ///
    /// - Returns: A new `Unique` owning a copy of the value.
    /// - Precondition: The owner has not been emptied via `take()` or `leak()`.
    @inlinable
    public borrowing func duplicated() -> Ownership.Unique<Value> {
        guard let storage = _storage else {
            preconditionFailure("Ownership.Unique value has already been taken")
        }
        return Ownership.Unique(storage.pointee)
    }
}
