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
    /// AnyObject transfer namespace.
    ///
    /// Uses direct ARC retain/release via `Unmanaged` so the outgoing
    /// direction needs no heap box at all. The incoming direction uses a
    /// single shared atomic slot (one allocation, no internal payload
    /// pointer indirection).
    public enum Retained<T: AnyObject> {}
}
