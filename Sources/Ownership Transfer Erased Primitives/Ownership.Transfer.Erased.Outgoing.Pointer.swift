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

extension Ownership.Transfer.Erased.Outgoing {
    /// Sendable capability wrapper for the boxed pointer.
    ///
    /// Carries an `UnsafeMutableRawPointer` as an ownership-transfer token
    /// across `@Sendable` boundaries. The holder agrees to invoke
    /// `consume(_:)` or `destroy(_:)` exactly once.
    ///
    /// ## Safety Invariant
    ///
    /// `@unchecked Sendable` per [MEM-SAFE-024] Category A —
    /// synchronization is external; the holder commits to single-consumption
    /// by contract.
    @safe
    public struct Pointer: @unchecked Sendable {
        /// The raw allocation address.
        @unsafe
        public let raw: UnsafeMutableRawPointer
        /// Wraps a raw pointer as an outgoing erased pointer.
        @unsafe
        public init(_ raw: UnsafeMutableRawPointer) { unsafe (self.raw = raw) }
    }
}
