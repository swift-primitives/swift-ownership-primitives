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

extension Ownership.Transfer {
    /// Type-erased transfer namespace.
    ///
    /// The payload's concrete type is known to producer and consumer by
    /// agreement; the cell itself stores an opaque box that destructs
    /// correctly even when neither side reaches the unboxing call (for
    /// abandoned paths).
    public enum Erased {}
}
