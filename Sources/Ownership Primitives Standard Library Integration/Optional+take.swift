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
    /// Consumes the whole optional in one step and clears the storage via `defer`,
    /// so there is no intermediate binding extracted from a `mutating self` region.
    ///
    /// ## Usage
    /// ```swift
    /// var handle: SomeNonCopyableType? = ...
    /// guard let h = handle.take() else { return }
    /// // handle is now nil, h owns the value
    /// ```
    ///
    /// - Returns: The wrapped value if present, nil otherwise.
    ///
    /// > Note: An earlier `switch consume self { case .some(let value): ... }`
    /// > shape triggered a Swift 6.4 RegionIsolation diagnostic ("returning
    /// > 'value' as a 'sending' result risks causing data races"): pattern
    /// > matching bound `value` as a fresh local still tied to the
    /// > `mutating self` region, and the region checker could not see it as
    /// > disconnected from the caller's region on return. Consuming `self`
    /// > directly into the `return` expression removes the extra binding
    /// > entirely — the sending value and the consumed storage are the same
    /// > single expression, so there is nothing left for the checker to tie
    /// > back to `self`'s isolation.
    @inlinable
    public mutating func take() -> sending Wrapped? {
        defer { self = nil }
        return consume self
    }
}
