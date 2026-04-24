// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-ownership-primitives open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-ownership-primitives project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

public import Tagged_Primitives

// MARK: - Tagged conforms to Ownership.Borrow.`Protocol`

// This conformance lives in Ownership Borrow Primitives, alongside the
// `Ownership.Borrow.`Protocol`` declaration and the `Ownership.Borrow<Value>`
// type. That placement matches the ecosystem convention under which
// `Tagged` conformances to non-stdlib capability protocols live with the
// protocol package (see `swift-ordinal-primitives` `Tagged+Ordinal.Protocol`,
// `swift-format-primitives` `Tagged+Format`, etc.) — keeping
// `swift-tagged-primitives` atomic and dep-free.
extension Tagged: Ownership.Borrow.`Protocol`
where RawValue: Ownership.Borrow.`Protocol` & ~Copyable, Tag: ~Copyable & ~Escapable {
    /// Resolves `Tagged<Tag, RawValue>.Borrowed` to `RawValue.Borrowed`.
    ///
    /// Type identity is preserved — `Tagged<Kernel, Path>.Borrowed` IS
    /// `Path.Borrowed`, not a wrapper. Functions accepting
    /// `borrowing Path.Borrowed` accept
    /// `borrowing Tagged<Kernel, Path>.Borrowed` without conversion.
    public typealias Borrowed = RawValue.Borrowed
}
