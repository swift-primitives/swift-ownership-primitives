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
    ///
    /// > Note: Swift 6.4-dev nightly emits a RegionIsolation diagnostic on
    /// > the `sending` return ("returning task-isolated 'value' as a
    /// > 'sending' result risks causing data races"). The diagnostic does
    /// > not fire on Swift 6.3 release. The CI matrix's nightly job is
    /// > `continue-on-error: true`; the package builds clean on Swift 6.3.1
    /// > across macOS, Ubuntu, and Windows. Restructuring to satisfy the
    /// > nightly analyzer (e.g. consuming into a local before returning)
    /// > does not eliminate the diagnostic — the binding inherits
    /// > task-isolation from `mutating self`. Track for a re-evaluation
    /// > when 6.4 stabilizes.
    @inlinable
    public mutating func take() -> sending Wrapped? {
        switch consume self {
        case .some(let value):
            self = nil
            // SAFETY: Swift 6.4-dev RegionIsolation — the bound `value`
            // is task-isolated to `mutating self`. Re-binding through
            // `nonisolated(unsafe)` marks the local as disconnected from
            // the caller's region (established ecosystem pattern — see
            // Order.Comparator+Projection / Pool.Bounded.onEnqueue). The
            // intermediate binding is load-bearing: `nonisolated(unsafe)`
            // is a declaration modifier and cannot apply to a bare
            // `return` expression. Under Swift <6.4 this is a harmless
            // no-op.
            // swiftlint:disable:next direct_return
            nonisolated(unsafe) let v = value
            return v

        case .none:
            self = nil
            return nil
        }
    }
}
