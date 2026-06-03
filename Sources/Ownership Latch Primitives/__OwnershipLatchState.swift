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

/// State constants for Ownership.Latch state machine.
///
/// Hoisted to module scope due to Swift limitation: static stored properties
/// are not supported in generic types. Refer via `Ownership.Latch.State`.
@usableFromInline
enum __OwnershipLatchState {}

extension __OwnershipLatchState {
    @usableFromInline static let empty: Int = 0
    @usableFromInline static let initializing: Int = 1
    @usableFromInline static let full: Int = 2
    @usableFromInline static let taken: Int = 3
}
