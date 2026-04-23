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

/// Module-scope hoisted protocol for `Ownership.Borrow.\`Protocol\``.
///
/// Use the canonical spelling `Ownership.Borrow.\`Protocol\`` at conformance
/// sites. This `__`-prefixed declaration is the implementation-detail target
/// of the nested typealias inside `Ownership.Borrow<Value>` and is not
/// intended for direct reference.
///
/// Conformers expose a borrowed projection of their content. The default
/// `Borrowed = Ownership.Borrow<Self>` covers types without interior
/// storage or type-level invariants; conformers with storage or invariants
/// override the associatedtype with a custom nested type (e.g.,
/// `Path.Borrowed`, `String.Borrowed`).
///
/// Precedent for the hoisting pattern: `swift-tree-primitives`'s
/// `__TreeNChildSlot<n>`. SE-0404 opened non-generic protocol nesting only;
/// direct nesting inside the generic struct `Ownership.Borrow<Value>`
/// remains prohibited on Swift 6.3.1.
public protocol __Ownership_Borrow_Protocol: ~Copyable, ~Escapable {
    associatedtype Borrowed: ~Copyable, ~Escapable
        = Ownership.Borrow<Self>
}
