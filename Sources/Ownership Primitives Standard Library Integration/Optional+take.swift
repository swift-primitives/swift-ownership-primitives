// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-ownership-primitives open source project
//
// Copyright (c) 2024-2025 Coen ten Thije Boonkkamp and the swift-ownership-primitives project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

/// Extension for consuming ~Copyable optional values.
///
/// This is a stopgap utility until Swift stdlib provides equivalent functionality.
/// The underscore prefix signals this is internal infrastructure that may be
/// removed when stdlib alternatives become available.
extension Optional where Wrapped: ~Copyable {
    /// Takes the value out of the optional, leaving nil behind.
    ///
    /// This is the canonical pattern for consuming ~Copyable optional stored properties.
    /// Uses `consume self` to move the value out, then reassigns nil to the storage.
    ///
    /// ## Usage
    /// ```swift
    /// var handle: SomeNonCopyableType? = ...
    /// guard let h = handle.take() else { return }
    /// // handle is now nil, h owns the value
    /// ```
    ///
    /// - Returns: The wrapped value if present, nil otherwise.
    @inlinable
    public mutating func take() -> sending Wrapped? {
        switch consume self {
        case .some(let value):
            self = nil
            return value
        case .none:
            self = nil
            return nil
        }
    }
}
