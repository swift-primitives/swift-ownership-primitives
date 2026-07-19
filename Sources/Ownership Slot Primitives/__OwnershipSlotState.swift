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

/// State constants for Ownership.Slot state machine.
///
/// Hoisted to module scope due to Swift limitation: static stored properties
/// are not supported in generic types. Refer via `Ownership.Slot.State`.
@usableFromInline
enum __OwnershipSlotState {}

extension __OwnershipSlotState {
    @usableFromInline static let empty: UInt8 = 0
    @usableFromInline static let initializing: UInt8 = 1
    @usableFromInline static let full: UInt8 = 2
    @usableFromInline static let draining: UInt8 = 3
}
