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

/// Ownership Primitives
///
/// Types that own values with distinct ownership contracts. Each type provides
/// a specific combination of ownership semantics, mutability, and thread-safety.
///
/// ## Types
///
/// | Type | Ownership | Mutability | Sendable |
/// |------|-----------|------------|----------|
/// | ``Unique`` | Exclusive | Mutable | When `Value: Sendable` |
/// | ``Shared`` | Shared (ARC) | Immutable | When `Value: Sendable` |
/// | ``Mutable`` | Shared (ARC) | Mutable | Not Sendable (use `.Unchecked`) |
/// | ``Slot`` | Reusable | Move semantics | `@unchecked` (atomic sync) |
/// | ``Transfer`` | One-shot | Move-only | Tokens are Sendable |
///
/// ## Design Philosophy
///
/// This module provides ownership primitives with distinct contracts:
///
/// - Need exclusive ownership with deterministic cleanup? → ``Unique``
/// - Need shared immutable heap storage? → ``Shared``
/// - Need shared mutable heap storage? → ``Mutable``
/// - Need atomic move semantics? → ``Slot``
/// - Need cross-boundary ownership transfer? → ``Transfer``
///
/// ## Sendable Policy
///
/// **Principle:** Mutable reference wrappers are NOT Sendable by default.
/// Crossing isolation boundaries requires explicit opt-in.
///
/// ### Exclusive ownership
/// - `Unique`: Sendable when `Value: Sendable` (exclusive owner, no sharing)
///
/// ### Immutable shared
/// - `Shared`: Sendable when `Value: Sendable` (immutable, safe to share)
///
/// ### Mutable shared (not Sendable by default)
/// - `Mutable`: Not Sendable. Use `Mutable.Unchecked` for explicit opt-in.
///
/// ### Synchronized types
/// - `Slot`: `@unchecked Sendable` because atomic state machine provides
///   synchronization. Safe publication via release/acquire on state transitions.
/// - `Transfer`: Tokens are Sendable. Exactly-once semantics enforced atomically.
///
/// ## Relationship to Reference Primitives
///
/// `Ownership_Primitives` contains types that **own** values.
/// `Reference_Primitives` contains types that **refer** to values without ownership:
/// - `Reference.Weak`: Zeroing weak reference
/// - `Reference.Unowned`: Unsafe unowned reference
/// - `Reference.Sendability`: Sendability escape hatches
public enum Ownership {}
